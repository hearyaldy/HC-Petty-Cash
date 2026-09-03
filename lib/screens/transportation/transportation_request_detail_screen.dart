import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/transportation_request.dart';
import '../../models/enums.dart';
import '../../services/firestore_service.dart';
import '../../services/transportation_request_pdf_export_service.dart';
import '../../services/email_attachment_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/edit_transportation_request_dialog.dart';
import '../../widgets/transportation_mileage_entry_dialog.dart';
import '../../widgets/transportation_per_diem_entry_dialog.dart';
import '../../widgets/transportation_hotel_entry_dialog.dart';
import '../../widgets/support_document_upload_dialog.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/print_options_dialog.dart';
import 'package:printing/printing.dart';

class TransportationRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const TransportationRequestDetailScreen({super.key, required this.requestId});

  @override
  State<TransportationRequestDetailScreen> createState() =>
      _TransportationRequestDetailScreenState();
}

class _TransportationRequestDetailScreenState
    extends State<TransportationRequestDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TransportationRequestPdfExportService _exportService =
      TransportationRequestPdfExportService();
  final EmailAttachmentService _emailService = EmailAttachmentService();

  Future<void> _editRequest(TransportationRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTransportationRequestDialog(
        request: request,
        requesterId: request.requesterId,
        requesterName: request.requesterName,
      ),
    );

    if (result != null && mounted) {
      try {
        final updatedRequest = request.copyWith(
          department: result['department'] as String,
          requestDate: result['requestDate'] as DateTime,
          purpose: result['purpose'] as String,
          destinationPlace: result['destinationPlace'] as String,
          travelDateTime: result['travelDateTime'] as DateTime,
          returnDateTime: result['returnDateTime'] as DateTime,
          travelLocation: result['travelLocation'] as String,
          vehicleType: result['vehicleType'] as String,
          departureFlightNumber: result['departureFlightNumber'] as String?,
          departureFlightTime: result['departureFlightTime'] as String?,
          returnFlightNumber: result['returnFlightNumber'] as String?,
          returnFlightTime: result['returnFlightTime'] as String?,
          notes: result['notes'] as String?,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTransportationRequest(updatedRequest);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRequest(TransportationRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'This will permanently delete this request and all its mileage, per diem, and hotel entries. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTransportationRequest(request.id);
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _exportPDF(TransportationRequest request) async {
    await showPrintOptionsDialog(
      context: context,
      title: 'Print Transportation Request',
      onPrint: () async {
        try {
          await _exportService.printTransportationRequest(request);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error exporting PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  Future<String?> _promptForRecipientEmail() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email to SEUM'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recipient Email',
              hintText: 'e.g. treasurer@adventist.or.th',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  static const String _emailHeaderLogoUrl =
      'https://hc-petty-cash-report.web.app/assets/assets/images/hope_channel_logo.png';

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _buildEmailHtml(TransportationRequest request) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final travelLocation = request.travelLocation.toTravelLocation();
    final vehicleType = request.vehicleType.toVehicleType();

    final hasFlightInfo = request.departureFlightNumber != null ||
        request.departureFlightTime != null ||
        request.returnFlightNumber != null ||
        request.returnFlightTime != null;

    final flightRow = hasFlightInfo
        ? '''
          <tr>
            <td style="width:50%;padding:0 12px 14px 0;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">&#9992;&#65039; Departure Flight</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.departureFlightNumber ?? '-')} &middot; ${_escapeHtml(request.departureFlightTime ?? '-')}</div>
            </td>
            <td style="width:50%;padding:0 0 14px 12px;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">&#9992;&#65039; Return Flight</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.returnFlightNumber ?? '-')} &middot; ${_escapeHtml(request.returnFlightTime ?? '-')}</div>
            </td>
          </tr>
          '''
        : '';

    return '''
<div style="background:#eef4f8;padding:32px 18px;font-family:Helvetica,Arial,sans-serif;color:#0f172a;">
  <div style="max-width:680px;margin:0 auto;background:#ffffff;border:1px solid #d9e5ee;border-radius:24px;overflow:hidden;box-shadow:0 18px 40px rgba(15,23,42,0.08);">
    <div style="padding:36px 32px 30px;background:#0f4c5c;color:#ffffff;">
      <table role="presentation" style="border-collapse:collapse;margin:0 0 18px 0;">
        <tr>
          <td style="vertical-align:middle;padding:0 12px 0 0;">
            <div style="display:inline-block;padding:8px 12px;border-radius:14px;background:#ffffff;">
              <img src="$_emailHeaderLogoUrl" alt="Hope Channel SEA" width="72" style="display:block;width:72px;max-width:100%;height:auto;border:0;outline:none;text-decoration:none;" />
            </div>
          </td>
          <td style="vertical-align:middle;">
            <div style="display:inline-block;padding:7px 12px;border-radius:999px;background:rgba(255,255,255,0.18);font-size:11px;font-weight:800;letter-spacing:0.14em;text-transform:uppercase;">Transportation Request</div>
          </td>
        </tr>
      </table>
      <div style="margin-top:18px;font-size:28px;font-weight:800;line-height:1.2;">${_escapeHtml(request.requestNumber)}</div>
      <div style="margin-top:12px;font-size:16px;line-height:1.65;max-width:520px;color:rgba(255,255,255,0.92);">A transportation request from ${_escapeHtml(request.requesterName)} (${_escapeHtml(request.department)}) has been submitted for your review. The completed form is attached as a PDF.</div>
    </div>
    <div style="padding:30px 32px 34px;">
      <div style="padding:18px 20px;border-radius:18px;background:#f8fbfd;border:1px solid #d9e5ee;">
        <table role="presentation" style="width:100%;border-collapse:collapse;">
          <tr>
            <td style="width:50%;padding:0 12px 14px 0;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Requested By</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.requesterName)}</div>
            </td>
            <td style="width:50%;padding:0 0 14px 12px;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Department</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.department)}</div>
            </td>
          </tr>
          <tr>
            <td colspan="2" style="padding:0 0 14px 0;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Purpose of Travel</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.purpose)}</div>
            </td>
          </tr>
          <tr>
            <td colspan="2" style="padding:0 0 14px 0;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Destination</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(request.destinationPlace)} &middot; ${_escapeHtml(travelLocation.displayName)}</div>
            </td>
          </tr>
          <tr>
            <td style="width:50%;padding:0 12px 14px 0;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Date of Travel</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(dateTimeFormat.format(request.travelDateTime))}</div>
            </td>
            <td style="width:50%;padding:0 0 14px 12px;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Date of Return</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(dateTimeFormat.format(request.returnDateTime))}</div>
            </td>
          </tr>
          $flightRow
        </table>
      </div>
      <div style="margin-top:16px;padding:18px 20px;border-radius:18px;background:#f0fdfa;border:1px solid #99f6e4;">
        <div style="font-size:12px;font-weight:800;letter-spacing:0.1em;text-transform:uppercase;color:#0f766e;">Cost Summary</div>
        <table role="presentation" style="width:100%;border-collapse:collapse;margin-top:10px;">
          <tr>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;">Vehicle (${_escapeHtml(vehicleType.displayName)})</td>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;text-align:right;">${currencyFormat.format(request.totalMileageAmount)} Baht</td>
          </tr>
          <tr>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;">Per Diem</td>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;text-align:right;">${currencyFormat.format(request.totalPerDiemAmount)} Baht</td>
          </tr>
          <tr>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;">Hotel</td>
            <td style="padding:4px 0;font-size:13px;color:#134e4a;text-align:right;">${currencyFormat.format(request.totalHotelAmount)} Baht</td>
          </tr>
          <tr>
            <td style="padding:10px 0 0 0;font-size:15px;font-weight:800;color:#0f172a;border-top:1px solid #99f6e4;">Grand Total</td>
            <td style="padding:10px 0 0 0;font-size:15px;font-weight:800;color:#0f172a;text-align:right;border-top:1px solid #99f6e4;">${currencyFormat.format(request.grandTotal)} Baht</td>
          </tr>
        </table>
      </div>
      <div style="margin-top:22px;font-size:13px;line-height:1.7;color:#5c6f7a;">
        Submitted on ${_escapeHtml(dateFormat.format(request.requestDate))}. Please see the attached PDF for the full itemized breakdown and signature blocks.
      </div>
    </div>
  </div>
</div>
''';
  }

  Future<bool> _showEmailPreviewDialog({
    required String recipientEmail,
    required String subject,
    required Uint8List pdfBytes,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 700,
          height: 750,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade600,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Email Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('To: $recipientEmail',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('Subject: $subject',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdfBytes,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _emailPDF(TransportationRequest request) async {
    final recipientEmail = await _promptForRecipientEmail();
    if (recipientEmail == null || !mounted) return;

    try {
      final mileageEntries = await _firestoreService
          .transportationMileageEntriesStream(request.id)
          .first;
      final perDiemEntries = await _firestoreService
          .transportationPerDiemEntriesStream(request.id)
          .first;
      final hotelEntries = await _firestoreService
          .transportationHotelEntriesStream(request.id)
          .first;

      final pdfBytes = await _exportService.generateTransportationRequestPdf(
        request,
        mileageEntries,
        perDiemEntries,
        hotelEntries,
      );

      final subject = 'Transportation Request ${request.requestNumber}';
      final htmlBody = _buildEmailHtml(request);

      if (!mounted) return;
      final confirmed = await _showEmailPreviewDialog(
        recipientEmail: recipientEmail,
        subject: subject,
        pdfBytes: pdfBytes,
      );
      if (!confirmed || !mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sending email...')));

      await _emailService.sendEmailWithAttachment(
        requestId: request.id,
        recipientEmail: recipientEmail,
        subject: subject,
        htmlBody: htmlBody,
        attachmentBytes: pdfBytes,
        attachmentName: 'Transportation_Request_${request.requestNumber}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email sent to $recipientEmail'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Mileage entries ────────────────────────────────────────────────────

  Future<void> _addMileageEntry(TransportationRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TransportationMileageEntryDialog(request: request),
    );

    if (result != null && mounted) {
      try {
        final entry = TransportationMileageEntry(
          id: const Uuid().v4(),
          requestId: request.id,
          date: result['date'] as DateTime,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          ratePerKm: result['ratePerKm'] as double,
          amount: result['amount'] as double,
          airport: result['airport'] as String?,
          remark: result['remark'] as String?,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveTransportationMileageEntry(entry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding mileage entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editMileageEntry(
    TransportationRequest request,
    TransportationMileageEntry entry,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          TransportationMileageEntryDialog(request: request, entry: entry),
    );

    if (result != null && mounted) {
      try {
        final updatedEntry = TransportationMileageEntry(
          id: entry.id,
          requestId: request.id,
          date: result['date'] as DateTime,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          ratePerKm: result['ratePerKm'] as double,
          amount: result['amount'] as double,
          airport: result['airport'] as String?,
          remark: result['remark'] as String?,
          createdAt: entry.createdAt,
        );
        await _firestoreService.updateTransportationMileageEntry(updatedEntry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating mileage entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteMileageEntry(
    TransportationRequest request,
    TransportationMileageEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTransportationMileageEntry(
          entry.id,
          request.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting mileage entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── Per diem entries ───────────────────────────────────────────────────

  Future<void> _addPerDiemEntry(TransportationRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TransportationPerDiemEntryDialog(request: request),
    );

    if (result != null && mounted) {
      try {
        final entry = TransportationPerDiemEntry(
          id: const Uuid().v4(),
          requestId: request.id,
          date: result['date'] as DateTime,
          hasBreakfast: result['hasBreakfast'] as bool,
          hasLunch: result['hasLunch'] as bool,
          hasSupper: result['hasSupper'] as bool,
          hasIncidentMeal: result['hasIncidentMeal'] as bool,
          mealRate: result['mealRate'] as double,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveTransportationPerDiemEntry(entry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding per diem entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editPerDiemEntry(
    TransportationRequest request,
    TransportationPerDiemEntry entry,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          TransportationPerDiemEntryDialog(request: request, entry: entry),
    );

    if (result != null && mounted) {
      try {
        final updatedEntry = TransportationPerDiemEntry(
          id: entry.id,
          requestId: request.id,
          date: result['date'] as DateTime,
          hasBreakfast: result['hasBreakfast'] as bool,
          hasLunch: result['hasLunch'] as bool,
          hasSupper: result['hasSupper'] as bool,
          hasIncidentMeal: result['hasIncidentMeal'] as bool,
          mealRate: result['mealRate'] as double,
          createdAt: entry.createdAt,
        );
        await _firestoreService.updateTransportationPerDiemEntry(updatedEntry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating per diem entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePerDiemEntry(
    TransportationRequest request,
    TransportationPerDiemEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTransportationPerDiemEntry(
          entry.id,
          request.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting per diem entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── Hotel entries ──────────────────────────────────────────────────────

  Future<void> _addHotelEntry(TransportationRequest request) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TransportationHotelEntryDialog(request: request),
    );

    if (result != null && mounted) {
      try {
        final entry = TransportationHotelEntry(
          id: const Uuid().v4(),
          requestId: request.id,
          date: result['date'] as DateTime,
          hotelName: result['hotelName'] as String,
          amount: result['amount'] as double,
          createdAt: DateTime.now(),
        );
        await _firestoreService.saveTransportationHotelEntry(entry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding hotel entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editHotelEntry(
    TransportationRequest request,
    TransportationHotelEntry entry,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          TransportationHotelEntryDialog(request: request, entry: entry),
    );

    if (result != null && mounted) {
      try {
        final updatedEntry = TransportationHotelEntry(
          id: entry.id,
          requestId: request.id,
          date: result['date'] as DateTime,
          hotelName: result['hotelName'] as String,
          amount: result['amount'] as double,
          createdAt: entry.createdAt,
        );
        await _firestoreService.updateTransportationHotelEntry(updatedEntry);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating hotel entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteHotelEntry(
    TransportationRequest request,
    TransportationHotelEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTransportationHotelEntry(
          entry.id,
          request.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting hotel entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSupportDocumentUploadDialog(TransportationRequest request) {
    showDialog(
      context: context,
      builder: (context) => SupportDocumentUploadDialog(
        transactionId: request.id,
        existingDocumentUrls: request.supportDocumentUrls,
        onDocumentsUploaded: (urls) async {
          try {
            final updatedRequest = request.copyWith(
              supportDocumentUrls: urls,
              updatedAt: DateTime.now(),
            );
            await _firestoreService.updateTransportationRequest(updatedRequest);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support documents updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating support documents: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showSupportDocument(TransportationRequest request) {
    if (request.supportDocumentUrls.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => SupportDocumentGallery(
        documentUrls: request.supportDocumentUrls,
        transactionReceiptNo: request.requestNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<TransportationRequest?>(
        stream: _firestoreService.transportationRequestStream(widget.requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Column(
                  children: [
                    _buildHeaderCard(null),
                    const SizedBox(height: 100),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final request = snapshot.data;
          if (request == null) {
            return SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Column(
                  children: [
                    _buildHeaderCard(null),
                    const SizedBox(height: 100),
                    const Center(child: Text('Request not found')),
                  ],
                ),
              ),
            );
          }

          return _buildRequestContent(request);
        },
      ),
    );
  }

  Widget _buildRequestContent(TransportationRequest request) {
    final spacing = ResponsiveHelper.getSpacing(context);
    return SingleChildScrollView(
      child: ResponsiveContainer(
        padding: ResponsiveHelper.getScreenPadding(context).copyWith(
          top: MediaQuery.of(context).padding.top + 16,
        ),
        child: Column(
          children: [
            _buildHeaderCard(request),
            const SizedBox(height: 16),
            _buildRequestInfoCard(request),
            _buildMileageSection(request),
            _buildPerDiemSection(request),
            _buildHotelSection(request),
            _buildSummarySection(request),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeaderCard([TransportationRequest? request]) {
    final auth = context.read<AuthProvider>();
    final isAdminUser = auth.hasRole(UserRole.admin);
    final currentUserId = auth.currentUser?.id;
    final isOwner = request?.requesterId == currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
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
              if (request != null)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  tooltip: 'Actions',
                  onSelected: (value) async {
                    final freshRequest =
                        await _firestoreService.getTransportationRequest(widget.requestId);
                    if (freshRequest == null) return;

                    switch (value) {
                      case 'edit':
                        _editRequest(freshRequest);
                        break;
                      case 'delete':
                        _deleteRequest(freshRequest);
                        break;
                      case 'export':
                        _exportPDF(freshRequest);
                        break;
                      case 'email':
                        _emailPDF(freshRequest);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 12),
                          Text('Edit Request'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 20),
                          SizedBox(width: 12),
                          Text('Export / Print PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'email',
                      child: Row(
                        children: [
                          Icon(Icons.email, size: 20),
                          SizedBox(width: 12),
                          Text('Email to SEUM'),
                        ],
                      ),
                    ),
                    if (isAdminUser || isOwner)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Text('Delete Request',
                                style: TextStyle(color: Colors.red.shade700)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_filled, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transportation Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request?.requestNumber ?? 'Request to SEUM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
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

  // ─── Info card ──────────────────────────────────────────────────────────

  Widget _buildRequestInfoCard(TransportationRequest request) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
    final travelLocation = request.travelLocation.toTravelLocation();
    final vehicleType = request.vehicleType.toVehicleType();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Request Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow(Icons.person, 'Requested By', request.requesterName),
          _infoRow(Icons.business, 'Department', request.department),
          _infoRow(Icons.event, 'Date', dateFormat.format(request.requestDate)),
          _infoRow(Icons.flag, 'Purpose', request.purpose),
          _infoRow(Icons.location_on, 'Destination', request.destinationPlace),
          _infoRow(Icons.flight_takeoff, 'Date of Travel',
              dateTimeFormat.format(request.travelDateTime)),
          _infoRow(Icons.flight_land, 'Date of Return',
              dateTimeFormat.format(request.returnDateTime)),
          _infoRow(Icons.public, 'Travel Location', travelLocation.displayName),
          _infoRow(Icons.directions_car, 'Vehicle Type', vehicleType.displayName),
          if (request.departureFlightNumber != null ||
              request.departureFlightTime != null)
            _infoRow(
              Icons.flight,
              'Departure Flight',
              '${request.departureFlightNumber ?? '-'} '
                  '${request.departureFlightTime != null ? '· ${request.departureFlightTime}' : ''}',
            ),
          if (request.returnFlightNumber != null ||
              request.returnFlightTime != null)
            _infoRow(
              Icons.flight,
              'Return Flight',
              '${request.returnFlightNumber ?? '-'} '
                  '${request.returnFlightTime != null ? '· ${request.returnFlightTime}' : ''}',
            ),
          if (request.notes != null && request.notes!.isNotEmpty)
            _infoRow(Icons.note, 'Notes', request.notes!),
          if (request.supportDocumentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSupportDocument(request),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text('View Docs (${request.supportDocumentUrls.length})'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (context.read<AuthProvider>().canUploadSupportDocument())
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSupportDocumentUploadDialog(request),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload Air Ticket / Support Documents'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mileage section ────────────────────────────────────────────────────

  Widget _buildMileageSection(TransportationRequest request) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 8),
                  const Text('Mileage',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _addMileageEntry(request),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<List<TransportationMileageEntry>>(
            stream: _firestoreService.transportationMileageEntriesStream(request.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return _emptySectionState('No mileage entries yet');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(entry.date),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.airport != null
                                    ? 'Taxi · ${entry.airport!.taxiAirportDisplayName}'
                                    : '${currencyFormat.format(entry.mileageStart)} → ${currencyFormat.format(entry.mileageEnd)} KM '
                                        '(${currencyFormat.format(entry.totalKm)} km)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              if (entry.remark != null && entry.remark!.isNotEmpty)
                                Text(
                                  entry.remark!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                '฿${currencyFormat.format(entry.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.blue.shade700),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _editMileageEntry(request, entry),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: Colors.red.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _deleteMileageEntry(request, entry),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Per diem section ───────────────────────────────────────────────────

  Widget _buildPerDiemSection(TransportationRequest request) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 8),
                  const Text('Per Diem',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _addPerDiemEntry(request),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<List<TransportationPerDiemEntry>>(
            stream: _firestoreService.transportationPerDiemEntriesStream(request.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return _emptySectionState('No per diem entries yet');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(entry.date),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (entry.hasBreakfast)
                                    _mealChip('B', 'Breakfast', Colors.amber.shade700),
                                  if (entry.hasLunch)
                                    _mealChip('L', 'Lunch', Colors.orange.shade700),
                                  if (entry.hasSupper)
                                    _mealChip('S', 'Supper', Colors.deepOrange.shade700),
                                  if (entry.hasIncidentMeal)
                                    _mealChip('I', 'Incident', Colors.purple.shade700),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                '฿${currencyFormat.format(entry.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green.shade700),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _editPerDiemEntry(request, entry),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: Colors.red.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _deletePerDiemEntry(request, entry),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mealChip(String label, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // ─── Hotel section ──────────────────────────────────────────────────────

  Widget _buildHotelSection(TransportationRequest request) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.hotel, color: Colors.purple.shade600, size: 24),
                  const SizedBox(width: 8),
                  const Text('Hotel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _addHotelEntry(request),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<List<TransportationHotelEntry>>(
            stream: _firestoreService.transportationHotelEntriesStream(request.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return _emptySectionState('No hotel entries yet');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade200, height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(entry.date),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.hotelName,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple.shade200),
                              ),
                              child: Text(
                                '฿${currencyFormat.format(entry.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.purple.shade700),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _editHotelEntry(request, entry),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: Colors.red.shade600),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _deleteHotelEntry(request, entry),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptySectionState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ),
    );
  }

  // ─── Summary ────────────────────────────────────────────────────────────

  Widget _buildSummarySection(TransportationRequest request) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200,
            blurRadius: 12,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.summarize, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _summaryRow(Icons.directions_car, 'Mileage Total',
                    '฿${currencyFormat.format(request.totalMileageAmount)}'),
                const SizedBox(height: 12),
                _summaryRow(Icons.restaurant, 'Per Diem Total',
                    '฿${currencyFormat.format(request.totalPerDiemAmount)}'),
                const SizedBox(height: 12),
                _summaryRow(Icons.hotel, 'Hotel Total',
                    '฿${currencyFormat.format(request.totalHotelAmount)}'),
                const SizedBox(height: 16),
                const Divider(color: Colors.white54, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GRAND TOTAL',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '฿${currencyFormat.format(request.grandTotal)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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

  Widget _summaryRow(IconData icon, String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}
