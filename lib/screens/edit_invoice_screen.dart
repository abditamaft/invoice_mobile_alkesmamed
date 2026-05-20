import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'pdf_invoice_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EditInvoiceScreen extends StatefulWidget {
  final dynamic orderData;
  const EditInvoiceScreen({super.key, required this.orderData});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  static const Color kPrimary = Color(0xFF11213D);
  static const Color kAccent = Color(0xFFF9C895);

  final currencyFormatter = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Controllers untuk field yang bisa diedit
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _shippingCostCtrl;

  // Custom Field Baru
  TextEditingController _dpCtrl = TextEditingController(text: '0');
  TextEditingController _ttdNameCtrl = TextEditingController(
    text: 'Admin Alkes Mamed',
  );
  TextEditingController _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _editableItems = [];

  @override
  void initState() {
    super.initState();
    final shipping = widget.orderData['shipping'] ?? {};
    _nameCtrl = TextEditingController(
      text: shipping['recipient_name'] ?? 'Pelanggan',
    );
    _phoneCtrl = TextEditingController(text: shipping['phone'] ?? '');
    _addressCtrl = TextEditingController(text: shipping['full_address'] ?? '');
    _shippingCostCtrl = TextEditingController(
      text: widget.orderData['shipping_cost']?.toString() ?? '0',
    );
    _notesCtrl = TextEditingController(text: widget.orderData['notes'] ?? '');

    // Ekstrak item agar bisa diedit
    List<dynamic> items = widget.orderData['items'] ?? [];
    for (var item in items) {
      String name = "${item['product_name']} ${item['variant_name'] ?? ''}"
          .trim();
      _editableItems.add({
        'nameCtrl': TextEditingController(text: name),
        'qtyCtrl': TextEditingController(
          text: item['quantity']?.toString() ?? '1',
        ),
        'priceCtrl': TextEditingController(
          text: item['price']?.toString() ?? '0',
        ),
      });
    }
  }

  // --- LOGIKA PERHITUNGAN OTOMATIS ---
  Map<String, num> _calculateTotals() {
    num subtotal = 0;
    for (var item in _editableItems) {
      num qty = num.tryParse(item['qtyCtrl'].text) ?? 0;
      num price = num.tryParse(item['priceCtrl'].text) ?? 0;
      subtotal += (qty * price);
    }
    num shipping = num.tryParse(_shippingCostCtrl.text) ?? 0;
    num dp = num.tryParse(_dpCtrl.text) ?? 0;
    num grandTotal = subtotal + shipping;
    num sisaBayar = grandTotal - dp;
    if (sisaBayar < 0) sisaBayar = 0;

    return {
      'subtotal': subtotal,
      'shipping': shipping,
      'grandTotal': grandTotal,
      'dp': dp,
      'sisaBayar': sisaBayar,
    };
  }

  // --- COMPILE DATA UNTUK DILEMPAR KE PDF ---
  void _cetakPdfCustom() {
    final totals = _calculateTotals();

    Map<String, dynamic> customOrderData = {
      'invoice_number': widget.orderData['invoice_number'],
      'created_at': widget.orderData['created_at'],
      'payment_method': widget.orderData['payment_method'],
      'status': widget.orderData['status'],
      'notes': _notesCtrl.text,
      'shipping': {
        'recipient_name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'full_address': _addressCtrl.text,
      },
      'subtotal': totals['subtotal'],
      'shipping_cost': totals['shipping'],
      'grand_total': totals['grandTotal'],
      'dp': totals['dp'],
      'sisa_bayar': totals['sisaBayar'],
      'ttd_name': _ttdNameCtrl.text,
    };

    List<Map<String, dynamic>> customItems = _editableItems.map((item) {
      return {
        'product_name': item['nameCtrl'].text,
        'variant_name': '',
        'quantity': num.tryParse(item['qtyCtrl'].text) ?? 0,
        'price': num.tryParse(item['priceCtrl'].text) ?? 0,
      };
    }).toList();

    PdfInvoiceService.generateInvoice(
      orderData: customOrderData,
      items: customItems,
      isManualEdit: true,
    );
  }

  // --- FUNGSI KIRIM WA KHUSUS EDIT MANUAL ---
  Future<void> _sendWaCustom() async {
    final totals = _calculateTotals();

    String phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor HP pembeli tidak boleh kosong!")),
      );
      return;
    }
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';

    String itemListText = "";
    for (var item in _editableItems) {
      String prodName = item['nameCtrl'].text;
      num qty = num.tryParse(item['qtyCtrl'].text) ?? 0;
      num price = num.tryParse(item['priceCtrl'].text) ?? 0;
      itemListText +=
          "- $qty x $prodName (${currencyFormatter.format(price)})\n";
    }

    String message =
        "Halo *${_nameCtrl.text}*,\nTerima kasih telah berbelanja di *PT. Mamed Indonesia Group*.\n\nBerikut rincian pesanan Anda:\n🧾 *No. Invoice:* ${widget.orderData['invoice_number'] ?? '-'}\n📦 *Produk:*\n$itemListText\n🚚 *Ongkir:* ${currencyFormatter.format(totals['shipping'])}\n------------------------\n💰 *GRAND TOTAL: ${currencyFormatter.format(totals['grandTotal'])}*\n\n";

    if (totals['dp']! > 0) {
      message +=
          "💳 *Telah Dibayar (DP):* ${currencyFormatter.format(totals['dp'])}\n❗ *SISA TAGIHAN:* ${currencyFormatter.format(totals['sisaBayar'])}\n\n";
    }

    if (_notesCtrl.text.isNotEmpty) {
      message += "📝 *Catatan:* ${_notesCtrl.text}\n\n";
    }
    message += "Hormat Kami,\n*${_ttdNameCtrl.text}*";

    final Uri waUrl = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(message)}",
    );

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal membuka WhatsApp.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Edit Manual Invoice",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: kPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Informasi Pelanggan"),
            _buildTextField("Nama Pembeli", _nameCtrl),
            _buildTextField("Nomor Telepon", _phoneCtrl),
            _buildTextField("Alamat Lengkap", _addressCtrl, maxLines: 3),

            const SizedBox(height: 20),
            _buildSectionTitle("Daftar Produk"),
            ..._editableItems.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildTextField("Nama Produk", item['nameCtrl']),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "Qty",
                            item['qtyCtrl'],
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            "Harga Satuan (Rp)",
                            item['priceCtrl'],
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("Biaya & Pembayaran"),
            _buildTextField(
              "Ongkos Kirim (Rp)",
              _shippingCostCtrl,
              isNumber: true,
            ),
            _buildTextField("Uang Muka / DP (Rp)", _dpCtrl, isNumber: true),

            const SizedBox(height: 20),
            _buildSectionTitle("Tambahan PDF"),
            _buildTextField("Catatan", _notesCtrl, maxLines: 2),
            _buildTextField("Nama Tanda Tangan", _ttdNameCtrl),

            const SizedBox(height: 30),
            // PREVIEW TOTAL HARGA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    "Subtotal",
                    currencyFormatter.format(totals['subtotal']),
                  ),
                  _buildSummaryRow(
                    "Ongkos Kirim",
                    currencyFormatter.format(totals['shipping']),
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    "Grand Total",
                    currencyFormatter.format(totals['grandTotal']),
                    isBold: true,
                  ),
                  _buildSummaryRow(
                    "Telah Dibayar (DP)",
                    currencyFormatter.format(totals['dp']),
                    color: Colors.green,
                  ),
                  _buildSummaryRow(
                    "Kekurangan / Sisa",
                    currencyFormatter.format(totals['sisaBayar']),
                    color: Colors.red,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 140,
            ), // Spacing buat tombol floating yang agak besar
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Biar gak nutupin layar
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cetakPdfCustom,
                icon: const Icon(Icons.print, color: kPrimary),
                label: Text(
                  "CETAK PDF CUSTOM",
                  style: GoogleFonts.poppins(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendWaCustom,
                icon: const Icon(Icons.wechat_outlined, color: Colors.white),
                label: Text(
                  "KIRIM WA DENGAN DP & SISA",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: kPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        onChanged: (val) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? kPrimary,
            ),
          ),
        ],
      ),
    );
  }
} // 🔥 INI DIA PENUTUP CLASS YANG BENAR
