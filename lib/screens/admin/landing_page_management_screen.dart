import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/edit_testimonial_dialog.dart';

/// Editable content for the public landing page (web/landing.html), stored
/// as a single Firestore document that the static page fetches at load time.
class LandingPageManagementScreen extends StatefulWidget {
  const LandingPageManagementScreen({super.key});

  @override
  State<LandingPageManagementScreen> createState() =>
      _LandingPageManagementScreenState();
}

class _LandingPageManagementScreenState
    extends State<LandingPageManagementScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _heroTitleController = TextEditingController();
  final _heroSubtitleController = TextEditingController();
  final _heroVideoIdController = TextEditingController();
  final _lineGroupUrlController = TextEditingController();

  final _videoTitleController = TextEditingController();
  final _videoSubtitleController = TextEditingController();
  final _videoIdController = TextEditingController();
  final _videoDateLabelController = TextEditingController();

  List<Map<String, dynamic>> _testimonials = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _heroTitleController.dispose();
    _heroSubtitleController.dispose();
    _heroVideoIdController.dispose();
    _lineGroupUrlController.dispose();
    _videoTitleController.dispose();
    _videoSubtitleController.dispose();
    _videoIdController.dispose();
    _videoDateLabelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('site_config')
          .doc('landing_page')
          .get();
      final data = doc.data();

      // Defaults mirror the hardcoded fallback content in web/landing.html,
      // so the form starts pre-filled with real content on first use.
      _heroTitleController.text =
          data?['heroTitle'] ?? 'คุณไม่ได้อยู่คนเดียว';
      _heroSubtitleController.text = data?['heroSubtitle'] ??
          'เคยอธิษฐานแล้วรู้สึกเหมือนไม่มีใครได้ยินไหม? '
              'ชุมชนนี้มีไว้เพื่อช่วงเวลาแบบนั้น ดูวิดีโอสัปดาห์นี้ '
              'แล้วบอกเล่าสิ่งที่อยู่ในใจ — เราจะอธิษฐานด้วยกัน';
      _heroVideoIdController.text = data?['heroVideoId'] ?? '8K0XHvZVCUQ';
      _lineGroupUrlController.text =
          data?['lineGroupUrl'] ?? 'https://line.me/R/ti/g/TjkjXDbCwt';

      final videoMessage = data?['videoMessage'] as Map<String, dynamic>?;
      _videoTitleController.text =
          videoMessage?['title'] ?? 'เมื่อพระเจ้าดูเหมือนเงียบ';
      _videoSubtitleController.text =
          videoMessage?['subtitle'] ?? 'เรื่องของฮันนาห์';
      _videoIdController.text = videoMessage?['youtubeId'] ?? '8K0XHvZVCUQ';
      _videoDateLabelController.text =
          videoMessage?['dateLabel'] ?? 'มิถุนายน 2025';

      final testimonials = data?['testimonials'] as List<dynamic>?;
      _testimonials = testimonials != null
          ? testimonials
              .map((t) => Map<String, dynamic>.from(t as Map))
              .toList()
          : [
              {
                'text':
                    'ฉันเจอชุมชนนี้ในช่วงเวลาที่ยากที่สุดในชีวิต ไม่รู้ว่าพระเจ้ายังฟังอยู่ไหม '
                        'แต่สารเหล่านี้ทำให้ฉันนึกได้ว่า พระองค์ฟังอยู่ตลอด',
                'author': 'ณัฐยา ช.',
                'location': 'เชียงใหม่',
                'initials': 'NC',
              },
              {
                'text':
                    'ส่งคำขอการอธิษฐานไปโดยไม่ได้คาดหวังอะไรมาก แต่มีคนเขียนกลับมาและอธิษฐานด้วยกันกับฉัน '
                        'แค่นั้นทำให้รู้สึกว่าตัวเองมีคุณค่า',
                'author': 'อาหมัด ร.',
                'location': 'กรุงเทพฯ',
                'initials': 'AR',
              },
              {
                'text':
                    'อยู่ห่างบ้านและหาคนที่ใส่ใจจริงๆ ไม่เจอ ชุมชนนี้กลายเป็นสิ่งที่ตั้งตารอทุกสัปดาห์ '
                        '— คนจริง ความเชื่อจริง ไม่มีการแกล้งทำ',
                'author': 'โซฟี ม.',
                'location': 'กรุงเทพฯ',
                'initials': 'SM',
              },
            ];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading landing page content: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final email =
          context.read<AuthProvider>().currentUser?.email ?? 'unknown';

      // Whole-document overwrite, not a merge-update — a web manager who has
      // this screen open in two tabs will last-write-wins clobber the other
      // tab. Acceptable for a single non-technical editor; not building
      // optimistic locking for this.
      await FirebaseFirestore.instance
          .collection('site_config')
          .doc('landing_page')
          .set({
        'heroTitle': _heroTitleController.text.trim(),
        'heroSubtitle': _heroSubtitleController.text.trim(),
        'heroVideoId': _heroVideoIdController.text.trim(),
        'lineGroupUrl': _lineGroupUrlController.text.trim(),
        'videoMessage': {
          'title': _videoTitleController.text.trim(),
          'subtitle': _videoSubtitleController.text.trim(),
          'youtubeId': _videoIdController.text.trim(),
          'dateLabel': _videoDateLabelController.text.trim(),
        },
        'testimonials': _testimonials,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': email,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Landing page updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addOrEditTestimonial({int? index}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTestimonialDialog(
        testimonial: index != null ? _testimonials[index] : null,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _testimonials[index] = result;
      } else {
        _testimonials.add(result);
      }
    });
  }

  void _removeTestimonial(int index) {
    setState(() => _testimonials.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveContainer(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'Hero Section',
                      children: [
                        TextField(
                          controller: _heroTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Hero Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _heroSubtitleController,
                          decoration: const InputDecoration(
                            labelText: 'Hero Subtitle',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _heroVideoIdController,
                          decoration: const InputDecoration(
                            labelText: 'Hero YouTube Video ID',
                            helperText:
                                'Just the ID, e.g. 8K0XHvZVCUQ from youtube.com/watch?v=8K0XHvZVCUQ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _lineGroupUrlController,
                          decoration: const InputDecoration(
                            labelText: 'LINE Group URL',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: "This Week's Video",
                      children: [
                        TextField(
                          controller: _videoTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _videoSubtitleController,
                          decoration: const InputDecoration(
                            labelText: 'Subtitle',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _videoIdController,
                          decoration: const InputDecoration(
                            labelText: 'YouTube Video ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _videoDateLabelController,
                          decoration: const InputDecoration(
                            labelText: 'Date Label',
                            helperText: 'e.g. มิถุนายน 2025',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      title: 'Testimonials',
                      trailing: _testimonials.length >= 5
                          ? null
                          : TextButton.icon(
                              onPressed: () => _addOrEditTestimonial(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                      children: [
                        if (_testimonials.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No testimonials yet.'),
                          ),
                        for (var i = 0; i < _testimonials.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                child: Text(
                                  (_testimonials[i]['initials'] ?? '')
                                      .toString(),
                                ),
                              ),
                              title: Text(
                                _testimonials[i]['text'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${_testimonials[i]['author'] ?? ''} — ${_testimonials[i]['location'] ?? ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _addOrEditTestimonial(index: i),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeTestimonial(i),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 32),
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
    final isPhone = MediaQuery.of(context).size.width < 430;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
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
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'HC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Landing Page',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isPhone
                                  ? 'Public website content'
                                  : 'Public website content management',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.white),
                        tooltip: 'View live page',
                        onPressed: () => launchUrl(
                          Uri.parse('https://hc-petty-cash-report.web.app/'),
                          mode: LaunchMode.externalApplication,
                        ),
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

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
