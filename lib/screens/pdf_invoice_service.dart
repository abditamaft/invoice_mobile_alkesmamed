import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfInvoiceService {
  static final PdfColor kPrimaryColor = PdfColor.fromHex('#11213D');
  static final PdfColor kAccentColor = PdfColor.fromHex('#F9C895');
  static final PdfColor kGreyColor = PdfColor.fromHex('#757575');
  static final PdfColor kLightGrey = PdfColor.fromHex('#F8F9FB');

  static Future<Uint8List> generateInvoiceBytes({
    required Map<String, dynamic> orderData,
    required List<dynamic> items,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontItalic = await PdfGoogleFonts.poppinsItalic();

    final formatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(orderData, fontBold, fontItalic),
            pw.SizedBox(height: 20),
            _buildCustomerInfo(orderData, fontBold),
            pw.SizedBox(height: 20),
            _buildTable(items, formatter, fontBold),
            pw.SizedBox(height: 15),
            _buildTotal(orderData, formatter, fontBold),
            pw.SizedBox(height: 20),
            _buildTerms(orderData['notes'] ?? '', fontBold),
          ];
        },
        footer: (pw.Context context) => _buildFooter(fontItalic),
      ),
    );

    return pdf.save();
  }

  static Future<void> generateInvoice({
    required Map<String, dynamic> orderData,
    required List<dynamic> items,
  }) async {
    final pdfBytes = await generateInvoiceBytes(
      orderData: orderData,
      items: items,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${orderData['invoice_number']}',
    );
  }

  // --- HEADER ---
  static pw.Widget _buildHeader(
    Map<String, dynamic> orderData,
    pw.Font fontBold,
    pw.Font fontItalic,
  ) {
    final invoiceNumber = orderData['invoice_number'] ?? '-';
    // Mengubah format tanggal dari database (created_at)
    String invoiceDate = "-";
    if (orderData['created_at'] != null) {
      DateTime dt = DateTime.parse(orderData['created_at']);
      invoiceDate = DateFormat('dd MMM yyyy HH:mm', 'id').format(dt);
    }

    final paymentMethod = orderData['payment_method'] ?? '-';
    final status = orderData['status']?.toString().toUpperCase() ?? 'PENDING';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "PT. MAMED INDONESIA GROUP",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: kPrimaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Perdagangan & Distribusi Alat Medis",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: kGreyColor,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "Jl. Muwuh, Sumberagung, Plaosan, Magetan\nWhatsApp: 0823-3211-6115",
                style: const pw.TextStyle(fontSize: 9, height: 1.5),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "INVOICE",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 24,
                color: kPrimaryColor,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              "No: $invoiceNumber",
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
            pw.Text(
              "Tanggal: $invoiceDate",
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              "Metode: $paymentMethod",
              style: pw.TextStyle(fontSize: 10, color: kGreyColor),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: status == 'PAID' || status == 'COMPLETED'
                    ? PdfColors.green100
                    : PdfColors.orange100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                "STATUS: $status",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: status == 'PAID' || status == 'COMPLETED'
                      ? PdfColors.green800
                      : PdfColors.orange800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- INFO PELANGGAN ---
  static pw.Widget _buildCustomerInfo(
    Map<String, dynamic> orderData,
    pw.Font fontBold,
  ) {
    // Mengambil relasi shipping dari API
    final shipping = orderData['shipping'] ?? {};
    final buyerName = shipping['recipient_name'] ?? 'Pelanggan';
    final phone = shipping['phone'] ?? '-';
    final address = shipping['full_address'] ?? '-';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "DITAGIHKAN & DIKIRIM KEPADA:",
          style: pw.TextStyle(fontSize: 10, color: kGreyColor, font: fontBold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          buyerName,
          style: pw.TextStyle(
            fontSize: 14,
            font: fontBold,
            color: kPrimaryColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text("Telp: $phone", style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          "Alamat: $address",
          style: const pw.TextStyle(fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  // --- TABEL PRODUK ---
  static pw.Widget _buildTable(
    List<dynamic> items,
    NumberFormat formatter,
    pw.Font fontBold,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        font: fontBold,
        fontSize: 10,
      ),
      headerDecoration: pw.BoxDecoration(color: kPrimaryColor),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['NO', 'DESKRIPSI PRODUK', 'QTY', 'HARGA', 'TOTAL'],
      data: List<List<String>>.generate(items.length, (index) {
        final item = items[index];
        final name = "${item['product_name']} - ${item['variant_name']}";
        final num price = num.tryParse(item['price'].toString()) ?? 0;
        final num qty = num.tryParse(item['quantity'].toString()) ?? 0;
        final total = price * qty;

        return [
          (index + 1).toString(),
          name,
          qty.toString(),
          formatter.format(price),
          formatter.format(total),
        ];
      }),
    );
  }

  // --- PERHITUNGAN TOTAL SESUAI DATABASE ---
  static pw.Widget _buildTotal(
    Map<String, dynamic> orderData,
    NumberFormat formatter,
    pw.Font fontBold,
  ) {
    // Ambil langsung dari field database
    final subtotal = num.tryParse(orderData['subtotal'].toString()) ?? 0;
    final shippingCost =
        num.tryParse(orderData['shipping_cost'].toString()) ?? 0;
    final grandTotal = num.tryParse(orderData['grand_total'].toString()) ?? 0;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: kLightGrey,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildAmountLine(
              "Subtotal Produk",
              formatter.format(subtotal),
              fontBold,
            ),
            pw.SizedBox(height: 6),
            _buildAmountLine(
              "Ongkos Kirim",
              formatter.format(shippingCost),
              fontBold,
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: kAccentColor, thickness: 2),
            pw.SizedBox(height: 10),
            _buildAmountLine(
              "GRAND TOTAL",
              formatter.format(grandTotal),
              fontBold,
              isGrandTotal: true,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "(Sudah Dibayar Lunas)",
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.green800,
                font: fontBold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildAmountLine(
    String title,
    String value,
    pw.Font font, {
    bool isGrandTotal = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: isGrandTotal ? 12 : 10,
            color: kPrimaryColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: isGrandTotal ? 14 : 10,
            color: kPrimaryColor,
            fontWeight: isGrandTotal
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // --- CATATAN & FOOTER ---
  static pw.Widget _buildTerms(String notes, pw.Font fontBold) {
    if (notes.isEmpty) notes = "-";
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Catatan Pembeli:",
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 10,
            color: kPrimaryColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          notes,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font fontItalic) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 5),
        pw.Text(
          "Dokumen ini diterbitkan secara otomatis oleh sistem PT. Mamed Indonesia Group dan sah tanpa tanda tangan.",
          style: pw.TextStyle(fontSize: 8, color: kGreyColor, font: fontItalic),
        ),
      ],
    );
  }
}
