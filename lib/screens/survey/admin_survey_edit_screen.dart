import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/survey.dart';
import '../../providers/survey_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

// ── Mutable data wrappers ─────────────────────────────────────────────────────

class _MutableCondition {
  String? questionId;
  Set<String> matchValues;
  int? targetSectionIndex; // null = not set; sections.length = end survey

  _MutableCondition({this.questionId, Set<String>? matchValues, this.targetSectionIndex})
      : matchValues = matchValues ?? {};

  factory _MutableCondition.from(SectionCondition c) => _MutableCondition(
        questionId: c.questionId,
        matchValues: Set<String>.from(c.matchValues),
        targetSectionIndex: c.targetSectionIndex,
      );

  _MutableCondition.copy(_MutableCondition other)
      : questionId = other.questionId,
        matchValues = Set<String>.from(other.matchValues),
        targetSectionIndex = other.targetSectionIndex;
}

class _MutableSection {
  final Key widgetKey;
  String title;
  String subtitle;
  List<SurveyQuestion> questions;
  List<_MutableCondition> conditions;
  int? defaultNext;
  bool isExpanded;

  _MutableSection({
    Key? widgetKey,
    required this.title,
    required this.subtitle,
    required this.questions,
    List<_MutableCondition>? conditions,
    this.defaultNext,
    this.isExpanded = true,
  })  : widgetKey = widgetKey ?? UniqueKey(),
        conditions = conditions ?? [];

  factory _MutableSection.from(SurveySection s) => _MutableSection(
        title: s.title,
        subtitle: s.subtitle,
        questions: List<SurveyQuestion>.from(s.questions),
        conditions: s.conditions.map(_MutableCondition.from).toList(),
        defaultNext: s.defaultNext,
      );

  SurveySection toSection() => SurveySection(
        title: title,
        subtitle: subtitle,
        questions: List<SurveyQuestion>.from(questions),
        conditions: conditions
            .where((c) =>
                c.questionId != null &&
                c.matchValues.isNotEmpty &&
                c.targetSectionIndex != null)
            .map((c) => SectionCondition(
                  questionId: c.questionId!,
                  matchValues: c.matchValues.toList(),
                  targetSectionIndex: c.targetSectionIndex!,
                ))
            .toList(),
        defaultNext: defaultNext,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminSurveyEditScreen extends StatefulWidget {
  final String surveyId;
  const AdminSurveyEditScreen({super.key, required this.surveyId});

  @override
  State<AdminSurveyEditScreen> createState() => _AdminSurveyEditScreenState();
}

class _AdminSurveyEditScreenState extends State<AdminSurveyEditScreen> {
  Survey? _survey;
  bool _loading = true;
  bool _saving = false;
  late List<_MutableSection> _sections;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<SurveyProvider>().getSurvey(widget.surveyId);
    if (mounted) {
      setState(() {
        _survey = s;
        _sections = s?.sections.map(_MutableSection.from).toList() ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sections = _sections.map((ms) => ms.toSection()).toList();
      await context.read<SurveyProvider>().updateSurveySections(widget.surveyId, sections);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Survey saved'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Section reorder ───────────────────────────────────────────────────────

  void _reorderSections(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
      // Remap condition targets after reorder
      for (final s in _sections) {
        for (final c in s.conditions) {
          c.targetSectionIndex = _remapIdx(
              c.targetSectionIndex, oldIndex, newIndex, _sections.length);
        }
        if (s.defaultNext != null) {
          s.defaultNext =
              _remapIdx(s.defaultNext!, oldIndex, newIndex, _sections.length);
        }
      }
    });
  }

  int _remapIdx(int? t, int oldIdx, int newIdx, int endSentinel) {
    if (t == null || t == endSentinel) return t ?? endSentinel;
    if (t == oldIdx) return newIdx;
    if (oldIdx < newIdx && t > oldIdx && t <= newIdx) return t - 1;
    if (oldIdx > newIdx && t >= newIdx && t < oldIdx) return t + 1;
    return t;
  }

  // ── Section CRUD ──────────────────────────────────────────────────────────

  void _addSection() async {
    final result = await showDialog<_MutableSection>(
      context: context,
      builder: (_) => _SectionDialog(
        allSections: _sections,
        allQuestions: _allQuestions(),
      ),
    );
    if (result != null) setState(() => _sections.add(result));
  }

  void _editSection(int index) async {
    final result = await showDialog<_MutableSection>(
      context: context,
      builder: (_) => _SectionDialog(
        existing: _sections[index],
        sectionIndex: index,
        allSections: _sections,
        allQuestions: _allQuestions(),
      ),
    );
    if (result != null) {
      setState(() {
        _sections[index].title = result.title;
        _sections[index].subtitle = result.subtitle;
        _sections[index].conditions = result.conditions;
        _sections[index].defaultNext = result.defaultNext;
      });
    }
  }

  void _deleteSection(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Delete "${_sections[index].title}" and all its questions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(() => _sections.removeAt(index));
  }

  // ── Question CRUD ─────────────────────────────────────────────────────────

  void _addQuestion(int sectionIndex) async {
    final letter = String.fromCharCode(65 + (sectionIndex % 26));
    final code = '$letter${_sections[sectionIndex].questions.length + 1}';
    final result = await showDialog<SurveyQuestion>(
      context: context,
      builder: (_) => _QuestionDialog(
        suggestedCode: code,
        allQuestions: _allQuestions(),
      ),
    );
    if (result != null) setState(() => _sections[sectionIndex].questions.add(result));
  }

  void _editQuestion(int sectionIndex, int questionIndex) async {
    final existing = _sections[sectionIndex].questions[questionIndex];
    final result = await showDialog<SurveyQuestion>(
      context: context,
      builder: (_) => _QuestionDialog(
        existing: existing,
        allQuestions: _allQuestions(),
      ),
    );
    if (result != null) {
      setState(() => _sections[sectionIndex].questions[questionIndex] = result);
    }
  }

  void _deleteQuestion(int sectionIndex, int questionIndex) {
    setState(() => _sections[sectionIndex].questions.removeAt(questionIndex));
  }

  void _reorderQuestion(int sectionIndex, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final q = _sections[sectionIndex].questions.removeAt(oldIndex);
      _sections[sectionIndex].questions.insert(newIndex, q);
    });
  }

  List<SurveyQuestion> _allQuestions() =>
      _sections.expand((s) => s.questions).toList();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_survey == null) return const Scaffold(body: Center(child: Text('Survey not found')));

    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 20),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: _reorderSections,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                      child: child,
                    ),
                    children: [
                      for (int i = 0; i < _sections.length; i++)
                        _buildSectionCard(i, key: _sections[i].widgetKey),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Add Section'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal.shade700,
                        side: BorderSide(color: Colors.teal.shade400),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      )),
                      const SizedBox(width: 4),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                        child: const Center(child: Text('HC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Edit Survey ${_survey!.code}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text('Sections & Questions', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => context.pop()),
                      _saving
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                              tooltip: 'Save',
                              onPressed: _save,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    final totalQ = _sections.fold(0, (acc, s) => acc + s.questions.length);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.cyan.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.shade200.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_survey!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${_sections.length} sections · $totalQ questions', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                : const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal.shade700, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _buildSectionCard(int sectionIndex, {required Key key}) {
    final section = _sections[sectionIndex];
    final hasConditions = section.conditions.isNotEmpty || section.defaultNext != null;

    return Card(
      key: key,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(section.isExpanded ? 12 : 12), bottom: Radius.circular(section.isExpanded ? 0 : 12)),
            ),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: sectionIndex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Icon(Icons.drag_indicator, color: Colors.teal.shade300, size: 20),
                  ),
                ),
                // Section number badge
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.teal.shade600, borderRadius: BorderRadius.circular(7)),
                  child: Center(child: Text('${sectionIndex + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ),
                const SizedBox(width: 10),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (section.subtitle.isNotEmpty)
                        Text(section.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Condition badge
                if (hasConditions)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: 'Has routing conditions',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade300)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.alt_route, size: 11, color: Colors.orange.shade700),
                          const SizedBox(width: 3),
                          Text('Route', style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                // Q count
                Text('${section.questions.length}q', style: TextStyle(fontSize: 11, color: Colors.teal.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                IconButton(icon: Icon(Icons.edit_outlined, size: 17, color: Colors.teal.shade700), tooltip: 'Edit section', onPressed: () => _editSection(sectionIndex), constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red), tooltip: 'Delete section', onPressed: () => _deleteSection(sectionIndex), constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                IconButton(
                  icon: Icon(section.isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.teal.shade700),
                  onPressed: () => setState(() => section.isExpanded = !section.isExpanded),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          // ── Expanded content ───────────────────────────────────────────
          if (section.isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Questions reorderable list
                  if (section.questions.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                      ),
                      child: Center(child: Text('No questions yet — add one below', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (old, newIdx) => _reorderQuestion(sectionIndex, old, newIdx),
                      proxyDecorator: (child, index, animation) => Material(elevation: 6, borderRadius: BorderRadius.circular(8), color: Colors.transparent, child: child),
                      children: [
                        for (int qi = 0; qi < section.questions.length; qi++)
                          _buildQuestionTile(sectionIndex, qi, section.questions[qi], key: ValueKey(section.questions[qi].id)),
                      ],
                    ),

                  // Add question button
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _addQuestion(sectionIndex),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Question'),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal.shade700),
                  ),

                  // Routing summary
                  if (hasConditions) _buildRoutingSummary(sectionIndex, section),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutingSummary(int sectionIndex, _MutableSection section) {
    final lines = <String>[];
    for (final c in section.conditions) {
      final q = _allQuestions().where((q) => q.id == c.questionId).firstOrNull;
      final qLabel = q != null ? '${q.code}: ${q.text}' : c.questionId;
      final vals = c.matchValues.take(3).join(', ');
      final target = c.targetSectionIndex != null
          ? (c.targetSectionIndex! >= _sections.length
              ? 'End survey'
              : '§${c.targetSectionIndex! + 1} ${_sections[c.targetSectionIndex!].title}')
          : '?';
      lines.add('If "$qLabel" is [$vals] → $target');
    }
    final defaultLabel = section.defaultNext == null
        ? 'next section'
        : section.defaultNext! >= _sections.length
            ? 'End survey'
            : '§${section.defaultNext! + 1} ${_sections[section.defaultNext!].title}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.alt_route, size: 13, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text('Section Routing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
          ]),
          const SizedBox(height: 6),
          ...lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(l, style: TextStyle(fontSize: 11, color: Colors.orange.shade800), maxLines: 2, overflow: TextOverflow.ellipsis),
          )),
          Text('Default → $defaultLabel', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ── Question tile ─────────────────────────────────────────────────────────

  Widget _buildQuestionTile(int sectionIndex, int qIndex, SurveyQuestion q, {required Key key}) {
    final typeColor = _typeColor(q.type);
    final typeLabel = _typeLabel(q.type);
    final typeIcon = _typeIcon(q.type);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header row
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: qIndex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.drag_indicator, size: 18, color: Colors.grey.shade300),
                  ),
                ),
                // Code badge
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(q.code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
                ),
                const SizedBox(width: 8),
                // Question text
                Expanded(
                  child: Text(
                    q.text + (q.isRequired ? ' *' : ''),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Type chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: typeColor.withValues(alpha: 0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(typeIcon, size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text(typeLabel, style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 4),
                // Skip logic indicator
                if (q.conditionalOnId != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Tooltip(
                      message: 'Has skip logic',
                      child: Icon(Icons.alt_route, size: 14, color: Colors.purple.shade400),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 15, color: Colors.teal.shade600),
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () => _editQuestion(sectionIndex, qIndex),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () => _deleteQuestion(sectionIndex, qIndex),
                ),
              ],
            ),
          ),

          // Answer preview
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 16, 10),
            child: _buildAnswerPreview(q),
          ),
        ],
      ),
    );
  }

  // ── Answer preview (Google Forms style) ──────────────────────────────────

  Widget _buildAnswerPreview(SurveyQuestion q) {
    return switch (q.type) {
      QuestionType.singleChoice => _choicePreview(q.options, isMulti: false),
      QuestionType.multipleChoice => _choicePreview(q.options, isMulti: true),
      QuestionType.yesNo => _yesNoPreview(),
      QuestionType.scale => _scalePreview(q),
      QuestionType.openText => _textPreview(q),
    };
  }

  Widget _choicePreview(List<String> options, {required bool isMulti}) {
    if (options.isEmpty) {
      return Text('No options added yet', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic));
    }
    final show = options.take(4).toList();
    final extra = options.length - show.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...show.map((opt) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(
              isMulti ? Icons.check_box_outline_blank : Icons.radio_button_unchecked,
              size: 14,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(opt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 20),
            child: Text('+ $extra more', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _yesNoPreview() => Wrap(
    spacing: 8,
    children: ['Yes', 'No', 'Not Sure'].map((opt) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: Text(opt, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
    )).toList(),
  );

  Widget _scalePreview(SurveyQuestion q) {
    final min = q.scaleMin ?? 1;
    final max = q.scaleMax ?? 5;
    final count = (max - min + 1).clamp(1, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          children: List.generate(count, (i) {
            final val = min + i;
            return Container(
              width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300), color: Colors.grey.shade50),
              child: Center(child: Text('$val', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
            );
          }),
        ),
        if (q.scaleMinLabel != null || q.scaleMaxLabel != null) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (q.scaleMinLabel != null) Text(q.scaleMinLabel!, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              if (q.scaleMaxLabel != null) Text(q.scaleMaxLabel!, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _textPreview(SurveyQuestion q) => Container(
    padding: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
    child: Text(
      q.isRequired ? 'Long answer text...' : 'Long answer text... (optional)',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
    ),
  );

  // ── Type helpers ──────────────────────────────────────────────────────────

  String _typeLabel(QuestionType t) => switch (t) {
        QuestionType.singleChoice => 'Single',
        QuestionType.multipleChoice => 'Multi',
        QuestionType.scale => 'Scale',
        QuestionType.openText => 'Text',
        QuestionType.yesNo => 'Yes/No',
      };

  Color _typeColor(QuestionType t) => switch (t) {
        QuestionType.singleChoice => Colors.blue,
        QuestionType.multipleChoice => Colors.purple,
        QuestionType.scale => Colors.orange,
        QuestionType.openText => Colors.green,
        QuestionType.yesNo => Colors.teal,
      };

  IconData _typeIcon(QuestionType t) => switch (t) {
        QuestionType.singleChoice => Icons.radio_button_checked,
        QuestionType.multipleChoice => Icons.check_box_outlined,
        QuestionType.scale => Icons.linear_scale,
        QuestionType.openText => Icons.short_text,
        QuestionType.yesNo => Icons.toggle_on_outlined,
      };
}

// ── Section dialog ────────────────────────────────────────────────────────────

class _SectionDialog extends StatefulWidget {
  final _MutableSection? existing;
  final int? sectionIndex;
  final List<_MutableSection> allSections;
  final List<SurveyQuestion> allQuestions;

  const _SectionDialog({
    this.existing,
    this.sectionIndex,
    required this.allSections,
    required this.allQuestions,
  });

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late List<_MutableCondition> _conditions;
  late int? _defaultNext;
  bool _showRouting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _title = TextEditingController(text: s?.title ?? '');
    _subtitle = TextEditingController(text: s?.subtitle ?? '');
    _conditions = s?.conditions.map((c) => _MutableCondition.copy(c)).toList() ?? [];
    _defaultNext = s?.defaultNext;
    _showRouting = _conditions.isNotEmpty || s?.defaultNext != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  int get _endSentinel => widget.allSections.length;

  SurveyQuestion? _findQuestion(String? id) =>
      id == null ? null : widget.allQuestions.where((q) => q.id == id).firstOrNull;

  List<String> _optionsForQuestion(SurveyQuestion? q) {
    if (q == null) return [];
    return switch (q.type) {
      QuestionType.yesNo => ['Yes', 'No', 'Not Sure'],
      QuestionType.singleChoice || QuestionType.multipleChoice => q.options,
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Section' : 'Add Section'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Section Title *', border: OutlineInputBorder()),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitle,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Subtitle (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),

                // ── Section routing toggle ───────────────────────────────
                InkWell(
                  onTap: () => setState(() => _showRouting = !_showRouting),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _showRouting ? Colors.orange.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _showRouting ? Colors.orange.shade300 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alt_route, size: 16, color: _showRouting ? Colors.orange.shade700 : Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Section Routing / Skip Logic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _showRouting ? Colors.orange.shade800 : Colors.grey.shade600))),
                        Icon(_showRouting ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500, size: 18),
                      ],
                    ),
                  ),
                ),

                if (_showRouting) ...[
                  const SizedBox(height: 12),
                  if (widget.allQuestions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('Add questions to the survey first to set up routing.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    )
                  else ...[
                    // Condition rows
                    ...List.generate(_conditions.length, (i) => _buildConditionRow(i)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _conditions.add(_MutableCondition())),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add condition', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Default next
                    Text('Default (if no conditions match):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    _buildDefaultNextPicker(),
                  ],
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                _MutableSection(
                  widgetKey: widget.existing?.widgetKey,
                  title: _title.text.trim(),
                  subtitle: _subtitle.text.trim(),
                  questions: widget.existing?.questions ?? [],
                  conditions: _conditions,
                  defaultNext: _defaultNext,
                  isExpanded: widget.existing?.isExpanded ?? true,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildConditionRow(int index) {
    final cond = _conditions[index];
    final selectedQ = _findQuestion(cond.questionId);
    final qOptions = _optionsForQuestion(selectedQ);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.shade200, borderRadius: BorderRadius.circular(4)),
                child: Text('IF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.orange.shade900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(cond.questionId ?? '__none_$index'),
                  initialValue: cond.questionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                    hintText: 'Select question',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('(select question)', style: TextStyle(color: Colors.grey))),
                    ...widget.allQuestions.map((q) => DropdownMenuItem(
                      value: q.id,
                      child: Text('${q.code}: ${q.text}', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setState(() {
                    cond.questionId = v;
                    cond.matchValues.clear();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                tooltip: 'Remove',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _conditions.removeAt(index)),
              ),
            ],
          ),

          if (selectedQ != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.shade200, borderRadius: BorderRadius.circular(4)),
                  child: Text('IS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.orange.shade900)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: qOptions.isNotEmpty
                      ? Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: qOptions.map((opt) {
                            final sel = cond.matchValues.contains(opt);
                            return FilterChip(
                              label: Text(opt, style: const TextStyle(fontSize: 12)),
                              selected: sel,
                              onSelected: (v) => setState(() => v ? cond.matchValues.add(opt) : cond.matchValues.remove(opt)),
                              selectedColor: Colors.orange.shade100,
                              checkmarkColor: Colors.orange.shade800,
                              side: BorderSide(color: sel ? Colors.orange.shade400 : Colors.grey.shade300),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        )
                      : TextFormField(
                          initialValue: cond.matchValues.join(', '),
                          decoration: const InputDecoration(isDense: true, hintText: 'Value(s), comma-separated', border: OutlineInputBorder(), fillColor: Colors.white, filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          onChanged: (v) => setState(() {
                            cond.matchValues = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
                          }),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text('→', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.teal.shade800)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('target_${cond.targetSectionIndex}_$index'),
                    initialValue: cond.targetSectionIndex,
                    isExpanded: true,
                    decoration: InputDecoration(isDense: true, labelText: 'Jump to', border: const OutlineInputBorder(), fillColor: Colors.white, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('(select target)', style: TextStyle(color: Colors.grey))),
                      ...widget.allSections.asMap().entries
                          .where((e) => e.key != widget.sectionIndex)
                          .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('§${e.key + 1} ${e.value.title}', overflow: TextOverflow.ellipsis),
                          )),
                      DropdownMenuItem(value: _endSentinel, child: Row(children: [Icon(Icons.flag_outlined, size: 14, color: Colors.red.shade400), const SizedBox(width: 6), const Text('End of survey')])),
                    ],
                    onChanged: (v) => setState(() => cond.targetSectionIndex = v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultNextPicker() {
    final isEnd = _defaultNext == _endSentinel;
    final isNext = _defaultNext == null;
    final isJump = !isNext && !isEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _radioRow('Continue to next section', isNext, () => setState(() => _defaultNext = null)),
        const SizedBox(height: 4),
        _radioRow('End survey', isEnd, () => setState(() => _defaultNext = _endSentinel)),
        const SizedBox(height: 4),
        Row(
          children: [
            _radioRow('Jump to:', isJump, () {
              final others = widget.allSections.asMap().entries.where((e) => e.key != widget.sectionIndex).toList();
              if (others.isNotEmpty) setState(() => _defaultNext = others.first.key);
            }),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<int>(
                value: isJump ? _defaultNext : null,
                isExpanded: true,
                hint: const Text('Select section'),
                items: widget.allSections.asMap().entries
                    .where((e) => e.key != widget.sectionIndex)
                    .map((e) => DropdownMenuItem(value: e.key, child: Text('§${e.key + 1} ${e.value.title}', overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _defaultNext = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _radioRow(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Colors.orange.shade600 : Colors.grey.shade400, width: 2),
          ),
          child: selected
              ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.shade600)))
              : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    ),
  );
}

// ── Question dialog ───────────────────────────────────────────────────────────

class _QuestionDialog extends StatefulWidget {
  final SurveyQuestion? existing;
  final String suggestedCode;
  final List<SurveyQuestion> allQuestions;

  const _QuestionDialog({
    this.existing,
    this.suggestedCode = '',
    required this.allQuestions,
  });

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _code;
  late TextEditingController _text;
  late TextEditingController _note;
  late TextEditingController _scaleMin;
  late TextEditingController _scaleMax;
  late TextEditingController _scaleMinLabel;
  late TextEditingController _scaleMaxLabel;
  late TextEditingController _maxSel;
  late List<TextEditingController> _optionCtrls;
  late QuestionType _type;
  late bool _required;
  String? _condOnId;
  Set<String> _condValues = {};

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _code = TextEditingController(text: q?.code ?? widget.suggestedCode);
    _text = TextEditingController(text: q?.text ?? '');
    _note = TextEditingController(text: q?.note ?? '');
    _scaleMin = TextEditingController(text: '${q?.scaleMin ?? 1}');
    _scaleMax = TextEditingController(text: '${q?.scaleMax ?? 5}');
    _scaleMinLabel = TextEditingController(text: q?.scaleMinLabel ?? '');
    _scaleMaxLabel = TextEditingController(text: q?.scaleMaxLabel ?? '');
    _maxSel = TextEditingController(text: '${q?.maxSelections ?? ''}');
    _type = q?.type ?? QuestionType.singleChoice;
    _required = q?.isRequired ?? true;
    _condOnId = q?.conditionalOnId;
    _condValues = Set<String>.from(q?.conditionalOnValues ?? []);

    // Initialize option controllers
    final opts = q?.options ?? [];
    _optionCtrls = opts.isNotEmpty
        ? opts.map((o) => TextEditingController(text: o)).toList()
        : [TextEditingController(), TextEditingController()];
  }

  @override
  void dispose() {
    for (final c in [_code, _text, _note, _scaleMin, _scaleMax, _scaleMinLabel, _scaleMaxLabel, _maxSel]) { c.dispose(); }
    for (final c in _optionCtrls) { c.dispose(); }
    super.dispose();
  }

  String _genId() => '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  bool get _hasOptions => _type == QuestionType.singleChoice || _type == QuestionType.multipleChoice;
  bool get _isScale => _type == QuestionType.scale;

  SurveyQuestion _buildQuestion() {
    final opts = _hasOptions
        ? _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return SurveyQuestion(
      id: widget.existing?.id ?? _genId(),
      code: _code.text.trim(),
      text: _text.text.trim(),
      type: _type,
      options: opts,
      isRequired: _required,
      maxSelections: _type == QuestionType.multipleChoice && _maxSel.text.isNotEmpty
          ? int.tryParse(_maxSel.text)
          : null,
      scaleMin: _isScale ? (int.tryParse(_scaleMin.text) ?? 1) : null,
      scaleMax: _isScale ? (int.tryParse(_scaleMax.text) ?? 5) : null,
      scaleMinLabel: _isScale && _scaleMinLabel.text.isNotEmpty ? _scaleMinLabel.text.trim() : null,
      scaleMaxLabel: _isScale && _scaleMaxLabel.text.isNotEmpty ? _scaleMaxLabel.text.trim() : null,
      note: _note.text.isNotEmpty ? _note.text.trim() : null,
      conditionalOnId: _condOnId,
      conditionalOnValues: _condOnId != null && _condValues.isNotEmpty ? _condValues.toList() : null,
    );
  }

  List<String> _condOptionsFor(String? qId) {
    if (qId == null) return [];
    final q = widget.allQuestions.where((q) => q.id == qId).firstOrNull;
    if (q == null) return [];
    return switch (q.type) {
      QuestionType.yesNo => ['Yes', 'No', 'Not Sure'],
      QuestionType.singleChoice || QuestionType.multipleChoice => q.options,
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final otherQuestions = widget.allQuestions.where((q) => q.id != (widget.existing?.id ?? '')).toList();
    final condOpts = _condOptionsFor(_condOnId);

    return AlertDialog(
      title: Row(children: [
        Icon(_typeIcon(_type), color: _typeColor(_type), size: 20),
        const SizedBox(width: 8),
        Text(widget.existing == null ? 'Add Question' : 'Edit Question'),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Code + Type ────────────────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<QuestionType>(
                        key: ValueKey(_type.name),
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Answer Type', border: OutlineInputBorder()),
                        items: QuestionType.values.map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Icon(_typeIcon(t), size: 16, color: _typeColor(t)),
                            const SizedBox(width: 8),
                            Text(_typeLabelFull(t)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() => _type = v ?? QuestionType.singleChoice),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Question text ──────────────────────────────────────────
                TextFormField(
                  controller: _text,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Question Text *', border: OutlineInputBorder()),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                ),

                // ── Options (choice) ──────────────────────────────────────
                if (_hasOptions) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      if (_type == QuestionType.multipleChoice)
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _maxSel,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max select', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_optionCtrls.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          _type == QuestionType.multipleChoice ? Icons.check_box_outline_blank : Icons.radio_button_unchecked,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _optionCtrls[i],
                            decoration: InputDecoration(
                              hintText: 'Option ${i + 1}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 15, color: Colors.red),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: _optionCtrls.length > 1
                              ? () => setState(() {
                                    _optionCtrls[i].dispose();
                                    _optionCtrls.removeAt(i);
                                  })
                              : null,
                        ),
                      ],
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () => setState(() => _optionCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add option'),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal.shade700),
                  ),
                ],

                // ── Scale ──────────────────────────────────────────────────
                if (_isScale) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _scaleMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min value', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _scaleMax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max value', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _scaleMinLabel, decoration: const InputDecoration(labelText: 'Min label', border: OutlineInputBorder()))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _scaleMaxLabel, decoration: const InputDecoration(labelText: 'Max label', border: OutlineInputBorder()))),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Helper note (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required'),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                ),

                // ── Skip logic ─────────────────────────────────────────────
                const Divider(height: 24),
                Text('Skip / Show Logic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                if (otherQuestions.isEmpty)
                  Text('Add more questions to the survey to enable skip logic.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
                else ...[
                  Text('Show this question only if:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_condOnId ?? '__none__'),
                    initialValue: _condOnId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Another question...', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('(always show)')),
                      ...otherQuestions.map((q) => DropdownMenuItem(
                        value: q.id,
                        child: Text('${q.code}: ${q.text}', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setState(() { _condOnId = v; _condValues.clear(); }),
                  ),
                  if (_condOnId != null) ...[
                    const SizedBox(height: 10),
                    Text('Has answer:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    condOpts.isNotEmpty
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: condOpts.map((opt) {
                              final sel = _condValues.contains(opt);
                              return FilterChip(
                                label: Text(opt, style: const TextStyle(fontSize: 12)),
                                selected: sel,
                                onSelected: (v) => setState(() => v ? _condValues.add(opt) : _condValues.remove(opt)),
                                selectedColor: Colors.teal.shade100,
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          )
                        : TextFormField(
                            initialValue: _condValues.join(', '),
                            decoration: const InputDecoration(hintText: 'Value(s), comma-separated', border: OutlineInputBorder()),
                            onChanged: (v) => _condValues = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet(),
                          ),
                  ],
                ],

                // ── Answer Preview ─────────────────────────────────────────
                const SizedBox(height: 16),
                _buildPreviewBox(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _buildQuestion());
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildPreviewBox() {
    final q = _buildQuestion();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.preview_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 10),
          Text.rich(TextSpan(
            text: q.text.isEmpty ? 'Question text...' : q.text,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: q.text.isEmpty ? Colors.grey.shade400 : Colors.black87),
            children: q.isRequired ? [TextSpan(text: ' *', style: TextStyle(color: Colors.red.shade600))] : [],
          )),
          const SizedBox(height: 10),
          _previewAnswer(q),
        ],
      ),
    );
  }

  Widget _previewAnswer(SurveyQuestion q) {
    return switch (q.type) {
      QuestionType.singleChoice || QuestionType.multipleChoice => q.options.isEmpty
          ? Text('(no options yet)', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: q.options.take(3).map((opt) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(q.type == QuestionType.multipleChoice ? Icons.check_box_outline_blank : Icons.radio_button_unchecked, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(opt, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ]),
              )).toList(),
            ),
      QuestionType.yesNo => Wrap(
          spacing: 8,
          children: ['Yes', 'No', 'Not Sure'].map((o) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: Text(o, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          )).toList(),
        ),
      QuestionType.scale => Row(
          children: List.generate(min((q.scaleMax ?? 5) - (q.scaleMin ?? 1) + 1, 10), (i) {
            final val = (q.scaleMin ?? 1) + i;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                child: Center(child: Text('$val', style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
              ),
            );
          }),
        ),
      QuestionType.openText => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300), color: Colors.white),
          child: Text(q.isRequired ? 'Your answer...' : 'Your answer (optional)...', style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ),
    };
  }

  String _typeLabelFull(QuestionType t) => switch (t) {
        QuestionType.singleChoice => 'Single Choice',
        QuestionType.multipleChoice => 'Multiple Choice',
        QuestionType.scale => 'Scale (Rating)',
        QuestionType.openText => 'Open Text',
        QuestionType.yesNo => 'Yes / No',
      };

  Color _typeColor(QuestionType t) => switch (t) {
        QuestionType.singleChoice => Colors.blue,
        QuestionType.multipleChoice => Colors.purple,
        QuestionType.scale => Colors.orange,
        QuestionType.openText => Colors.green,
        QuestionType.yesNo => Colors.teal,
      };

  IconData _typeIcon(QuestionType t) => switch (t) {
        QuestionType.singleChoice => Icons.radio_button_checked,
        QuestionType.multipleChoice => Icons.check_box_outlined,
        QuestionType.scale => Icons.linear_scale,
        QuestionType.openText => Icons.short_text,
        QuestionType.yesNo => Icons.toggle_on_outlined,
      };
}
