import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/media_yearly_stats.dart';
import '../../models/enums.dart';
import '../../services/media_yearly_stats_service.dart';
import '../../services/media_yearly_stats_pdf_service.dart';
import '../../utils/responsive_helper.dart';

class MediaYearlyStatsScreen extends StatefulWidget {
  const MediaYearlyStatsScreen({super.key});

  @override
  State<MediaYearlyStatsScreen> createState() => _MediaYearlyStatsScreenState();
}

class _MediaYearlyStatsScreenState extends State<MediaYearlyStatsScreen> {
  final _service = MediaYearlyStatsService();

  int _selectedYear = DateTime.now().year;
  String _selectedLanguage = 'all';
  String _selectedPlatform = 'all';
  String _pageName = '';
  final TextEditingController _pageFilterController = TextEditingController();

  List<MediaYearlyStats> _availableReports = [];
  MediaYearlyStats? _currentStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadStats();
    });
  }

  @override
  void dispose() {
    _pageFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _service.listByYear(_selectedYear);
      if (!mounted) return;

      // Filter reports based on selected filters
      List<MediaYearlyStats> filteredReports = reports;
      if (_selectedLanguage != 'all') {
        filteredReports = filteredReports
            .where((r) => r.language == _selectedLanguage)
            .toList();
      }
      if (_selectedPlatform != 'all') {
        filteredReports = filteredReports
            .where((r) => r.platform == _selectedPlatform)
            .toList();
      }
      if (_pageName.trim().isNotEmpty) {
        filteredReports = filteredReports
            .where(
              (r) =>
                  r.pageName.toLowerCase().contains(_pageName.toLowerCase()),
            )
            .toList();
      }

      _availableReports = filteredReports;

      // Get the first matching report if available
      _currentStats = filteredReports.isNotEmpty ? filteredReports.first : null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load stats: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ResponsiveContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeaderBanner(),
                          const SizedBox(height: 16),
                          _buildFilters(),
                          const SizedBox(height: 16),
                          if (_currentStats == null)
                            _buildEmptyState()
                          else ...[
                            if (_currentStats!.title != null ||
                                _currentStats!.notes != null)
                              _buildInfoCard(),
                            if (_currentStats!.title != null ||
                                _currentStats!.notes != null)
                              const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Result',
                              children: [
                                _buildStatRow(
                                  'Total Follower',
                                  _currentStats!.resultTotalFollower,
                                ),
                                _buildStatRow(
                                  'Net Follower Gain',
                                  _currentStats!.resultNetFollowerGain,
                                ),
                                _buildStatRow(
                                  'View',
                                  _currentStats!.resultView,
                                ),
                                _buildStatRow(
                                  'Viewers',
                                  _currentStats!.resultViewers,
                                ),
                                _buildStatRow(
                                  'Content Interaction',
                                  _currentStats!.resultContentInteraction,
                                ),
                                _buildStatRow(
                                  'Link Click',
                                  _currentStats!.resultLinkClick,
                                ),
                                _buildStatRow(
                                  'Visit',
                                  _currentStats!.resultVisit,
                                ),
                                _buildStatRow(
                                  'Follow',
                                  _currentStats!.resultFollow,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Audience',
                              children: [
                                _buildStatRow(
                                  'Follow',
                                  _currentStats!.audienceFollow,
                                ),
                                _buildStatRow(
                                  'Returning Viewers',
                                  _currentStats!.audienceReturningViewers,
                                ),
                                _buildStatRow(
                                  'Engage Follower',
                                  _currentStats!.audienceEngageFollower,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Content Overview',
                              children: [
                                _buildStatRow(
                                  'View',
                                  _currentStats!.contentOverviewView,
                                ),
                                _buildStatRow(
                                  '3 Second View',
                                  _currentStats!.contentOverviewThreeSecondView,
                                ),
                                _buildStatRow(
                                  '1 Minutes View',
                                  _currentStats!.contentOverviewOneMinuteView,
                                ),
                                _buildStatRow(
                                  'Content Interaction',
                                  _currentStats!
                                      .contentOverviewContentInteraction,
                                ),
                                _buildDurationRow(
                                  'Watch Time',
                                  _currentStats!.contentOverviewWatchTime,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'View Breakdown',
                              children: [
                                _buildStatRow(
                                  'Total',
                                  _currentStats!.viewBreakdownTotal,
                                ),
                                _buildStatRow(
                                  'From Organic',
                                  _currentStats!.viewBreakdownFromOrganic,
                                ),
                                _buildStatRow(
                                  'From Follower',
                                  _currentStats!.viewBreakdownFromFollower,
                                ),
                                _buildStatRow(
                                  'Viewers',
                                  _currentStats!.viewBreakdownViewers,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildSectionCard(
                              title: 'Content',
                              children: [
                                _buildStatRow(
                                  'Reach',
                                  _currentStats!.contentReach,
                                ),
                                _buildDurationRow(
                                  'Watch Time',
                                  _currentStats!.contentWatchTime,
                                ),
                                _buildDecimalRow(
                                  'Video Average',
                                  _currentStats!.contentVideoAverage,
                                ),
                                _buildStatRow(
                                  'Like and Reaction',
                                  _currentStats!.contentLikeReaction,
                                ),
                                _buildStatRow(
                                  'Viewers',
                                  _currentStats!.contentViewers,
                                ),
                              ],
                            ),
                            if (_currentStats!.platformStats.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildPlatformSection(),
                            ],
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.pink.shade400,
            Colors.pink.shade600,
            Colors.pink.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderActionButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back to Dashboard',
                      onPressed: () => context.go('/media-dashboard'),
                    ),
                    Row(
                      children: [
                        if (_currentStats != null)
                          _buildHeaderActionButton(
                            icon: Icons.picture_as_pdf,
                            tooltip: 'Export PDF',
                            onPressed: _isLoading ? () {} : _exportPdf,
                          ),
                        const SizedBox(width: 8),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _isLoading ? () {} : _loadStats,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yearly Social Media Stats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generated from Social Media Reports',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.insights,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveBuilder(
              mobile: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(6, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedYear = value);
                      await _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Languages'),
                      ),
                      ...MediaLanguage.values.map((lang) {
                        return DropdownMenuItem(
                          value: lang.code,
                          child: Text(lang.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedLanguage = value);
                      await _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPlatform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Platforms'),
                      ),
                      DropdownMenuItem(
                        value: 'youtube',
                        child: Text('YouTube'),
                      ),
                      DropdownMenuItem(
                        value: 'facebook',
                        child: Text('Facebook'),
                      ),
                      DropdownMenuItem(
                        value: 'instagram',
                        child: Text('Instagram'),
                      ),
                      DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedPlatform = value);
                      await _loadStats();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pageFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Page Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _pageName = value,
                    onFieldSubmitted: (_) => _loadStats(),
                  ),
                ],
              ),
              tablet: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(6, (index) {
                            final year = DateTime.now().year - index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedYear = value);
                            await _loadStats();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedLanguage,
                          decoration: const InputDecoration(
                            labelText: 'Language',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Languages'),
                            ),
                            ...MediaLanguage.values.map((lang) {
                              return DropdownMenuItem(
                                value: lang.code,
                                child: Text(lang.displayName),
                              );
                            }),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedLanguage = value);
                            await _loadStats();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPlatform,
                          decoration: const InputDecoration(
                            labelText: 'Platform',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All Platforms'),
                            ),
                            DropdownMenuItem(
                              value: 'youtube',
                              child: Text('YouTube'),
                            ),
                            DropdownMenuItem(
                              value: 'facebook',
                              child: Text('Facebook'),
                            ),
                            DropdownMenuItem(
                              value: 'instagram',
                              child: Text('Instagram'),
                            ),
                            DropdownMenuItem(
                              value: 'tiktok',
                              child: Text('TikTok'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            setState(() => _selectedPlatform = value);
                            await _loadStats();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pageFilterController,
                          decoration: const InputDecoration(
                            labelText: 'Page Name',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => _pageName = value,
                          onFieldSubmitted: (_) => _loadStats(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (_availableReports.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Reports for $_selectedYear: ${_availableReports.length}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Yearly Stats Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate yearly stats from the Social Media Reports page',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/media-period-reports'),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Go to Social Media Reports'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentStats!.title != null) ...[
              Text(
                _currentStats!.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                _buildInfoChip(
                  Icons.language,
                  _getLanguageDisplay(_currentStats!.language),
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  _getPlatformIcon(_currentStats!.platform),
                  _currentStats!.platform.toUpperCase(),
                ),
                if (_currentStats!.pageName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.pages, _currentStats!.pageName),
                ],
              ],
            ),
            if (_currentStats!.notes != null) ...[
              const SizedBox(height: 12),
              Text(
                _currentStats!.notes!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pink.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.pink.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.pink.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageDisplay(String code) {
    return MediaLanguage.values
            .where((l) => l.code == code)
            .firstOrNull
            ?.displayName ??
        code.toUpperCase();
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle;
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      default:
        return Icons.public;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value != null ? _formatNumber(value) : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationRow(String label, int? hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            hours != null ? _formatDuration(hours) : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDecimalRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value != null ? value.toStringAsFixed(2) : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSection() {
    final platforms = _currentStats!.platformStats;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...platforms.entries.map((entry) {
              final platform = entry.key;
              final stats = entry.value;
              return ExpansionTile(
                leading: Icon(_getPlatformIcon(platform)),
                title: Text(platform.toUpperCase()),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          'View',
                          stats['resultView']?.toInt(),
                        ),
                        _buildStatRow(
                          'Viewers',
                          stats['resultViewers']?.toInt(),
                        ),
                        _buildStatRow(
                          'Reach',
                          stats['contentReach']?.toInt(),
                        ),
                        _buildDurationRow(
                          'Watch Time',
                          stats['contentWatchTime']?.toInt(),
                        ),
                        _buildStatRow(
                          'Like and Reaction',
                          stats['contentLikeReaction']?.toInt(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }

  String _formatDuration(int hours) {
    if (hours <= 0) return '0h';
    final days = hours ~/ 24;
    final remainder = hours % 24;
    if (days == 0) return '${remainder}h';
    if (remainder == 0) return '${days}d';
    return '${days}d ${remainder}h';
  }

  Future<void> _exportPdf() async {
    if (_currentStats == null) return;
    try {
      final service = MediaYearlyStatsPdfService();
      final pdfBytes = await service.exportYearlyStats(_currentStats!);
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    }
  }
}
