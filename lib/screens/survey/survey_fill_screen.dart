import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/survey.dart';
import '../../models/survey_response.dart';
import '../../providers/auth_provider.dart';
import '../../providers/survey_provider.dart';

class SurveyFillScreen extends StatefulWidget {
  final String surveyId;
  const SurveyFillScreen({super.key, required this.surveyId});

  @override
  State<SurveyFillScreen> createState() => _SurveyFillScreenState();
}

class _SurveyFillScreenState extends State<SurveyFillScreen> {
  Survey? _survey;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  int _sectionIndex = 0;
  final List<int> _sectionHistory = [];

  // questionId → String | List<String> | int
  final Map<String, dynamic> _answers = {};

  // Design constants
  static const _accent = Color(0xFF00897B);
  static const _pageBg = Color(0xFFF0F4F8);
  static const _maxWidth = 680.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<SurveyProvider>().getSurvey(widget.surveyId);
    if (mounted) setState(() { _survey = s; _loading = false; });
  }

  // ── Conditional logic ─────────────────────────────────────────────────────

  bool _shouldShow(SurveyQuestion q) {
    if (q.conditionalOnId == null) return true;
    final answer = _answers[q.conditionalOnId];
    if (answer == null) return false;
    final vals = q.conditionalOnValues;
    if (vals == null) return true;
    if (answer is String) return vals.contains(answer);
    if (answer is List<String>) return answer.any(vals.contains);
    return false;
  }

  List<SurveyQuestion> get _visibleQuestions {
    if (_survey == null) return [];
    return _survey!.sections[_sectionIndex].questions
        .where(_shouldShow)
        .toList();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _sectionValid() {
    for (final q in _visibleQuestions) {
      if (!q.isRequired) continue;
      final v = _answers[q.id];
      if (v == null) return false;
      if (v is String && v.trim().isEmpty) return false;
      if (v is List && v.isEmpty) return false;
    }
    return true;
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (!_sectionValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Please answer all required questions before continuing.')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final sections = _survey!.sections;
    final section = sections[_sectionIndex];

    // Evaluate section routing conditions in order
    int nextIndex = section.defaultNext ?? (_sectionIndex + 1);
    for (final cond in section.conditions) {
      final answer = _answers[cond.questionId];
      bool matches = false;
      if (answer is String) {
        matches = cond.matchValues.contains(answer);
      } else if (answer is List) {
        matches = answer.any((v) => cond.matchValues.contains(v.toString()));
      }
      if (matches) {
        nextIndex = cond.targetSectionIndex;
        break;
      }
    }

    _sectionHistory.add(_sectionIndex);
    if (nextIndex >= sections.length) {
      _submit();
    } else {
      setState(() => _sectionIndex = nextIndex);
    }
  }

  void _back() {
    if (_sectionHistory.isNotEmpty) {
      setState(() => _sectionIndex = _sectionHistory.removeLast());
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final user = context.read<AuthProvider>().currentUser;

      String? country;
      for (final section in _survey!.sections) {
        for (final q in section.questions) {
          final v = _answers[q.id];
          if (v is String && _isCountry(v)) { country = v; break; }
        }
        if (country != null) break;
      }

      final response = SurveyResponse(
        id: '',
        surveyId: _survey!.id,
        surveyCode: _survey!.code,
        respondentId: user?.id,
        respondentName: user?.name,
        country: country,
        submittedAt: DateTime.now(),
        answers: _answers.entries
            .map((e) => SurveyAnswer(questionId: e.key, value: e.value))
            .toList(),
      );

      await context.read<SurveyProvider>().submitResponse(response);
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isCountry(String v) => const [
    'Cambodia', 'Laos', 'Malaysia', 'Brunei', 'Thailand', 'Vietnam',
  ].contains(v);

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _pageBg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    if (_survey == null) {
      return _buildNotFound();
    }
    final isAdmin = context.read<AuthProvider>().canManageUsers();
    if (!_survey!.isActive && !isAdmin) {
      return _buildInactive();
    }
    if (_submitted) return _buildThankYou();
    return _buildForm(isAdmin: isAdmin);
  }

  // ── Not found ─────────────────────────────────────────────────────────────

  Widget _buildNotFound() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text('Survey not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Inactive ──────────────────────────────────────────────────────────────

  Widget _buildInactive() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 6, color: Colors.grey.shade400),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 36),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pause_circle_outline_rounded,
                              size: 48, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _survey!.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This survey is currently closed.',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check back later or contact the survey administrator.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main form ─────────────────────────────────────────────────────────────

  Widget _buildForm({required bool isAdmin}) {
    final survey = _survey!;
    final section = survey.sections[_sectionIndex];
    final totalSections = survey.sections.length;
    final progress = (_sectionIndex + 1) / totalSections;
    final isLast = _sectionIndex == totalSections - 1;
    final isAdminPreview = !survey.isActive && isAdmin;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Thin progress bar ──────────────────────────────────────────
            LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.teal.shade50,
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),

            // ── Admin preview banner ───────────────────────────────────────
            if (isAdminPreview)
              Container(
                width: double.infinity,
                color: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin Preview — survey is inactive. Submitted responses will still be saved.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title card — only on first section
                          if (_sectionIndex == 0) ...[
                            _buildTitleCard(survey),
                            const SizedBox(height: 12),
                          ],

                          // Section header
                          if (totalSections > 1 || section.subtitle.isNotEmpty) ...[
                            _buildSectionHeaderCard(
                              section,
                              num: totalSections > 1 ? _sectionIndex + 1 : null,
                              total: totalSections > 1 ? totalSections : null,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Questions
                          ..._visibleQuestions.map(_buildQuestionCard),

                          const SizedBox(height: 8),
                          _buildNavRow(isLast),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Title card ────────────────────────────────────────────────────────────

  Widget _buildTitleCard(Survey survey) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 8, color: _accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Survey code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MI Survey',
                    style: TextStyle(
                      color: _accent, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  survey.title,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, height: 1.25,
                  ),
                ),

                // Description
                if (survey.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    survey.description,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700, height: 1.55),
                  ),
                ],

                const SizedBox(height: 16),

                // Meta chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip(Icons.timer_outlined,
                        '~${survey.estimatedMinutes} min'),
                    _metaChip(Icons.quiz_outlined,
                        '${survey.totalQuestions} questions'),
                    if (survey.isPublic)
                      _metaChip(Icons.public, 'Anyone can respond',
                          color: Colors.green.shade700,
                          bg: Colors.green.shade50),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Required note
                Row(
                  children: [
                    Text('* ',
                        style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w700)),
                    Text('Required questions',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label,
      {Color? color, Color? bg}) {
    final c = color ?? const Color(0xFF78909C);
    final background = bg ?? const Color(0xFFECEFF1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Section header card ───────────────────────────────────────────────────

  Widget _buildSectionHeaderCard(SurveySection section,
      {int? num, int? total}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _accent, width: 5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (num != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Section $num of $total',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5),
                ),
              ),
            Text(
              section.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (section.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                section.subtitle,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Question card ─────────────────────────────────────────────────────────

  Widget _buildQuestionCard(SurveyQuestion q) {
    final v = _answers[q.id];
    final hasAnswer = v != null &&
        (v is! String || v.isNotEmpty) &&
        (v is! List || v.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: hasAnswer ? 2 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: hasAnswer ? _accent : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question text row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.code.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        q.code,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF80CBC4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: q.text,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.4),
                        children: q.isRequired
                            ? [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w700),
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                ],
              ),

              // Note / helper text
              if (q.note != null && q.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  q.note!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                      height: 1.4),
                ),
              ],

              const SizedBox(height: 14),
              _buildInput(q),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(SurveyQuestion q) {
    return switch (q.type) {
      QuestionType.singleChoice => _buildSingleChoice(q),
      QuestionType.multipleChoice => _buildMultiChoice(q),
      QuestionType.scale => _buildScale(q),
      QuestionType.openText => _buildOpenText(q),
      QuestionType.yesNo => _buildYesNo(q),
    };
  }

  // ── Single choice ─────────────────────────────────────────────────────────

  Widget _buildSingleChoice(SurveyQuestion q) {
    final selected = _answers[q.id] as String?;
    return Column(
      children: q.options.map((opt) {
        return _selectableRow(
          isSelected: selected == opt,
          isCircle: true,
          label: opt,
          onTap: () => setState(() => _answers[q.id] = opt),
        );
      }).toList(),
    );
  }

  // ── Multiple choice ───────────────────────────────────────────────────────

  Widget _buildMultiChoice(SurveyQuestion q) {
    final selected = (_answers[q.id] as List<String>?) ?? [];
    final maxSel = q.maxSelections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (maxSel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Select up to $maxSel option${maxSel > 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ...q.options.map((opt) {
          final isSelected = selected.contains(opt);
          return _selectableRow(
            isSelected: isSelected,
            isCircle: false,
            label: opt,
            onTap: () => setState(() {
              final list = List<String>.from(selected);
              if (isSelected) {
                list.remove(opt);
              } else {
                if (maxSel == null || list.length < maxSel) list.add(opt);
              }
              _answers[q.id] = list;
            }),
          );
        }),
      ],
    );
  }

  // ── Shared selectable row ─────────────────────────────────────────────────

  Widget _selectableRow({
    required bool isSelected,
    required bool isCircle,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: isCircle
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? _accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? _accent : Colors.grey.shade400,
                        width: isSelected ? 2 : 1.5,
                      ),
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isSelected ? _accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? _accent : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
              child: isSelected
                  ? isCircle
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? const Color(0xFF00695C)
                      : Colors.black87,
                  fontWeight:
                      isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Scale ─────────────────────────────────────────────────────────────────

  Widget _buildScale(SurveyQuestion q) {
    final min = q.scaleMin ?? 1;
    final max = q.scaleMax ?? 5;
    final current = _answers[q.id] as int?;
    final count = max - min + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 8.0 * (count - 1);
            final btnSize = ((constraints.maxWidth - spacing) / count)
                .clamp(36.0, 58.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(count, (i) {
                final val = min + i;
                final sel = current == val;
                return GestureDetector(
                  onTap: () => setState(() => _answers[q.id] = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: btnSize,
                    height: btnSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? _accent : Colors.white,
                      border: Border.all(
                        color: sel ? _accent : Colors.grey.shade300,
                        width: sel ? 0 : 1.5,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        '$val',
                        style: TextStyle(
                          fontSize: btnSize < 44 ? 12 : 14,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: sel
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        if (q.scaleMinLabel != null || q.scaleMaxLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(q.scaleMinLabel ?? '$min',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              Text(q.scaleMaxLabel ?? '$max',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ],
    );
  }

  // ── Open text ─────────────────────────────────────────────────────────────

  Widget _buildOpenText(SurveyQuestion q) {
    return TextFormField(
      key: ValueKey(q.id),
      initialValue: _answers[q.id] as String?,
      minLines: 3,
      maxLines: 6,
      style: const TextStyle(fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText:
            q.isRequired ? 'Your answer' : 'Your answer (optional)',
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _accent, width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
      onChanged: (v) =>
          setState(() => _answers[q.id] = v.trim().isEmpty ? null : v),
    );
  }

  // ── Yes / No ──────────────────────────────────────────────────────────────

  Widget _buildYesNo(SurveyQuestion q) {
    final selected = _answers[q.id] as String?;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: ['Yes', 'No', 'Not Sure'].map((opt) {
        final sel = selected == opt;
        return GestureDetector(
          onTap: () => setState(() => _answers[q.id] = opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: sel ? _accent : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: sel ? _accent : Colors.grey.shade300,
                width: sel ? 0 : 1.5,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ],
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: sel ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Navigation row ────────────────────────────────────────────────────────

  Widget _buildNavRow(bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (_sectionIndex > 0)
            OutlinedButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _submitting ? null : _next,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 17),
            label: Text(isLast ? 'Submit' : 'Next'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Thank you page ────────────────────────────────────────────────────────

  Widget _buildThankYou() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 8, color: _accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0F2F1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 56,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Thank you!',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your response has been submitted successfully.',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                              height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your input helps Hope Channel Southeast Asia create '
                          'better content for the people in your community.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              height: 1.55),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'hope starts here.',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: _accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
