import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_production_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/media_production.dart';
import '../../models/enums.dart';
import '../../services/media_production_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class MediaProductionsScreen extends StatefulWidget {
  const MediaProductionsScreen({super.key});

  @override
  State<MediaProductionsScreen> createState() => _MediaProductionsScreenState();
}

class _MediaProductionsScreenState extends State<MediaProductionsScreen> {
  String _selectedLanguage = 'all';
  String _selectedType = 'all';
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProductions();
    });
  }

  Future<void> _loadProductions() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mediaProvider = Provider.of<MediaProductionProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';

    if (isAdmin) {
      await mediaProvider.loadAllProductions();
    } else if (user != null) {
      await mediaProvider.loadProductionsForUser(user.mediaPermissions.assignedLanguages);
    }
  }

  List<MediaProduction> _getFilteredProductions(List<MediaProduction> productions) {
    return productions.where((p) {
      if (_selectedLanguage != 'all' && p.language != _selectedLanguage) return false;
      if (_selectedType != 'all' && p.productionType != _selectedType) return false;
      if (_selectedStatus != 'all' && p.status != _selectedStatus) return false;
      if (_searchQuery.isNotEmpty &&
          !p.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/media/productions/add'),
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.add),
        label: const Text('New Production'),
      ),
      body: SafeArea(
        child: Consumer<MediaProductionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredProductions = _getFilteredProductions(provider.productions);

            return RefreshIndicator(
              onRefresh: _loadProductions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ResponsiveContainer(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildHeaderBanner(),
                      const SizedBox(height: 16),
                      _buildSearchAndFilters(),
                      const SizedBox(height: 16),
                      if (filteredProductions.isEmpty)
                        _buildEmptyState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredProductions.length,
                          itemBuilder: (context, index) {
                            final production = filteredProductions[index];
                            return _buildProductionCard(production);
                          },
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            );
          },
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
                        _buildHeaderActionButton(
                          icon: Icons.picture_as_pdf,
                          tooltip: 'Export PDF',
                          onPressed: () => _exportPdf(context),
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _loadProductions,
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
                            'Media Productions',
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
                            'View and manage all productions',
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
                        Icons.video_library,
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search productions...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          ResponsiveBuilder(
            mobile: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Languages')),
                    ...MediaLanguage.values.map((lang) => DropdownMenuItem(
                          value: lang.code,
                          child: Text(lang.displayName),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedLanguage = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Types')),
                    ...ProductionType.values.map((type) => DropdownMenuItem(
                          value: type.name,
                          child: Text(type.displayName),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Status')),
                    ...ProductionStatus.values.map((status) => DropdownMenuItem(
                          value: status.name,
                          child: Text(status.displayName),
                        )),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value!),
                ),
              ],
            ),
            tablet: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Languages')),
                      ...MediaLanguage.values.map((lang) => DropdownMenuItem(
                            value: lang.code,
                            child: Text(lang.displayName),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedLanguage = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Types')),
                      ...ProductionType.values.map((type) => DropdownMenuItem(
                            value: type.name,
                            child: Text(type.displayName),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedType = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Status')),
                      ...ProductionStatus.values.map((status) => DropdownMenuItem(
                            value: status.name,
                            child: Text(status.displayName),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedStatus = value!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No productions found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first production to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/media/productions/add'),
            icon: const Icon(Icons.add),
            label: const Text('New Production'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProductionCard(MediaProduction production) {
    final statusColor = _getStatusColor(production.status);
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/media/productions/${production.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail or Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(8),
                  image: production.thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(production.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: production.thumbnailUrl == null
                    ? Icon(Icons.video_library, color: Colors.pink.shade300, size: 40)
                    : null,
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            production.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            production.statusDisplayName,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.language,
                          production.languageDisplayName,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.category,
                          production.typeDisplayName,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (production.isSeries)
                      Text(
                        '${production.totalSeasons} Season(s) • ${production.totalEpisodes} Episode(s)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    if (production.durationMinutes != null)
                      Text(
                        'Duration: ${_formatDuration(production.durationMinutes!)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (production.category != null && production.category!.isNotEmpty)
                      Text(
                        'Category: ${production.category}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (production.budget != null)
                      Text(
                        'Budget: ${currencyFormat.format(production.budget)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (production.projectName != null)
                      Text(
                        'Project: ${production.projectName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final provider = context.read<MediaProductionProvider>();
    final projectProvider = context.read<ProjectReportProvider>();
    await projectProvider.loadProjectReports();
    final productions = provider.productions;
    if (productions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No productions to export.')),
      );
      return;
    }
    try {
      final projectBudgets = <String, double>{};
      for (final report in projectProvider.projectReports) {
        projectBudgets[report.id] = report.budget;
      }
      final service = MediaProductionPdfService();
      final pdfBytes = await service.exportProductionList(
        productions: productions,
        title: 'Media Productions List',
        projectBudgets: projectBudgets,
      );
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planning':
        return Colors.grey;
      case 'inProduction':
        return Colors.orange;
      case 'postProduction':
        return Colors.blue;
      case 'published':
        return Colors.green;
      case 'archived':
        return Colors.brown;
      default:
        return Colors.grey;
    }
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
}
