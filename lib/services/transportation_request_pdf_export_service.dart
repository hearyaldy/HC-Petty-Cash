import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transportation_request.dart';
import '../models/enums.dart';
import '../utils/logger.dart';
import 'firestore_service.dart';
import 'pdf_signature_helper.dart';

class TransportationRequestPdfExportService {
  final FirestoreService _firestoreService = FirestoreService();

  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.Font? _notoFallback;
  pw.Font? _emojiFont;

  Future<void> _loadFonts() async {
    if (_ttf != null && _ttfBold != null) return;

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
      _ttf = pw.Font.ttf(fontData);
      final fontBoldData =
          await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
      _ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    try {
      _notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      _emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

    await PdfSignatureHelper.load();
  }

  /// Explicit bold font reference — relying on the theme's implicit
  /// base/bold resolution silently degrades to the regular weight if the
  /// bundled bold asset ever fails to load, so bold text always pins this.
  pw.Font? get _boldFont => _ttfBold ?? _notoFallback;

  Future<Uint8List> generateTransportationRequestPdf(
    TransportationRequest request,
    List<TransportationMileageEntry> mileageEntries,
    List<TransportationPerDiemEntry> perDiemEntries,
    List<TransportationHotelEntry> hotelEntries,
  ) async {
    await _loadFonts();

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? _notoFallback ?? pw.Font.helvetica(),
          bold: _ttfBold ?? _notoFallback ?? pw.Font.helveticaBold(),
          fontFallback: [?_notoFallback, ?_emojiFont],
        ),
        header: (context) => _buildHeader(request, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(request, dateTimeFormat),
          pw.SizedBox(height: 16),
          _buildMileageTable(request, mileageEntries, currencyFormat, dateFormat),
          pw.SizedBox(height: 16),
          _buildPerDiemTable(request, perDiemEntries, currencyFormat, dateFormat),
          pw.SizedBox(height: 16),
          _buildHotelTable(hotelEntries, currencyFormat, dateFormat),
          pw.SizedBox(height: 16),
          _buildTotalSection(request, currencyFormat),
          pw.SizedBox(height: 24),
          _buildSignatureSection(),
          pw.SizedBox(height: 16),
          _buildRemarkSection(),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> printTransportationRequest(TransportationRequest request) async {
    final mileageEntries = await _firestoreService
        .transportationMileageEntriesStream(request.id)
        .first;
    final perDiemEntries = await _firestoreService
        .transportationPerDiemEntriesStream(request.id)
        .first;
    final hotelEntries =
        await _firestoreService.transportationHotelEntriesStream(request.id).first;

    final pdfBytes = await generateTransportationRequestPdf(
      request,
      mileageEntries,
      perDiemEntries,
      hotelEntries,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Transportation_Request_${request.requestNumber}',
    );
  }

  pw.Widget _buildHeader(TransportationRequest request, DateFormat dateFormat) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Southeastern Asia Union Mission (SEUM)',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      font: _boldFont,
                      color: PdfColors.teal800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    '193 Moo 3, Muak Lek, Saraburi, 18180, Thailand',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text(
              'TRANSPORTATION REQUEST FORM',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                font: _boldFont,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'No: ${request.requestNumber}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: _boldFont,
                color: PdfColors.teal800,
              ),
            ),
            pw.Text(
              'Date: ${dateFormat.format(request.requestDate)}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: _boldFont,
                color: PdfColors.teal800,
              ),
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.teal200),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildInfoSection(
    TransportationRequest request,
    DateFormat dateTimeFormat,
  ) {
    final travelLocation = request.travelLocation.toTravelLocation();
    final vehicleType = request.vehicleType.toVehicleType();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border.all(color: PdfColors.teal200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              _infoField('Name:', request.requesterName),
              _infoField('Department:', request.department),
            ],
          ),
          pw.SizedBox(height: 8),
          _infoFieldFull('Purpose of Travel:', request.purpose),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _infoField('Destination Place:', request.destinationPlace),
              _infoField('Travel Location:', travelLocation.displayName),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _infoField('Date of Travel:', dateTimeFormat.format(request.travelDateTime)),
              _infoField('Date of Return:', dateTimeFormat.format(request.returnDateTime)),
            ],
          ),
          if (request.departureFlightNumber != null ||
              request.departureFlightTime != null ||
              request.returnFlightNumber != null ||
              request.returnFlightTime != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _infoField(
                  'Departure Flight:',
                  '${request.departureFlightNumber ?? '-'}'
                  '${request.departureFlightTime != null ? ' · ${request.departureFlightTime}' : ''}',
                ),
                _infoField(
                  'Return Flight:',
                  '${request.returnFlightNumber ?? '-'}'
                  '${request.returnFlightTime != null ? ' · ${request.returnFlightTime}' : ''}',
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 8),
          _infoFieldFull(
            'Vehicle Type:',
            vehicleType.isFlatRate
                ? vehicleType.displayName
                : '${vehicleType.displayName} (${vehicleType.ratePerKm.toStringAsFixed(0)}฿/km)',
          ),
        ],
      ),
    );
  }

  pw.Widget _infoField(String label, String value) {
    return pw.Expanded(
      child: _infoFieldFull(label, value),
    );
  }

  pw.Widget _infoFieldFull(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: _boldFont)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildMileageTable(
    TransportationRequest request,
    List<TransportationMileageEntry> entries,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Mileage',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: _boldFont, color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Personal Vehicle: 5฿/km  ·  Van: 7฿/km  ·  Small Pickup / 4x4 Pickup Truck: 5฿/km  ·  '
          'Taxi: ${TaxiAirport.suvarnabhumi.displayName} ฿${TaxiAirport.suvarnabhumi.flatRate.toStringAsFixed(0)} / '
          '${TaxiAirport.donMueang.displayName} ฿${TaxiAirport.donMueang.flatRate.toStringAsFixed(0)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blue200),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.blue100),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Mileage Start', isHeader: true),
                _buildTableCell('Mileage End', isHeader: true),
                _buildTableCell('Total KM', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
                _buildTableCell('Remark', isHeader: true),
              ],
            ),
            ...entries.map((entry) {
              final isTaxi = entry.airport != null;
              final remarkText = isTaxi
                  ? '${entry.airport!.taxiAirportDisplayName}'
                      '${entry.remark != null && entry.remark!.isNotEmpty ? ' — ${entry.remark}' : ''}'
                  : (entry.remark ?? '-');
              return pw.TableRow(
                children: [
                  _buildTableCell(dateFormat.format(entry.date)),
                  _buildTableCell(isTaxi ? 'Taxi' : currencyFormat.format(entry.mileageStart)),
                  _buildTableCell(isTaxi ? 'Taxi' : currencyFormat.format(entry.mileageEnd)),
                  _buildTableCell(isTaxi ? '-' : currencyFormat.format(entry.totalKm)),
                  _buildTableCell(currencyFormat.format(entry.amount)),
                  _buildTableCell(remarkText, align: pw.TextAlign.left),
                ],
              );
            }),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                _buildTableCell('Total', isHeader: true),
                _buildTableCell(''),
                _buildTableCell(''),
                _buildTableCell(currencyFormat.format(request.totalKm), isHeader: true),
                _buildTableCell(currencyFormat.format(request.totalMileageAmount), isHeader: true),
                _buildTableCell(''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPerDiemTable(
    TransportationRequest request,
    List<TransportationPerDiemEntry> entries,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Per Diem',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: _boldFont, color: PdfColors.green800),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Per Diem: 125 Baht/meal (local) or 250 Baht/meal (abroad)',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.green200),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FlexColumnWidth(1.0),
            3: const pw.FlexColumnWidth(1.3),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.green100),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Meals (B / L / S / Incident)', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
                _buildTableCell('Signature', isHeader: true),
              ],
            ),
            ...entries.map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(dateFormat.format(entry.date)),
                    _buildTableCell(
                      '${entry.hasBreakfast ? 'B' : '-'}  ${entry.hasLunch ? 'L' : '-'}  '
                      '${entry.hasSupper ? 'S' : '-'}  ${entry.hasIncidentMeal ? 'I' : '-'}',
                    ),
                    _buildTableCell(currencyFormat.format(entry.amount)),
                    _buildTableCell(''),
                  ],
                )),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _buildTableCell('Total', isHeader: true),
                _buildTableCell(''),
                _buildTableCell(currencyFormat.format(request.totalPerDiemAmount), isHeader: true),
                _buildTableCell(''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildHotelTable(
    List<TransportationHotelEntry> entries,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Hotel',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: _boldFont, color: PdfColors.purple800),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.purple200),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.purple100),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Room / Hotel', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            ...entries.map((entry) => pw.TableRow(
                  children: [
                    _buildTableCell(dateFormat.format(entry.date)),
                    _buildTableCell(entry.hotelName, align: pw.TextAlign.left),
                    _buildTableCell(currencyFormat.format(entry.amount)),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: isHeader ? _boldFont : null,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTotalSection(
    TransportationRequest request,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.teal50,
          border: pw.Border.all(color: PdfColors.teal600, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          'GRAND TOTAL:  ${currencyFormat.format(request.grandTotal)} Baht',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: _boldFont, color: PdfColors.teal900),
          textAlign: pw.TextAlign.right,
        ),
      ),
    );
  }

  pw.Widget _buildSignatureSection() {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBlock('Requested by', showSignature: true),
            _signatureBlock('Approved by Treasurer'),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBlock('Transportation Department'),
            _signatureBlock('Report by'),
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureBlock(String label, {bool showSignature = false}) {
    return pw.Column(
      children: [
        if (showSignature) PdfSignatureHelper.slot(width: 100, height: 40),
        pw.SizedBox(width: 180, child: pw.Divider(thickness: 1)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildRemarkSection() {
    return pw.Text(
      'Remarks: Kindly attach the copy of your air ticket with this form please. Thank you very much.',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }
}
