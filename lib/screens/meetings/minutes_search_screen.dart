import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/adcom_minutes.dart';
import '../../services/adcom_minutes_service.dart';
import '../../utils/responsive_helper.dart';

class _VotedItemResult {
  final AdcomMinutes minutes;
  final MinutesItem item;

  _VotedItemResult(this.minutes, this.item);
}

class MinutesSearchScreen extends StatefulWidget {
  const MinutesSearchScreen({super.key});

  @override
  State<MinutesSearchScreen> createState() => _MinutesSearchScreenState();
}

class _MinutesSearchScreenState extends State<MinutesSearchScreen> {
  final _minutesService = AdcomMinutesService();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_VotedItemResult> _filterResults(List<AdcomMinutes> allMinutes) {
    final keyword = _query.trim().toLowerCase();
    final results = <_VotedItemResult>[];
    for (final minutes in allMinutes) {
      for (final item in minutes.minutesItems) {
        if (item.status != MinutesItemStatus.voted) continue;
        if (keyword.isNotEmpty) {
          final haystack = [
            item.itemNumber,
            item.title,
            item.description,
            item.resolution ?? '',
          ].join(' ').toLowerCase();
          if (!haystack.contains(keyword)) continue;
        }
        results.add(_VotedItemResult(minutes, item));
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.only(
              left: contentPadding.left,
              right: contentPadding.right,
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 16),
                _buildSearchField(),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<AdcomMinutes>>(
                    stream: _minutesService.getMinutes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error: ${snapshot.error}'));
                      }

                      final results =
                          _filterResults(snapshot.data ?? []);

                      if (results.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildResultCard(results[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade400,
            Colors.indigo.shade600,
            Colors.indigo.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fact_check_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Voted Minutes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Find action items that have been voted on.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'Search by item number, title, or resolution...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty
                ? 'No voted action items found.'
                : 'No voted action items match "$_query".',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_VotedItemResult result) {
    final dateLabel = _dateFormat.format(result.minutes.meetingDate);
    return InkWell(
      onTap: () =>
          context.push('/admin/adcom-minutes/${result.minutes.id}/view'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    result.item.itemNumber,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'VOTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.item.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (result.item.resolution != null &&
                result.item.resolution!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.item.resolution!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
