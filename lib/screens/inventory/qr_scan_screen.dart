import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/equipment.dart';
import '../../services/equipment_service.dart';
import '../../utils/responsive_helper.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _controller;
  final EquipmentService _equipmentService = EquipmentService();
  bool _isHandling = false;
  bool _torchEnabled = false;
  bool _frontCamera = false;
  bool _isInitializing = true;
  String? _errorMessage;
  final _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      await _controller!.start();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to start camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawValue) async {
    if (_isHandling) return;
    _isHandling = true;

    final normalized = rawValue.trim();
    if (normalized.isEmpty) {
      _isHandling = false;
      return;
    }

    try {
      // If QR encodes a direct inventory URL, navigate by ID
      if (normalized.startsWith('http')) {
        final uri = Uri.tryParse(normalized);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final idIndex = uri.pathSegments.indexOf('inventory');
          if (idIndex != -1 && uri.pathSegments.length > idIndex + 1) {
            final id = uri.pathSegments[idIndex + 1];
            if (id.isNotEmpty) {
              if (!mounted) return;
              context.go('/inventory/$id');
              return;
            }
          }
        }
      }

      String normalizeTag(String value) =>
          value.trim().toUpperCase().replaceAll(' ', '');

      final equipmentList = await _equipmentService.getAllEquipment().first;
      final normalizedTag = normalizeTag(normalized);

      // First try exact ID match
      var match = equipmentList.firstWhere(
        (e) => e.id == normalized,
        orElse: () => Equipment(
          id: '',
          name: '',
          category: 'Other',
          status: EquipmentStatus.available,
          condition: EquipmentCondition.good,
          createdAt: DateTime.now(),
        ),
      );

      // If no ID match, try tag matching
      if (match.id.isEmpty) {
        match = equipmentList.firstWhere(
          (e) =>
              (e.assetTag != null &&
                  normalizeTag(e.assetTag!) == normalizedTag) ||
              (e.itemStickerTag != null &&
                  normalizeTag(e.itemStickerTag!) == normalizedTag) ||
              (e.assetCode != null &&
                  normalizeTag(e.assetCode!) == normalizedTag),
          orElse: () => Equipment(
            id: '',
            name: '',
            category: 'Other',
            status: EquipmentStatus.available,
            condition: EquipmentCondition.good,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;

      if (match.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No item found for: $normalized'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        _isHandling = false;
        return;
      }

      context.go('/inventory/${match.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _isHandling = false;
    }
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Code Manually'),
        content: TextField(
          controller: _manualInputController,
          decoration: const InputDecoration(
            hintText: 'Enter asset tag or sticker code',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            if (value.trim().isNotEmpty) {
              _handleScan(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final value = _manualInputController.text.trim();
              if (value.isNotEmpty) {
                _handleScan(value);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: _buildHeaderCard(),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 640,
                ),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _showManualInputDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.keyboard, color: Colors.white, size: 20),
                ),
              ),
              if (_controller != null && !_isInitializing) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await _controller!.toggleTorch();
                    setState(() => _torchEnabled = !_torchEnabled);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _torchEnabled ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await _controller!.switchCamera();
                    setState(() => _frontCamera = !_frontCamera);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _frontCamera ? Icons.camera_front : Icons.camera_rear,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Point camera at equipment QR code',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
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

  Widget _buildBody() {
    // Show loading state
    if (_isInitializing) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state with manual input option
    if (_errorMessage != null || _controller == null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera not available',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showManualInputDialog,
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter Code Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    // Show camera scanner
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final rawValue = barcodes.first.rawValue;
            if (rawValue == null) return;
            _handleScan(rawValue);
          },
          errorBuilder: (context, error, child) {
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera error: ${error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (error.errorDetails != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error.errorDetails!.message ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter Code Manually'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Bottom instruction bar
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black.withValues(alpha: 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Point the camera at the QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showManualInputDialog,
                  child: const Text(
                    'Or enter code manually',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Web notice
        if (kIsWeb)
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Camera access requires HTTPS and user permission.\nIf camera doesn\'t work, use manual input.',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
