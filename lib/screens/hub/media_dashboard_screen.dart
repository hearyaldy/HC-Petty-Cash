import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_production_provider.dart';
import '../../models/enums.dart';
import '../../utils/responsive_helper.dart';
import '../../services/production_import_service.dart';

class MediaDashboardScreen extends StatefulWidget {
  const MediaDashboardScreen({super.key});

  @override
  State<MediaDashboardScreen> createState() => _MediaDashboardScreenState();
}

class _MediaDashboardScreenState extends State<MediaDashboardScreen> {
  int _totalProductions = 0;
  int _totalEpisodes = 0;
  int _publishedCount = 0;
  int _inProductionCount = 0;
  Map<String, int> _byLanguage = {};

  // Engagement stats
  int _totalViews = 0;
  int _totalEngagement = 0;
  double _engagementRate = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final mediaProvider = Provider.of<MediaProductionProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final isAdmin = user?.role == 'admin';

      // Load productions based on user permissions
      if (isAdmin) {
        await mediaProvider.loadAllProductions();
      } else if (user != null) {
        final assignedLanguages = user.mediaPermissions.assignedLanguages;
        await mediaProvider.loadProductionsForUser(assignedLanguages);
      }

      // Get production stats
      final stats = await mediaProvider.getProductionStats();

      // Get engagement stats for current year
      final yearStats = await mediaProvider.getYearlyEngagementStats(DateTime.now().year);

      if (mounted) {
        setState(() {
          _totalProductions = stats['totalProductions'] ?? 0;
          _totalEpisodes = stats['totalEpisodes'] ?? 0;
          _publishedCount = stats['publishedCount'] ?? 0;
          _inProductionCount = stats['inProductionCount'] ?? 0;
          _byLanguage = Map<String, int>.from(stats['byLanguage'] ?? {});

          _totalViews = yearStats['totalViews'] ?? 0;
          _totalEngagement = yearStats['totalEngagement'] ?? 0;
          _engagementRate = (yearStats['engagementRate'] ?? 0).toDouble();

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading media stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.currentUser?.role == 'admin';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeaderBanner(),
                  const SizedBox(height: 24),
                  _buildProductionOverview(),
                  const SizedBox(height: 24),
                  _buildEngagementCards(),
                  const SizedBox(height: 24),
                  _buildLanguageBreakdown(),
                  const SizedBox(height: 24),
                  _buildMenuSection(context, isAdmin),
                  const SizedBox(height: 24),
                  _buildQuickActionsSection(context),
                  const SizedBox(height: 24),
                ],
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
          // Background pattern
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
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/admin-hub'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Media Production',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Productions & Social Media Engagement',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadStats,
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

  Widget _buildProductionOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie, color: Colors.pink.shade600),
              const SizedBox(width: 8),
              const Text(
                'Production Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Productions',
                        _totalProductions.toString(),
                        Icons.video_library,
                        Colors.pink,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Total Episodes',
                        _totalEpisodes.toString(),
                        Icons.playlist_play,
                        Colors.purple,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Published',
                        _publishedCount.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'In Production',
                        _inProductionCount.toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEngagementCards() {
    return Row(
      children: [
        Expanded(
          child: _buildEngagementCard(
            'Total Views',
            _formatNumber(_totalViews),
            Icons.visibility,
            Colors.blue,
            '${DateTime.now().year} YTD',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEngagementCard(
            'Total Engagement',
            _formatNumber(_totalEngagement),
            Icons.thumb_up,
            Colors.green,
            'Likes + Comments + Shares',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEngagementCard(
            'Engagement Rate',
            '${_engagementRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.orange,
            'Avg across platforms',
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: Colors.pink.shade600),
              const SizedBox(width: 8),
              const Text(
                'Productions by Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _byLanguage.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No productions yet',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _byLanguage.entries.map((entry) {
                        final langDisplay = entry.key.mediaLanguageDisplayName;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.pink.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                langDisplay,
                                style: TextStyle(
                                  color: Colors.pink.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildMenuCard(
              context,
              'All Productions',
              Icons.video_library,
              Colors.pink,
              '/media/productions',
            ),
            _buildMenuCard(
              context,
              'Add Production',
              Icons.add_circle,
              Colors.green,
              '/media/productions/add',
            ),
            _buildMenuCard(
              context,
              'Engagement Data',
              Icons.analytics,
              Colors.blue,
              '/media/engagement',
            ),
            _buildMenuCard(
              context,
              'Annual Report',
              Icons.assessment,
              Colors.orange,
              '/media/reports/annual',
            ),
            _buildMenuCard(
              context,
              'Production Budget',
              Icons.account_balance_wallet,
              Colors.pinkAccent,
              '/media/production-budget',
            ),
            _buildMenuCard(
              context,
              'Yearly Social Stats',
              Icons.insights,
              Colors.teal,
              '/media/stats/yearly',
            ),
            _buildMenuCard(
              context,
              'Social Media Reports',
              Icons.calendar_month,
              Colors.deepPurple,
              '/media/stats/period',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.currentUser?.role == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('New Production'),
              onPressed: () => context.push('/media/productions/add'),
              backgroundColor: Colors.pink.shade50,
            ),
            ActionChip(
              avatar: const Icon(Icons.upload, size: 18),
              label: const Text('Add Engagement'),
              onPressed: () => context.push('/media/engagement/add'),
              backgroundColor: Colors.blue.shade50,
            ),
            ActionChip(
              avatar: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export Report'),
              onPressed: () => context.push('/media/reports/annual'),
              backgroundColor: Colors.orange.shade50,
            ),
            if (isAdmin)
              ActionChip(
                avatar: const Icon(Icons.download, size: 18),
                label: const Text('Import Productions'),
                onPressed: () => _showImportDialog(context),
                backgroundColor: Colors.green.shade50,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mediaProvider = Provider.of<MediaProductionProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final importService = ProductionImportService();
    final count = importService.getProductionCount();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Productions'),
        content: Text(
          'This will import $count productions from the HC SEA Production List.\n\n'
          'Existing productions with the same title and language will be skipped.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing productions...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final imported = await importService.importProductions(
        createdById: user.id,
        createdByName: user.name,
        skipExisting: true,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $imported productions'),
          backgroundColor: Colors.green,
        ),
      );

      // Invalidate cache and reload productions
      await mediaProvider.refreshProductions();

      // Reload stats
      await _loadStats();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  
}
