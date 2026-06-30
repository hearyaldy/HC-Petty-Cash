import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/survey.dart';
import '../../providers/auth_provider.dart';
import '../../providers/survey_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class AdminSurveysScreen extends StatefulWidget {
  const AdminSurveysScreen({super.key});

  @override
  State<AdminSurveysScreen> createState() => _AdminSurveysScreenState();
}

class _AdminSurveysScreenState extends State<AdminSurveysScreen> {
  final Map<String, int> _responseCounts = {};

  @override
  void initState() {
    super.initState();
    final provider = context.read<SurveyProvider>();
    provider.watchSurveys();
    provider.seedIfNeeded();
  }

  Future<void> _loadCounts(List<Survey> surveys) async {
    final provider = context.read<SurveyProvider>();
    for (final s in surveys) {
      if (!_responseCounts.containsKey(s.id)) {
        final count = await provider.getResponseCount(s.id);
        if (mounted) setState(() => _responseCounts[s.id] = count);
      }
    }
  }

  Future<void> _toggleActive(Survey survey) =>
      context.read<SurveyProvider>().setActive(survey.id, active: !survey.isActive);

  Future<void> _deleteSurvey(Survey survey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Survey'),
        content: Text(
          'Delete "${survey.title}"? This cannot be undone. Response data will remain.',
        ),
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
    if (confirmed != true || !mounted) return;
    await context.read<SurveyProvider>().deleteSurvey(survey.id);
  }

  Future<void> _reseed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Re-seed Surveys'),
        content: const Text(
          'This will overwrite Surveys A, B, and C with the originals from the MI documents. Custom surveys and response data are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Re-seed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SurveyProvider>().reseed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surveys A, B, C re-seeded'), backgroundColor: Colors.green),
      );
    }
  }

  void _openCreateDialog() => _showEditDialog(null);

  void _openEditDialog(Survey survey) => _showEditDialog(survey);

  void _showEditDialog(Survey? existing) {
    showDialog<void>(
      context: context,
      builder: (_) => _SurveyMetaDialog(
        existing: existing,
        onSaved: (survey) async {
          final provider = context.read<SurveyProvider>();
          if (existing == null) {
            await provider.createSurvey(survey);
          } else {
            await provider.updateSurveyMeta(existing.id, {
              'code': survey.code,
              'title': survey.title,
              'description': survey.description,
              'targetAudience': survey.targetAudience,
              'isPublic': survey.isPublic,
              'estimatedMinutes': survey.estimatedMinutes,
              'isActive': survey.isActive,
            });
          }
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.canManageUsers()) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }
    final provider = context.watch<SurveyProvider>();
    final surveys = provider.surveys;
    if (surveys.isNotEmpty) _loadCounts(surveys);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildPageHeader(context),
              const SizedBox(height: 20),
              if (provider.error != null)
                _buildErrorBanner(provider.error!),
              if (provider.loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              else if (surveys.isEmpty)
                _buildEmpty()
              else
                _buildSurveyGrid(context, surveys),
              const SizedBox(height: 40),
            ],
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
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4)),
          ],
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
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text('HC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('MI Surveys', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Mission Intelligence', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        tooltip: 'Re-seed A/B/C',
                        onPressed: _reseed,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                        tooltip: 'Create New Survey',
                        onPressed: _openCreateDialog,
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

  Widget _buildPageHeader(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.cyan.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.shade200.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.poll_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Survey Management',
                    style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Create, edit, and manage MI surveys. Toggle active to open for responses.',
                    style: TextStyle(fontSize: isMobile ? 11 : 13, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Survey'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.teal.shade700,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
        child: Row(children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ]),
      );

  Widget _buildEmpty() => Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.poll_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No surveys found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Click the refresh icon to seed the 3 MI surveys, or create a new one.',
                    style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _reseed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Seed MI Surveys (A, B, C)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSurveyGrid(BuildContext context, List<Survey> surveys) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    if (isDesktop) {
      // 2-column grid on desktop
      return LayoutBuilder(builder: (context, constraints) {
        final colW = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: surveys.map((s) => SizedBox(width: colW, child: _buildCard(s))).toList(),
        );
      });
    }
    return Column(
      children: surveys.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildCard(s),
      )).toList(),
    );
  }

  Widget _buildCard(Survey survey) {
    final count = _responseCounts[survey.id];
    final audienceColor = _audienceColor(survey.targetAudience);
    final surveyUrl = _surveyUrl(survey.id);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: badge + active toggle ──────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.teal.shade600, borderRadius: BorderRadius.circular(8)),
                  child: Text('Survey ${survey.code}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: audienceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_audienceLabel(survey.targetAudience),
                      style: TextStyle(color: audienceColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Switch(
                  value: survey.isActive,
                  onChanged: (_) => _toggleActive(survey),
                  activeThumbColor: Colors.teal,
                ),
                Text(
                  survey.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 12, color: survey.isActive ? Colors.teal : Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Title + description ──────────────────────────────────────
            Text(survey.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(survey.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            // ── Stats row ────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              children: [
                _stat(Icons.quiz_outlined, '${survey.totalQuestions} questions'),
                _stat(Icons.timer_outlined, '~${survey.estimatedMinutes} min'),
                _stat(Icons.people_outline, '${count ?? '…'} responses'),
                _stat(survey.isPublic ? Icons.public : Icons.lock_outline,
                    survey.isPublic ? 'Public link' : 'Login required'),
              ],
            ),
            // ── Public link ──────────────────────────────────────────────
            if (survey.isPublic && survey.isActive) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.link, size: 13, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(surveyUrl, style: TextStyle(fontSize: 11, color: Colors.teal.shade700), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // ── Action buttons ───────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/surveys/${survey.id}/responses'),
                  icon: const Icon(Icons.bar_chart, size: 15),
                  label: Text('Responses${count != null ? ' ($count)' : ''}'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade700),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/surveys/${survey.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit Questions'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo.shade700),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditDialog(survey),
                  icon: const Icon(Icons.settings_outlined, size: 15),
                  label: const Text('Settings'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/survey/${survey.id}'),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan.shade700),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyLink(surveyUrl),
                  icon: const Icon(Icons.link, size: 15),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showQrDialog(survey),
                  icon: const Icon(Icons.qr_code, size: 15),
                  label: const Text('QR Code'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.purple.shade700),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'Delete survey',
                  onPressed: () => _deleteSurvey(survey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );

  String _surveyUrl(String surveyId) {
    if (kIsWeb) return '${Uri.base.origin}/survey/$surveyId';
    return 'https://hc-petty-cash-report.web.app/survey/$surveyId';
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey link copied to clipboard'), backgroundColor: Colors.teal),
      );
    }
  }

  void _showQrDialog(Survey survey) {
    final url = _surveyUrl(survey.id);
    showDialog<void>(
      context: context,
      builder: (_) => _QrDialog(survey: survey, url: url),
    );
  }

  String _audienceLabel(String v) => switch (v) {
        'public' => 'General Public',
        'leaders' => 'Church Leaders',
        'members' => 'Church Members',
        _ => v,
      };

  Color _audienceColor(String v) => switch (v) {
        'public' => Colors.blue,
        'leaders' => Colors.purple,
        'members' => Colors.teal,
        _ => Colors.grey,
      };
}

// ── Create / Edit survey metadata dialog ──────────────────────────────────────

class _SurveyMetaDialog extends StatefulWidget {
  final Survey? existing;
  final Future<void> Function(Survey) onSaved;

  const _SurveyMetaDialog({required this.existing, required this.onSaved});

  @override
  State<_SurveyMetaDialog> createState() => _SurveyMetaDialogState();
}

class _SurveyMetaDialogState extends State<_SurveyMetaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _minutes;
  late String _audience;
  late bool _isPublic;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _code = TextEditingController(text: s?.code ?? '');
    _title = TextEditingController(text: s?.title ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _minutes = TextEditingController(text: '${s?.estimatedMinutes ?? 10}');
    _audience = s?.targetAudience ?? 'public';
    _isPublic = s?.isPublic ?? true;
    _isActive = s?.isActive ?? false;
  }

  @override
  void dispose() {
    _code.dispose(); _title.dispose(); _description.dispose(); _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final survey = Survey(
        id: widget.existing?.id ?? '',
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        targetAudience: _audience,
        isActive: _isActive,
        isPublic: _isPublic,
        estimatedMinutes: int.tryParse(_minutes.text.trim()) ?? 10,
        sections: widget.existing?.sections ?? [],
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await widget.onSaved(survey);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Survey Settings' : 'Create New Survey'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minutes,
                      decoration: const InputDecoration(labelText: 'Est. minutes', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(_audience),
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'Target Audience', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('General Public')),
                    DropdownMenuItem(value: 'leaders', child: Text('Church Leaders')),
                    DropdownMenuItem(value: 'members', child: Text('Church Members')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (v) => setState(() => _audience = v ?? 'public'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public link (no login required)'),
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),
                  ),
                ]),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active (accepting responses)'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

// ── QR Code dialog ────────────────────────────────────────────────────────────

class _QrDialog extends StatefulWidget {
  final Survey survey;
  final String url;

  const _QrDialog({required this.survey, required this.url});

  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  bool _copied = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.qr_code, color: Colors.teal.shade700, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Survey ${widget.survey.code}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('QR Code & Share Link',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: QrImageView(
                data: widget.url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Survey name
            Text(
              widget.survey.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.survey.isPublic ? Icons.public : Icons.lock_outline,
                  size: 13,
                  color: widget.survey.isPublic ? Colors.teal : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.survey.isPublic ? 'Public — no login required' : 'Private — login required',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.survey.isPublic ? Colors.teal.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Link row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.url,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _copyLink,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _copied
                          ? const Icon(Icons.check_circle, size: 18, color: Colors.teal, key: ValueKey('check'))
                          : Icon(Icons.copy_outlined, size: 18, color: Colors.grey.shade600, key: const ValueKey('copy')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _copyLink,
          icon: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 16),
          label: Text(_copied ? 'Copied!' : 'Copy Link'),
          style: TextButton.styleFrom(foregroundColor: Colors.teal.shade700),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
