import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/equipment.dart';
import '../../models/user.dart';
import '../../services/equipment_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_export_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final String equipmentId;

  const EquipmentDetailScreen({super.key, required this.equipmentId});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  final EquipmentService _equipmentService = EquipmentService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  List<User> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _availableUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canEdit = authProvider.canEditInventory();
    final canDelete = authProvider.canDeleteInventory();

    return StreamBuilder<List<Equipment>>(
      stream: _equipmentService.getAllEquipment(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(title: const Text('Equipment Details')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(title: const Text('Equipment Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final allEquipment = snapshot.data ?? [];
        final currentIndex = allEquipment.indexWhere((e) => e.id == widget.equipmentId);

        if (currentIndex == -1) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(title: const Text('Equipment Details')),
            body: const Center(child: Text('Equipment not found')),
          );
        }

        final equipment = allEquipment[currentIndex];
        final hasPrevious = currentIndex > 0;
        final hasNext = currentIndex < allEquipment.length - 1;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: SafeArea(
            child: Column(
              children: [
                // Header section (scrollable part)
                Padding(
                  padding: ResponsiveHelper.getScreenPadding(context),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // Custom header banner with navigation
                          _buildHeaderBanner(
                            equipment,
                            canEdit,
                            canDelete,
                            allEquipment,
                            currentIndex,
                            hasPrevious,
                            hasNext,
                          ),
                          const SizedBox(height: 16),
                          // Tab bar
                          Container(
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
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Colors.purple.shade700,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorColor: Colors.purple.shade600,
                              indicatorWeight: 3,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              tabs: const [
                                Tab(icon: Icon(Icons.info), text: 'Details'),
                                Tab(icon: Icon(Icons.history), text: 'History'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tab content (expanded to fill remaining space)
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(
                        padding: ResponsiveHelper.getScreenPadding(context),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: _buildDetailsContent(
                              equipment,
                              NumberFormat.currency(symbol: 'THB ', decimalDigits: 0),
                              DateFormat('dd MMM yyyy'),
                            ),
                          ),
                        ),
                      ),
                      _buildHistoryTab(equipment),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildActionButton(equipment),
        );
      },
    );
  }

  Widget _buildHeaderBanner(
    Equipment equipment,
    bool canEdit,
    bool canDelete,
    List<Equipment> allEquipment,
    int currentIndex,
    bool hasPrevious,
    bool hasNext,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade400,
              Colors.purple.shade600,
              Colors.purple.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.shade300,
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
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
                  // Top action bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderActionButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back to Inventory',
                        onPressed: () => context.go('/inventory'),
                      ),
                      Row(
                        children: [
                          if (equipment.itemStickerTag != null)
                            _buildHeaderActionButton(
                              icon: Icons.qr_code_2,
                              tooltip: 'Print Sticker',
                              onPressed: () => _showSingleStickerPrintDialog(equipment),
                            ),
                          if (canEdit) ...[
                            const SizedBox(width: 8),
                            _buildHeaderActionButton(
                              icon: Icons.edit,
                              tooltip: 'Quick Edit',
                              onPressed: () => _showEditDialog(equipment),
                            ),
                          ],
                          if (canDelete) ...[
                            const SizedBox(width: 8),
                            _buildHeaderActionButton(
                              icon: Icons.delete,
                              tooltip: 'Delete Equipment',
                              onPressed: () => _confirmDelete(equipment),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Main content with navigation arrows
                  Row(
                    children: [
                      // Previous button
                      _buildNavigationButton(
                        icon: Icons.chevron_left,
                        enabled: hasPrevious,
                        onPressed: hasPrevious
                            ? () => context.go('/inventory/${allEquipment[currentIndex - 1].id}')
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Equipment info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              equipment.name,
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
                            const SizedBox(height: 4),
                            if (equipment.brand != null || equipment.model != null)
                              Text(
                                '${equipment.brand ?? ''} ${equipment.model ?? ''}'.trim(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildBannerStat('${currentIndex + 1}/${allEquipment.length}', 'Items'),
                                const SizedBox(width: 24),
                                _buildBannerStat(
                                  equipment.status.displayName,
                                  'Status',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category icon + Next button
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getCategoryIcon(equipment.category),
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildNavigationButton(
                            icon: Icons.chevron_right,
                            enabled: hasNext,
                            onPressed: hasNext
                                ? () => context.go('/inventory/${allEquipment[currentIndex + 1].id}')
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required bool enabled,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.3),
          size: 28,
        ),
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

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget? _buildActionButton(Equipment equipment) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final canCheckout = authProvider.canCheckoutInventory();

    if (equipment.status == EquipmentStatus.available && canCheckout) {
      return FloatingActionButton.extended(
        onPressed: () => _showCheckoutDialog(equipment),
        icon: const Icon(Icons.output),
        label: const Text('Check Out'),
        backgroundColor: Colors.orange,
      );
    } else if (equipment.status == EquipmentStatus.checkedOut) {
      // Only the person who checked it out or users with checkout permission can check it in
      final canCheckIn =
          canCheckout ||
          equipment.currentHolderId == user?.id;
      if (canCheckIn) {
        return FloatingActionButton.extended(
          onPressed: () => _showCheckInDialog(equipment),
          icon: const Icon(Icons.input),
          label: const Text('Check In'),
          backgroundColor: Colors.green,
        );
      }
    }
    return null;
  }

  Widget _buildDetailsContent(
    Equipment equipment,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(equipment, currencyFormat),
        const SizedBox(height: 16),
        if (equipment.isCheckedOut)
          _buildCurrentCheckoutCard(equipment, dateFormat),
        if (equipment.isCheckedOut) const SizedBox(height: 16),
        ResponsiveHelper.isDesktop(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSpecificationsCard(equipment)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPurchaseInfoCard(
                      equipment,
                      currencyFormat,
                      dateFormat,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildSpecificationsCard(equipment),
                  const SizedBox(height: 16),
                  _buildPurchaseInfoCard(equipment, currencyFormat, dateFormat),
                ],
              ),
        if (equipment.notes != null && equipment.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(equipment),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderCard(Equipment equipment, NumberFormat currencyFormat) {
    final statusColor = _getStatusColor(equipment.status);
    final conditionColor = _getConditionColor(equipment.condition);
    final hasPhoto = equipment.photoUrl != null && equipment.photoUrl!.isNotEmpty;

    return Container(
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
        children: [
          // Photo section
          if (hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                equipment.photoUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: hasPhoto
                  ? const BorderRadius.vertical(bottom: Radius.circular(16))
                  : BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  _getCategoryColor(equipment.category).withValues(alpha: 0.1),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          equipment.category,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getCategoryIcon(equipment.category),
                        size: 48,
                        color: _getCategoryColor(equipment.category),
                      ),
                    ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (equipment.brand != null || equipment.model != null)
                        Text(
                          '${equipment.brand ?? ''} ${equipment.model ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            equipment.category,
                            _getCategoryColor(equipment.category),
                            Icons.category,
                          ),
                          _buildChip(
                            equipment.status.displayName,
                            statusColor,
                            Icons.info,
                          ),
                          _buildChip(
                            equipment.condition.displayName,
                            conditionColor,
                            Icons.star,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
                if (equipment.purchasePrice != null) ...[
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Asset Value',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        currencyFormat.format(equipment.purchasePrice),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCheckoutCard(Equipment equipment, DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: Colors.orange.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currently Checked Out',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipment.currentHolderName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.orange.shade300,
              size: 16,
            ),
          ],
        ),
    );
  }

  Widget _buildSpecificationsCard(Equipment equipment) {
    final stickerTag = equipment.itemStickerTag;
    final assetTag = equipment.assetTag;
    final qrData = stickerTag ?? assetTag;

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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Specifications & Identification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
            const Divider(height: 24),
            if (equipment.accountingPeriod != null)
              _buildInfoRow('Accounting Period', equipment.accountingPeriod!),
            if (equipment.assetCode != null)
              _buildInfoRow('Asset Code', equipment.assetCode!),
            if (equipment.itemStickerTag != null)
              _buildInfoRow('Item Sticker Tag', equipment.itemStickerTag!),
            if (equipment.serialNumber != null)
              _buildInfoRow('Serial Number', equipment.serialNumber!),
            if (equipment.assetTag != null)
              _buildInfoRow('Asset Tag', equipment.assetTag!),
            if (equipment.location != null)
              _buildInfoRow('Location', equipment.location!),
            if (equipment.assignedToName != null)
              _buildInfoRow('Assigned To', equipment.assignedToName!),
            if (equipment.quantity > 1)
              _buildInfoRow('Quantity', equipment.quantity.toString()),
            if (equipment.description != null)
              _buildInfoRow('Description', equipment.description!),
            if (equipment.assetAgeYears != null)
              _buildInfoRow('Asset Age', '${equipment.assetAgeYears} years'),
            if (qrData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    QrImageView(
                      data: qrData,
                      size: 72,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Organization Name
                          if (equipment.organizationName != null &&
                              equipment.organizationName!.isNotEmpty)
                            Text(
                              equipment.organizationName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 4),
                          // Item Sticker Tag
                          Text(
                            qrData,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Barcode
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: qrData,
                            height: 40,
                            drawText: false,
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 4),
                          // Item Name
                          Text(
                            equipment.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (equipment.accountingPeriod == null &&
                equipment.assetCode == null &&
                equipment.itemStickerTag == null &&
                equipment.serialNumber == null &&
                equipment.assetTag == null &&
                equipment.location == null &&
                equipment.description == null)
              Text(
                'No specifications available',
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
    );
  }

  Widget _buildPurchaseInfoCard(
    Equipment equipment,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Purchase & Depreciation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
            const Divider(height: 24),
            if (equipment.purchasePrice != null)
              _buildInfoRow(
                'Purchase Price',
                currencyFormat.format(equipment.purchasePrice),
              ),
            if (equipment.unitCost != null || equipment.effectiveUnitCost != null)
              _buildInfoRow(
                'Unit Cost',
                currencyFormat.format(
                  equipment.unitCost ?? equipment.effectiveUnitCost,
                ),
              ),
            if (equipment.purchaseDate != null)
              _buildInfoRow(
                'Purchase Date',
                dateFormat.format(equipment.purchaseDate!),
              ),
            if (equipment.purchaseYear != null)
              _buildInfoRow('Purchase Year', equipment.purchaseYear.toString()),
            if (equipment.supplier != null)
              _buildInfoRow('Supplier', equipment.supplier!),
            if (equipment.warrantyExpiry != null)
              _buildInfoRow(
                'Warranty Until',
                dateFormat.format(equipment.warrantyExpiry!),
                isWarrantyExpired: equipment.warrantyExpiry!.isBefore(
                  DateTime.now(),
                ),
              ),
            // Depreciation info
            if (equipment.depreciationPercentage != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                'Depreciation Rate',
                '${equipment.depreciationPercentage}% per year',
              ),
              if (equipment.monthlyDepreciation != null)
                _buildInfoRow(
                  'Monthly Depreciation',
                  currencyFormat.format(equipment.monthlyDepreciation),
                ),
              if (equipment.monthsDepreciated != null)
                _buildInfoRow(
                  'Months Depreciated',
                  '${equipment.monthsDepreciated} months',
                ),
              if (equipment.totalDepreciation != null)
                _buildInfoRow(
                  'Total Depreciation',
                  currencyFormat.format(equipment.totalDepreciation),
                ),
              if (equipment.currentBookValue != null)
                _buildInfoRow(
                  'Current Book Value',
                  currencyFormat.format(equipment.currentBookValue),
                ),
            ],
            const Divider(height: 24),
            _buildInfoRow('Created', dateFormat.format(equipment.createdAt)),
            if (equipment.updatedAt != null)
              _buildInfoRow(
                'Last Updated',
                dateFormat.format(equipment.updatedAt!),
              ),
          ],
        ),
    );
  }

  Widget _buildNotesCard(Equipment equipment) {
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.note,
                  color: Colors.amber.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(equipment.notes!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isWarrantyExpired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isWarrantyExpired ? Colors.red : null,
              ),
            ),
          ),
          if (isWarrantyExpired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Expired',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Equipment equipment) {
    return StreamBuilder<List<EquipmentCheckout>>(
      stream: _equipmentService.getEquipmentCheckoutHistory(equipment.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final checkouts = snapshot.data ?? [];

        if (checkouts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No checkout history',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              padding: ResponsiveHelper.getScreenPadding(context),
              itemCount: checkouts.length,
              itemBuilder: (context, index) {
                return _buildCheckoutHistoryItem(checkouts[index]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutHistoryItem(EquipmentCheckout checkout) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

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
                CircleAvatar(
                  backgroundColor: checkout.isReturned
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    checkout.isReturned ? Icons.check : Icons.schedule,
                    color: checkout.isReturned
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkout.checkedOutByName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        checkout.isReturned
                            ? 'Returned'
                            : 'Currently has equipment',
                        style: TextStyle(
                          color: checkout.isReturned
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        checkout.conditionAtCheckout ==
                            EquipmentCondition.excellent
                        ? Colors.green.shade50
                        : checkout.conditionAtCheckout ==
                              EquipmentCondition.good
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    checkout.conditionAtCheckout.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          checkout.conditionAtCheckout ==
                              EquipmentCondition.excellent
                          ? Colors.green.shade700
                          : checkout.conditionAtCheckout ==
                                EquipmentCondition.good
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checked Out',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        dateFormat.format(checkout.checkedOutAt),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (checkout.isReturned)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Returned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          dateFormat.format(checkout.returnedAt!),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (checkout.purpose != null && checkout.purpose!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Purpose: ${checkout.purpose}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog(Equipment equipment) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final purposeController = TextEditingController();
    DateTime? expectedReturn;
    EquipmentCondition selectedCondition = equipment.condition;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.output, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Check Out Equipment'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking out: ${equipment.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'To: ${user?.name ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentCondition>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Current Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: EquipmentCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(condition.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCondition = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                    hintText: 'e.g., Studio shoot',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => expectedReturn = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expected Return (optional)',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      expectedReturn != null
                          ? DateFormat('dd MMM yyyy').format(expectedReturn!)
                          : 'Select date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _equipmentService.checkOutEquipment(
                    equipmentId: equipment.id,
                    userId: user?.id ?? '',
                    userName: user?.name ?? 'Unknown',
                    purpose: purposeController.text.trim().isEmpty
                        ? null
                        : purposeController.text.trim(),
                    expectedReturnDate: expectedReturn,
                    conditionAtCheckout: selectedCondition,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Equipment checked out successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check Out'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInDialog(Equipment equipment) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final notesController = TextEditingController();
    EquipmentCondition selectedCondition = equipment.condition;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.input, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Check In Equipment'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning: ${equipment.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'From: ${equipment.currentHolderName ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentCondition>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Condition at Return',
                    border: OutlineInputBorder(),
                  ),
                  items: EquipmentCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(condition.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCondition = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g., Any issues or damage',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _equipmentService.checkInEquipment(
                    equipmentId: equipment.id,
                    checkoutId: equipment.currentCheckoutId!,
                    returnedBy: user?.id ?? '',
                    returnedByName: user?.name ?? 'Unknown',
                    conditionAtReturn: selectedCondition,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Equipment checked in successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Equipment equipment) {
    // Controllers for form fields
    final nameController = TextEditingController(text: equipment.name);
    final descriptionController = TextEditingController(text: equipment.description ?? '');
    final brandController = TextEditingController(text: equipment.brand ?? '');
    final modelController = TextEditingController(text: equipment.model ?? '');
    final serialNumberController = TextEditingController(text: equipment.serialNumber ?? '');
    final assetTagController = TextEditingController(text: equipment.assetTag ?? '');
    final assetCodeController = TextEditingController(text: equipment.assetCode ?? '');
    final accountingPeriodController = TextEditingController(text: equipment.accountingPeriod ?? '');
    final locationController = TextEditingController(text: equipment.location ?? '');
    final purchasePriceController = TextEditingController(
      text: equipment.purchasePrice?.toStringAsFixed(0) ?? '',
    );
    final supplierController = TextEditingController(text: equipment.supplier ?? '');
    final notesController = TextEditingController(text: equipment.notes ?? '');
    final quantityController = TextEditingController(text: equipment.quantity.toString());

    String selectedCategory = equipment.category;
    EquipmentCondition selectedCondition = equipment.condition;
    EquipmentStatus selectedStatus = equipment.status;
    DateTime? purchaseDate = equipment.purchaseDate;
    int? purchaseYear = equipment.purchaseYear;
    DateTime? warrantyExpiry = equipment.warrantyExpiry;
    String? assignedToId = equipment.assignedToId;
    String? assignedToName = equipment.assignedToName;
    bool isLoading = false;
    bool isUploadingImage = false;
    XFile? selectedImage;
    String? photoUrl = equipment.photoUrl;
    final dateFormat = DateFormat('dd MMM yyyy');
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);
    final availableUserIds = _availableUsers.map((user) => user.id).toSet();
    final hasAssignedUser = assignedToId != null && availableUserIds.contains(assignedToId);
    final categories = [
      if (!EquipmentCategories.categories.contains(selectedCategory))
        selectedCategory,
      ...EquipmentCategories.categories,
    ];

    Future<String?> uploadImage(
      XFile file,
      void Function(void Function()) setDialogState,
    ) async {
      try {
        setDialogState(() => isUploadingImage = true);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'equipment_$timestamp.jpg';
        final ref = FirebaseStorage.instance.ref().child('equipment/$fileName');

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes);
        } else {
          uploadTask = ref.putFile(File(file.path));
        }

        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      } finally {
        setDialogState(() => isUploadingImage = false);
      }
    }

    Future<void> pickImage(
      ImageSource source,
      void Function(void Function()) setDialogState,
    ) async {
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 70,
        );
        if (file == null) return;
        setDialogState(() => selectedImage = file);
        final url = await uploadImage(file, setDialogState);
        if (url != null) {
          setDialogState(() => photoUrl = url);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error picking image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade400,
                        Colors.purple.shade600,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              equipment.name,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                // Form content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Section
                        _buildEditSection('Basic Information', Icons.info_outline, Colors.blue, [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Equipment Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory_2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedCategory = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: brandController,
                                  decoration: const InputDecoration(
                                    labelText: 'Brand',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: modelController,
                                  decoration: const InputDecoration(
                                    labelText: 'Model',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Status Section
                        _buildEditSection('Status & Condition', Icons.check_circle_outline, Colors.orange, [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<EquipmentStatus>(
                                  value: selectedStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: EquipmentStatus.values.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => selectedStatus = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<EquipmentCondition>(
                                  value: selectedCondition,
                                  decoration: const InputDecoration(
                                    labelText: 'Condition',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: EquipmentCondition.values.map((condition) {
                                    return DropdownMenuItem(
                                      value: condition,
                                      child: Text(condition.displayName),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => selectedCondition = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Identification Section
                        _buildEditSection('Identification', Icons.qr_code, Colors.purple, [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: accountingPeriodController,
                                  decoration: const InputDecoration(
                                    labelText: 'Accounting Period',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: assetCodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Asset Code',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: serialNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Serial Number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: assetTagController,
                            decoration: const InputDecoration(
                              labelText: 'Asset Tag',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code_2),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Location Section
                        _buildEditSection('Location & Assignment', Icons.location_on, Colors.teal, [
                          TextFormField(
                            controller: locationController,
                            decoration: const InputDecoration(
                              labelText: 'Storage Location',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: assignedToId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Assigned To',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Not Assigned'),
                              ),
                              if (!hasAssignedUser && assignedToId != null)
                                DropdownMenuItem(
                                  value: assignedToId,
                                  child: Text(
                                    assignedToName != null
                                        ? '$assignedToName (unavailable)'
                                        : 'Unknown User (unavailable)',
                                  ),
                                ),
                              ..._availableUsers.map((user) {
                                return DropdownMenuItem(
                                  value: user.id,
                                  child: Text('${user.name} (${user.department})'),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                assignedToId = value;
                                assignedToName = _availableUsers
                                    .where((u) => u.id == value)
                                    .firstOrNull
                                    ?.name;
                              });
                            },
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Purchase Section
                        _buildEditSection('Purchase Information', Icons.shopping_cart, Colors.green, [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: purchasePriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Purchase Price (THB)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: quantityController,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate:
                                          purchaseDate ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        purchaseDate = picked;
                                        purchaseYear ??= picked.year;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Purchase Date',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      purchaseDate != null
                                          ? dateFormat.format(purchaseDate!)
                                          : 'Select date',
                                      style: TextStyle(
                                        color: purchaseDate != null
                                            ? null
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: purchaseYear ?? purchaseDate?.year,
                                  decoration: const InputDecoration(
                                    labelText: 'Purchase Year',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.event),
                                  ),
                                  items: years.map((year) {
                                    return DropdownMenuItem(
                                      value: year,
                                      child: Text(year.toString()),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      purchaseYear = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: supplierController,
                            decoration: const InputDecoration(
                              labelText: 'Supplier/Vendor',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.store),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: dialogContext,
                                initialDate:
                                    warrantyExpiry ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  warrantyExpiry = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Warranty Expiry',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.verified_user),
                              ),
                              child: Text(
                                warrantyExpiry != null
                                    ? dateFormat.format(warrantyExpiry!)
                                    : 'Select date',
                                style: TextStyle(
                                  color: warrantyExpiry != null
                                      ? null
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Notes Section
                        _buildEditSection('Notes', Icons.note, Colors.amber.shade700, [
                          TextFormField(
                            controller: notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ]),
                        const SizedBox(height: 20),
                        // Photo Section
                        _buildEditSection('Photo', Icons.camera_alt, Colors.pink, [
                          if (photoUrl != null)
                            Container(
                              height: 140,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                photoUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stack) {
                                  return const Center(
                                    child: Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  isUploadingImage ? 'Uploading...' : 'No photo',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploadingImage
                                      ? null
                                      : () => pickImage(
                                            ImageSource.camera,
                                            setDialogState,
                                          ),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Camera'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploadingImage
                                      ? null
                                      : () => pickImage(
                                            ImageSource.gallery,
                                            setDialogState,
                                          ),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          ),
                          if (photoUrl != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: isUploadingImage
                                  ? null
                                  : () => setDialogState(() => photoUrl = null),
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Remove Photo'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ),
                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('Equipment name is required'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isLoading = true);

                                  try {
                                    final updatedEquipment = Equipment(
                                      id: equipment.id,
                                      name: nameController.text.trim(),
                                      description: descriptionController.text.trim().isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      category: selectedCategory,
                                      brand: brandController.text.trim().isEmpty
                                          ? null
                                          : brandController.text.trim(),
                                      model: modelController.text.trim().isEmpty
                                          ? null
                                          : modelController.text.trim(),
                                      serialNumber: serialNumberController.text.trim().isEmpty
                                          ? null
                                          : serialNumberController.text.trim(),
                                      assetTag: assetTagController.text.trim().isEmpty
                                          ? null
                                          : assetTagController.text.trim(),
                                      assetCode: assetCodeController.text.trim().isEmpty
                                          ? null
                                          : assetCodeController.text.trim(),
                                      accountingPeriod: accountingPeriodController.text.trim().isEmpty
                                          ? null
                                          : accountingPeriodController.text.trim(),
                                      location: locationController.text.trim().isEmpty
                                          ? null
                                          : locationController.text.trim(),
                                      status: selectedStatus,
                                      condition: selectedCondition,
                                      purchasePrice: purchasePriceController.text.trim().isEmpty
                                          ? null
                                          : double.tryParse(purchasePriceController.text.trim()),
                                      purchaseDate: purchaseDate,
                                      purchaseYear: purchaseYear,
                                      supplier: supplierController.text.trim().isEmpty
                                          ? null
                                          : supplierController.text.trim(),
                                      warrantyExpiry: warrantyExpiry,
                                      photoUrl: photoUrl,
                                      notes: notesController.text.trim().isEmpty
                                          ? null
                                          : notesController.text.trim(),
                                      organizationId: equipment.organizationId,
                                      organizationName: equipment.organizationName,
                                      assignedToId: assignedToId,
                                      assignedToName: assignedToName,
                                      currentCheckoutId: equipment.currentCheckoutId,
                                      currentHolderId: equipment.currentHolderId,
                                      currentHolderName: equipment.currentHolderName,
                                      quantity: int.tryParse(quantityController.text.trim()) ?? 1,
                                      unitCost: equipment.unitCost,
                                      depreciationPercentage: equipment.depreciationPercentage,
                                      monthsDepreciated: equipment.monthsDepreciated,
                                      createdAt: equipment.createdAt,
                                      updatedAt: DateTime.now(),
                                      createdBy: equipment.createdBy,
                                    );

                                    await _equipmentService.updateEquipment(updatedEquipment);

                                    if (mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Equipment updated successfully'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isLoading = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(isLoading ? 'Saving...' : 'Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }

  Widget _buildEditSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
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
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Future<void> _showSingleStickerPrintDialog(Equipment equipment) async {
    if (equipment.itemStickerTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item does not have a sticker tag'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Default sticker size: 70x37mm, 8 rows, 3 columns (8×37=296mm fits A4 297mm)
    final widthController = TextEditingController(text: '70');
    final heightController = TextEditingController(text: '37');
    final sheetWidthController = TextEditingController(text: '210');
    final sheetHeightController = TextEditingController(text: '297');
    final rowsController = TextEditingController(text: '8');
    final colsController = TextEditingController(text: '3');
    final marginController = TextEditingController(text: '0');
    final hGapController = TextEditingController(text: '0');
    final vGapController = TextEditingController(text: '0');
    final offsetLeftController = TextEditingController(text: '0');
    final offsetRightController = TextEditingController(text: '0');
    final stickerLeftPaddingController = TextEditingController(text: '0');
    final startRowController = TextEditingController(text: '1');
    final startColumnController = TextEditingController(text: '1');

    // Built-in sticker presets
    final builtInPresets = <String, Map<String, dynamic>>{
      'Default (70x37mm, 8x3)': {
        'width': '70',
        'height': '37',
        'rows': '8',
        'cols': '3',
      },
      '70x29.7mm (10x3)': {
        'width': '70',
        'height': '29.7',
        'rows': '10',
        'cols': '3',
      },
      '63.5x38.1mm (7x3)': {
        'width': '63.5',
        'height': '38.1',
        'rows': '7',
        'cols': '3',
      },
      '52.5x29.7mm (10x4)': {
        'width': '52.5',
        'height': '29.7',
        'rows': '10',
        'cols': '4',
      },
      '38.1x21.2mm (13x5)': {
        'width': '38.1',
        'height': '21.2',
        'rows': '13',
        'cols': '5',
      },
      '25.4x10mm (27x7)': {
        'width': '25.4',
        'height': '10',
        'rows': '27',
        'cols': '7',
      },
    };

    // Load saved presets from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedPresetsJson = prefs.getString('sticker_presets') ?? '{}';
    final savedPresets = Map<String, dynamic>.from(jsonDecode(savedPresetsJson));

    // Merge built-in and saved presets
    final stickerPresets = <String, Map<String, dynamic>>{
      ...builtInPresets,
      ...savedPresets.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))),
      'Custom': {'width': '', 'height': '', 'rows': '', 'cols': ''},
    };
    String selectedPreset = 'Default (70x37mm, 8x3)';

    // Function to save a new preset
    Future<void> savePreset(String name, StateSetter setDialogState) async {
      final newPreset = {
        'width': widthController.text,
        'height': heightController.text,
        'rows': rowsController.text,
        'cols': colsController.text,
      };
      savedPresets[name] = newPreset;
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      stickerPresets[name] = newPreset;
      setDialogState(() {
        selectedPreset = name;
      });
    }

    // Function to delete a saved preset
    Future<void> deletePreset(String name, StateSetter setDialogState) async {
      savedPresets.remove(name);
      stickerPresets.remove(name);
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      setDialogState(() {
        selectedPreset = 'Default (70x37mm, 8x3)';
        final preset = stickerPresets[selectedPreset]!;
        widthController.text = preset['width']!;
        heightController.text = preset['height']!;
        rowsController.text = preset['rows']!;
        colsController.text = preset['cols']!;
      });
    }

    // Function to rename a saved preset
    Future<void> renamePreset(String oldName, String newName, StateSetter setDialogState) async {
      if (oldName == newName || newName.isEmpty) return;
      final presetData = savedPresets[oldName];
      if (presetData == null) return;

      savedPresets.remove(oldName);
      savedPresets[newName] = presetData;
      stickerPresets.remove(oldName);
      stickerPresets[newName] = Map<String, dynamic>.from(presetData);
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      setDialogState(() {
        selectedPreset = newName;
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code_2, color: Colors.purple.shade600),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Print Sticker')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.purple.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                equipment.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Tag: ${equipment.itemStickerTag}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Preset dropdown
                  const Text(
                    'Sticker Preset',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedPreset,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: stickerPresets.keys.map((preset) {
                      return DropdownMenuItem(
                        value: preset,
                        child: Text(preset, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && value != 'Custom') {
                        final preset = stickerPresets[value]!;
                        setDialogState(() {
                          selectedPreset = value;
                          widthController.text = preset['width']!;
                          heightController.text = preset['height']!;
                          rowsController.text = preset['rows']!;
                          colsController.text = preset['cols']!;
                        });
                      } else {
                        setDialogState(() {
                          selectedPreset = value!;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Save/Delete preset buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final nameController = TextEditingController();
                            final presetName = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Save Preset'),
                                content: TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Preset Name',
                                    hintText: 'e.g., My Custom Label',
                                    border: OutlineInputBorder(),
                                  ),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, nameController.text),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (presetName != null && presetName.trim().isNotEmpty) {
                              await savePreset(presetName.trim(), setDialogState);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Preset "$presetName" saved'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save Preset'),
                        ),
                      ),
                      if (savedPresets.containsKey(selectedPreset)) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final nameController = TextEditingController(text: selectedPreset);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Rename Preset'),
                                  content: TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'New Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, nameController.text),
                                      child: const Text('Rename'),
                                    ),
                                  ],
                                ),
                              );
                              if (newName != null && newName.trim().isNotEmpty && newName.trim() != selectedPreset) {
                                await renamePreset(selectedPreset, newName.trim(), setDialogState);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Preset renamed to "$newName"'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Rename'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Preset'),
                                  content: Text('Delete "$selectedPreset"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await deletePreset(selectedPreset, setDialogState);
                              }
                            },
                            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sticker Size (mm)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          onChanged: (_) => setDialogState(() {
                            selectedPreset = 'Custom';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Width',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          onChanged: (_) => setDialogState(() {
                            selectedPreset = 'Custom';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sheet Size (mm)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sheetWidthController,
                        decoration: const InputDecoration(
                          labelText: 'Sheet Width',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sheetHeightController,
                        decoration: const InputDecoration(
                          labelText: 'Sheet Height',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Layout',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rowsController,
                        decoration: const InputDecoration(
                          labelText: 'Rows',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: colsController,
                        decoration: const InputDecoration(
                          labelText: 'Columns',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Margins & Gaps (mm)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: marginController,
                        decoration: const InputDecoration(
                          labelText: 'Margin',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: hGapController,
                        decoration: const InputDecoration(
                          labelText: 'H Gap',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: vGapController,
                        decoration: const InputDecoration(
                          labelText: 'V Gap',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alignment',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: offsetLeftController,
                        decoration: const InputDecoration(
                          labelText: 'Left Offset (mm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: offsetRightController,
                        decoration: const InputDecoration(
                          labelText: 'Right Offset (mm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sticker Content',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stickerLeftPaddingController,
                  decoration: const InputDecoration(
                    labelText: 'Sticker Left Padding (mm)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sticker Position',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose where to print the sticker on the sheet',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startRowController,
                        decoration: const InputDecoration(
                          labelText: 'Row',
                          helperText: '1 = first row',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: startColumnController,
                        decoration: const InputDecoration(
                          labelText: 'Column',
                          helperText: '1 = first column',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print Sticker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final config = StickerPrintConfig(
      stickerWidthMm: double.tryParse(widthController.text) ?? 70,
      stickerHeightMm: double.tryParse(heightController.text) ?? 37,
      sheetWidthMm: double.tryParse(sheetWidthController.text) ?? 210,
      sheetHeightMm: double.tryParse(sheetHeightController.text) ?? 297,
      rows: int.tryParse(rowsController.text) ?? 8,
      columns: int.tryParse(colsController.text) ?? 3,
      marginMm: double.tryParse(marginController.text) ?? 0,
      horizontalGapMm: double.tryParse(hGapController.text) ?? 0,
      verticalGapMm: double.tryParse(vGapController.text) ?? 0,
      offsetLeftMm: double.tryParse(offsetLeftController.text) ?? 0,
      offsetRightMm: double.tryParse(offsetRightController.text) ?? 0,
      stickerLeftPaddingMm:
          double.tryParse(stickerLeftPaddingController.text) ?? 0,
      startRow: int.tryParse(startRowController.text) ?? 1,
      startColumn: int.tryParse(startColumnController.text) ?? 1,
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      final pdfService = PdfExportService();
      final pdfBytes = await pdfService.exportEquipmentStickerSheetBytes(
        [equipment],
        config,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        await Printing.layoutPdf(
          onLayout: (_) => Future.value(Uint8List.fromList(pdfBytes)),
          name: 'Sticker_${equipment.itemStickerTag}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating sticker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Equipment'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${equipment.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _equipmentService.deleteEquipment(equipment.id);
                if (mounted) {
                  Navigator.pop(context);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equipment deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.available:
        return Colors.green;
      case EquipmentStatus.checkedOut:
        return Colors.orange;
      case EquipmentStatus.maintenance:
        return Colors.red;
      case EquipmentStatus.retired:
        return Colors.grey;
    }
  }

  Color _getConditionColor(EquipmentCondition condition) {
    switch (condition) {
      case EquipmentCondition.excellent:
        return Colors.green;
      case EquipmentCondition.good:
        return Colors.blue;
      case EquipmentCondition.fair:
        return Colors.orange;
      case EquipmentCondition.poor:
        return Colors.red;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Colors.blue;
      case 'lens':
        return Colors.purple;
      case 'audio':
        return Colors.pink;
      case 'lighting':
        return Colors.amber;
      case 'tripod & support':
        return Colors.brown;
      case 'computer':
        return Colors.indigo;
      case 'monitor & display':
        return Colors.cyan;
      case 'storage & media':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Icons.camera_alt;
      case 'lens':
        return Icons.camera;
      case 'audio':
        return Icons.mic;
      case 'lighting':
        return Icons.light_mode;
      case 'tripod & support':
        return Icons.control_camera;
      case 'computer':
        return Icons.computer;
      case 'monitor & display':
        return Icons.monitor;
      case 'storage & media':
        return Icons.sd_card;
      default:
        return Icons.inventory_2;
    }
  }
}
