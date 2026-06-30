import 'package:flutter/material.dart';
import '../services/pdf_signature_helper.dart';

/// Shows a print options dialog with an "Include Signature" toggle.
/// Sets [PdfSignatureHelper.includeSignature] before calling [onPrint].
///
/// Usage:
/// ```dart
/// await showPrintOptionsDialog(
///   context: context,
///   onPrint: () async {
///     final bytes = await _service.generatePdf(...);
///     await Printing.layoutPdf(onLayout: (_) async => bytes);
///   },
/// );
/// ```
Future<void> showPrintOptionsDialog({
  required BuildContext context,
  required Future<void> Function() onPrint,
  String title = 'Print Options',
}) async {
  // Ensure the signature is loaded so hasSignature reflects reality
  await PdfSignatureHelper.load();
  if (!context.mounted) return;
  bool includeSignature = PdfSignatureHelper.includeSignature;
  final hasSignature = PdfSignatureHelper.hasSignature;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.print_outlined, color: Colors.blue.shade600),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Signature toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                value: includeSignature,
                onChanged: hasSignature
                    ? (v) => setState(() => includeSignature = v)
                    : null,
                title: const Text(
                  'Include Signature',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  hasSignature
                      ? 'Print with your signature image'
                      : 'No signature file found (assets/images/signature.png)',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasSignature
                        ? Colors.grey.shade600
                        : Colors.orange.shade700,
                  ),
                ),
                secondary: Icon(
                  Icons.draw_outlined,
                  color: hasSignature && includeSignature
                      ? Colors.blue.shade600
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return;

  // Apply the setting then generate + print
  PdfSignatureHelper.includeSignature = includeSignature;
  await onPrint();
}
