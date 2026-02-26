import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/media_production_provider.dart';
import '../../models/media_production.dart';
import '../../models/media_season.dart';
import '../../models/media_episode.dart';
import '../../models/media_engagement.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class MediaProductionDetailScreen extends StatefulWidget {
  final String productionId;

  const MediaProductionDetailScreen({super.key, required this.productionId});

  @override
  State<MediaProductionDetailScreen> createState() =>
      _MediaProductionDetailScreenState();
}

class _MediaProductionDetailScreenState
    extends State<MediaProductionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProduction();
  }

  Future<void> _loadProduction() async {
    final provider = Provider.of<MediaProductionProvider>(context, listen: false);
    await provider.loadProductionWithDetails(widget.productionId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,###').format(number);
  }

  String _formatCurrency(double value) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );
    return currencyFormat.format(value);
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return '${mins}m';
    }
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProductionProvider>(
      builder: (context, provider, _) {
        final production = provider.currentProduction;

        if (provider.isLoading && production == null) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (production == null) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildEmptyHeaderBanner(),
                  ),
                  const Expanded(
                    child: Center(child: Text('Production not found')),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/media/productions/${production.id}/engagement/add'),
            backgroundColor: Colors.pink,
            child: const Icon(Icons.add_chart),
          ),
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildHeaderBanner(production),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.pink,
                      labelColor: Colors.pink,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(icon: Icon(Icons.info), text: 'Overview'),
                        Tab(icon: Icon(Icons.playlist_play), text: 'Content'),
                        Tab(icon: Icon(Icons.analytics), text: 'Engagement'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(production, provider),
                  _buildContentTab(production, provider),
                  _buildEngagementTab(production, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHeaderBanner() {
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _buildHeaderActionButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () => context.pop(),
            ),
            const SizedBox(width: 16),
            const Text(
              'Production Not Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(MediaProduction production) {
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
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                    ),
                    Row(
                      children: [
                        _buildHeaderActionButton(
                          icon: Icons.edit,
                          tooltip: 'Edit',
                          onPressed: () => context.push('/media/productions/${production.id}/edit'),
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _loadProduction,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (production.thumbnailUrl != null)
                      Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(production.thumbnailUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.video_library, color: Colors.white, size: 32),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            production.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  production.languageDisplayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  production.statusDisplayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildOverviewTab(MediaProduction production, MediaProductionProvider provider) {
    final stats = provider.currentEngagementStats;

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(production),
              const SizedBox(height: 16),
              _buildStatsCard(production, stats),
              const SizedBox(height: 16),
              _buildQuickActions(production),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(MediaProduction production) {
    final hasUrls = production.productionUrls.isNotEmpty;
    final hasStaff = production.teamMemberNames.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: production.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            production.thumbnailUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.video_library, color: Colors.pink.shade300, size: 50),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        production.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(production.status),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoBadge(Icons.language, production.languageDisplayName),
                          const SizedBox(width: 8),
                          _buildInfoBadge(Icons.category, production.typeDisplayName),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (production.description != null) ...[
              const Divider(height: 24),
              Text(
                production.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const Divider(height: 24),
            ResponsiveBuilder(
              mobile: Column(
                children: [
                  _buildInfoItem('Seasons', production.totalSeasons.toString()),
                  const SizedBox(height: 8),
                  _buildInfoItem('Episodes', production.totalEpisodes.toString()),
                  const SizedBox(height: 8),
                  _buildInfoItem('Created By', production.createdByName),
                ],
              ),
              tablet: Row(
                children: [
                  Expanded(
                    child: _buildInfoItem('Seasons', production.totalSeasons.toString()),
                  ),
                  Expanded(
                    child: _buildInfoItem('Episodes', production.totalEpisodes.toString()),
                  ),
                  Expanded(
                    child: _buildInfoItem('Created By', production.createdByName),
                  ),
                ],
              ),
            ),
            if (production.durationMinutes != null || production.category != null) ...[
              const Divider(height: 24),
              ResponsiveBuilder(
                mobile: Column(
                  children: [
                    if (production.durationMinutes != null)
                      _buildInfoItem(
                        'Duration',
                        _formatDuration(production.durationMinutes!),
                      ),
                    if (production.category != null && production.category!.isNotEmpty)
                      _buildInfoItem('Category', production.category!),
                  ],
                ),
                tablet: Row(
                  children: [
                    if (production.durationMinutes != null)
                      Expanded(
                        child: _buildInfoItem(
                          'Duration',
                          _formatDuration(production.durationMinutes!),
                        ),
                      ),
                    if (production.category != null && production.category!.isNotEmpty)
                      Expanded(
                        child: _buildInfoItem('Category', production.category!),
                      ),
                  ],
                ),
              ),
            ],
            if (production.budget != null ||
                production.projectName != null ||
                production.productionYear != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (production.budget != null) ...[
                    Icon(Icons.account_balance_wallet, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Budget: ${_formatCurrency(production.budget!)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (production.budget != null &&
                      (production.projectName != null ||
                          production.productionYear != null))
                    const SizedBox(width: 16),
                  if (production.productionYear != null)
                    Text(
                      'Year: ${production.productionYear}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (production.productionYear != null &&
                      production.projectName != null)
                    const SizedBox(width: 16),
                  if (production.projectName != null)
                    Text(
                      'Project: ${production.projectName}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
            if (production.thumbnailUrl != null) ...[
              const Divider(height: 24),
              _buildInfoRow('Thumbnail URL', production.thumbnailUrl!),
            ],
            if (hasUrls) ...[
              const Divider(height: 24),
              const Text(
                'Production URLs',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: production.productionUrls
                    .map((url) => Chip(label: Text(url)))
                    .toList(),
              ),
            ],
            if (hasStaff) ...[
              const Divider(height: 24),
              const Text(
                'Assigned Staff',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: production.teamMemberNames
                    .map((name) => Chip(label: Text(name)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.productionStatusDisplayName,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(MediaProduction production, Map<String, dynamic>? stats) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.pink.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Engagement Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Views',
                    _formatNumber(stats?['totalViews'] ?? 0),
                    Icons.visibility,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Likes',
                    _formatNumber(stats?['totalLikes'] ?? 0),
                    Icons.thumb_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Comments',
                    _formatNumber(stats?['totalComments'] ?? 0),
                    Icons.comment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Shares',
                    _formatNumber(stats?['totalShares'] ?? 0),
                    Icons.share,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, color: Colors.pink.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Engagement Rate: ${(stats?['engagementRate'] ?? 0.0).toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: Colors.pink.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(MediaProduction production) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_chart, size: 18),
                  label: const Text('Add Engagement'),
                  onPressed: () =>
                      context.push('/media/productions/${production.id}/engagement/add'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Production'),
                  onPressed: () =>
                      context.push('/media/productions/${production.id}/edit'),
                ),
                if (production.isSeries)
                  ActionChip(
                    avatar: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Add Season'),
                    onPressed: () => _showAddSeasonDialog(production.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab(MediaProduction production, MediaProductionProvider provider) {
    if (!production.isSeries) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Standalone Production',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'This production is not a series',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final seasons = provider.currentSeasons;
    final episodes = provider.currentEpisodes;

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seasons (${seasons.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSeasonDialog(production.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Season'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (seasons.isEmpty)
                _buildEmptyContentState('No seasons yet', 'Add your first season')
              else
                ...seasons.map((season) => _buildSeasonCard(season, episodes)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonCard(MediaSeason season, List<MediaEpisode> allEpisodes) {
    final seasonEpisodes = allEpisodes.where((e) => e.seasonId == season.id).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.pink.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${season.seasonNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700,
              ),
            ),
          ),
        ),
        title: Text(season.displayName),
        subtitle: Text('${seasonEpisodes.length} episodes'),
        children: [
          if (seasonEpisodes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No episodes in this season',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            ...seasonEpisodes.map((episode) => _buildEpisodeItem(episode)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => _showAddEpisodeDialog(season),
              icon: const Icon(Icons.add),
              label: const Text('Add Episode'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(MediaEpisode episode) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '${episode.episodeNumber}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      title: Text(episode.title),
      subtitle: Text(episode.durationDisplay),
      trailing: _buildStatusChip(episode.status),
    );
  }

  Widget _buildEngagementTab(MediaProduction production, MediaProductionProvider provider) {
    final engagements = provider.currentEngagements;

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Engagement Records (${engagements.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/media/productions/${production.id}/engagement/add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (engagements.isEmpty)
                _buildEmptyContentState(
                  'No engagement data yet',
                  'Add your first engagement record',
                )
              else
                ...engagements.map((engagement) => _buildEngagementCard(engagement)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementCard(MediaEngagement engagement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPlatformIcon(engagement.platform),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        engagement.platformDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Recorded: ${DateFormat('MMM dd, yyyy').format(engagement.recordedDate)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${engagement.engagementRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildEngagementStat('Views', engagement.views, Colors.blue),
                ),
                Expanded(
                  child: _buildEngagementStat('Likes', engagement.likes, Colors.green),
                ),
                Expanded(
                  child: _buildEngagementStat('Comments', engagement.comments, Colors.orange),
                ),
                Expanded(
                  child: _buildEngagementStat('Shares', engagement.shares, Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(String platform) {
    IconData icon;
    Color color;
    switch (platform) {
      case 'youtube':
        icon = Icons.play_circle_fill;
        color = Colors.red;
        break;
      case 'facebook':
        icon = Icons.facebook;
        color = Colors.blue;
        break;
      case 'instagram':
        icon = Icons.camera_alt;
        color = Colors.pink;
        break;
      case 'tiktok':
        icon = Icons.music_note;
        color = Colors.black;
        break;
      default:
        icon = Icons.public;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildEngagementStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          _formatNumber(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEmptyContentState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planning':
      case 'draft':
        return Colors.grey;
      case 'inProduction':
      case 'editing':
        return Colors.orange;
      case 'postProduction':
      case 'scheduled':
        return Colors.blue;
      case 'published':
        return Colors.green;
      case 'archived':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _showAddSeasonDialog(String productionId) {
    final numberController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Season Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Season Title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text) ?? 1;
              final provider =
                  Provider.of<MediaProductionProvider>(context, listen: false);
              await provider.createSeason(
                productionId: productionId,
                seasonNumber: number,
                title: titleController.text.isEmpty ? null : titleController.text,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddEpisodeDialog(MediaSeason season) {
    final numberController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Episode to ${season.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Episode Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Episode Title',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final number = int.tryParse(numberController.text) ?? 1;
              final provider =
                  Provider.of<MediaProductionProvider>(context, listen: false);
              await provider.createEpisode(
                productionId: season.productionId,
                seasonId: season.id,
                episodeNumber: number,
                title: titleController.text.isEmpty ? 'Episode $number' : titleController.text,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
