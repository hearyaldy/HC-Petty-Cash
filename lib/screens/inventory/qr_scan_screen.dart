import 'dart:async';

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

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final EquipmentService _equipmentService = EquipmentService();
  bool _isHandling = false;
  bool _torchEnabled = false;
  bool _frontCamera = false;
  final _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // autoStart defaults to true: the MobileScanner widget below starts
    // this controller itself once it has actually mounted and attached to
    // it. The previous version called controller.start() manually from
    // here, before that widget existed — every call failed with
    // MobileScannerException(controllerNotAttached, ...) because there was
    // nothing yet for it to attach to. Letting the widget own its own
    // startup (tracked via _controller's own ValueListenable below) avoids
    // that chicken-and-egg deadlock entirely.
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera has real-world side effects (the phone's camera-in-use
    // indicator, battery drain) that shouldn't persist once this screen
    // isn't the thing on screen — backgrounding the browser tab/app should
    // release it just like leaving the page does, and bring it back when
    // the user returns rather than leaving it dark.
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_retryStart());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Explicitly stop before dispose rather than relying on dispose alone
    // to release the camera — stop() directly tells the platform layer to
    // release the stream immediately, instead of it happening as a side
    // effect of teardown, which matters most for the web camera-in-use
    // indicator lingering visibly after navigating away.
    unawaited(_controller.stop());
    _controller.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _retryStart() async {
    try {
      await _controller.start().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
          'Camera did not respond — check that camera permission was '
          'granted, and that you\'re not opening this in an in-app '
          'browser (e.g. from Facebook/Messenger/WhatsApp).',
        ),
      );
    } catch (_) {
      // _controller.value.error already reflects the failure — the
      // ValueListenableBuilder below re-renders from that automatically.
    }
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
              unawaited(_controller.stop());
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

      unawaited(_controller.stop());
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
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, child) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 8,
                ),
                child: _buildHeaderCard(state),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 640,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildBody(state),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(MobileScannerState state) {
    final isRunning = state.isRunning;
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
                onTap: () {
                  unawaited(_controller.stop());
                  context.pop();
                },
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
              if (isRunning) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await _controller.toggleTorch();
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
                    await _controller.switchCamera();
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

  Widget _buildBody(MobileScannerState state) {
    if (state.error != null) {
      return _buildErrorView(state.error!);
    }

    final isReady = state.isInitialized && !state.isStarting;

    // MobileScanner is what actually attaches to _controller and (via
    // autoStart) starts it — it has to be built unconditionally here, not
    // gated behind isReady, or nothing would ever trigger that attachment
    // and isReady would never become true in the first place. The loading
    // spinner below is an overlay on top of it, not a replacement for it.
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isEmpty) return;
            final rawValue = barcodes.first.rawValue;
            if (rawValue == null) return;
            _handleScan(rawValue);
          },
          errorBuilder: (context, error) => _buildErrorView(error),
        ),
        // Visual guide only — purely decorative, doesn't restrict where
        // mobile_scanner actually looks for a code within the frame.
        if (isReady)
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(painter: _ScanFramePainter()),
            ),
          ),
        if (!isReady)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  // Camera permission prompts can hang on some mobile
                  // browsers (see the timeout in _retryStart) — this button
                  // is the only way out until that resolves one way or the
                  // other.
                  TextButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard, color: Colors.white70),
                    label: const Text(
                      'Enter code manually instead',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isReady) ...[
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
                    'Position the code within the frame',
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
      ],
    );
  }

  Widget _buildErrorView(MobileScannerException error) {
    return Container(
      color: Colors.black,
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
          if (error.errorDetails?.message != null) ...[
            const SizedBox(height: 8),
            Text(
              error.errorDetails!.message!,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _retryStart,
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
}

/// Draws four L-shaped corner brackets as a viewfinder-style guide for
/// where to hold the QR code or barcode. Purely visual — mobile_scanner
/// still looks for codes anywhere in the camera feed, not just inside this
/// box.
class _ScanFramePainter extends CustomPainter {
  static const _cornerLength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      // Top-left
      ..moveTo(0, _cornerLength)
      ..lineTo(0, 0)
      ..lineTo(_cornerLength, 0)
      // Top-right
      ..moveTo(size.width - _cornerLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, _cornerLength)
      // Bottom-right
      ..moveTo(size.width, size.height - _cornerLength)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - _cornerLength, size.height)
      // Bottom-left
      ..moveTo(_cornerLength, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - _cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
