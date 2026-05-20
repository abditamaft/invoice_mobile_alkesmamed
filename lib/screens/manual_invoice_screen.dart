import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pdf_invoice_service.dart';
import 'package:url_launcher/url_launcher.dart';

class _InvoiceItem {
  final TextEditingController productCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _InvoiceItem({String product = '', String qty = '', String price = ''})
    : productCtrl = TextEditingController(text: product),
      qtyCtrl = TextEditingController(text: qty),
      priceCtrl = TextEditingController(text: price);

  void dispose() {
    productCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class ManualInvoiceScreen extends StatefulWidget {
  const ManualInvoiceScreen({super.key});

  @override
  State<ManualInvoiceScreen> createState() => _ManualInvoiceScreenState();
}

class _ManualInvoiceScreenState extends State<ManualInvoiceScreen> {
  // Controller Input Customer
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerAddressCtrl = TextEditingController();
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _invoiceNoCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Data input barang dinamis untuk support banyak barang
  final List<_InvoiceItem> _items = [];

  // Controller DP
  final TextEditingController _dpCtrl = TextEditingController();

  // State Variables
  String _paymentStatus = 'Lunas'; // Default Lunas
  String _paymentMethod = 'Transfer Bank';
  double _grandTotal = 0;
  double _sisaTagihan = 0;
  String _currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
  final TextEditingController _dateCtrl = TextEditingController();

  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = _currentDate;
    _items.add(_InvoiceItem());
  }

  // Fungsi Kalkulasi Otomatis
  void _calculateTotal() {
    double total = 0;

    for (final item in _items) {
      final qty = double.tryParse(item.qtyCtrl.text) ?? 0;
      final price = double.tryParse(item.priceCtrl.text) ?? 0;
      total += qty * price;
    }

    double dp = 0;
    if (_paymentStatus == 'DP') {
      dp = double.tryParse(_dpCtrl.text) ?? 0;
    } else {
      dp = total;
      _dpCtrl.clear();
    }

    setState(() {
      _grandTotal = total;
      _sisaTagihan = total - dp;
      if (_sisaTagihan < 0) _sisaTagihan = 0;
    });
  }

  Future<void> _createInvoicePdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF11213D)),
      ),
    );

    try {
      // 🔥 Inisialisasi locale data sebelum membuat PDF
      await initializeDateFormatting('id', null);
      final orderNumber = _invoiceNoCtrl.text.isEmpty
          ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
          : _invoiceNoCtrl.text;
      final paidAmount = _paymentStatus == 'DP'
          ? (double.tryParse(_dpCtrl.text) ?? 0)
          : _grandTotal;

      await PdfInvoiceService.generateInvoice(
        orderData: {
          'invoice_number': orderNumber,
          'invoice_date': _currentDate,
          'due_date': DateFormat(
            'dd MMM yyyy',
            'id',
          ).format(DateTime.now().add(const Duration(days: 7))),
          'recipient_name': _customerNameCtrl.text.isEmpty
              ? 'Pelanggan Umum'
              : _customerNameCtrl.text,
          'grand_total': _grandTotal,
          'paid_amount': paidAmount,
          'payment_method': _paymentMethod,
          'payment_status': _paymentStatus,
          'phone': _customerPhoneCtrl.text.isEmpty
              ? '-'
              : _customerPhoneCtrl.text,
          'address': _customerAddressCtrl.text.isEmpty
              ? '-'
              : _customerAddressCtrl.text,
          'notes': _notesCtrl.text,
        },
        items: _items
            .where((item) => item.productCtrl.text.isNotEmpty)
            .map(
              (item) => {
                'product': item.productCtrl.text,
                'price': double.tryParse(item.priceCtrl.text) ?? 0,
                'qty': double.tryParse(item.qtyCtrl.text) ?? 0,
              },
            )
            .toList(),
        isManualEdit: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal membuat PDF: $e")));
      }
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _downloadInvoicePdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF11213D)),
      ),
    );

    try {
      // 🔥 Inisialisasi locale data sebelum membuat PDF
      await initializeDateFormatting('id', null);
      final orderNumber = _invoiceNoCtrl.text.isEmpty
          ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
          : _invoiceNoCtrl.text;
      final paidAmount = _paymentStatus == 'DP'
          ? (double.tryParse(_dpCtrl.text) ?? 0)
          : _grandTotal;

      // 🔥 Cukup panggil method tanpa menyimpan ke variable jika tidak digunakan
      await PdfInvoiceService.generateInvoiceBytes(
        orderData: {
          'invoice_number': orderNumber,
          'invoice_date': _currentDate,
          'due_date': DateFormat(
            'dd MMM yyyy',
            'id',
          ).format(DateTime.now().add(const Duration(days: 7))),
          'recipient_name': _customerNameCtrl.text.isEmpty
              ? 'Pelanggan Umum'
              : _customerNameCtrl.text,
          'grand_total': _grandTotal,
          'paid_amount': paidAmount,
          'payment_method': _paymentMethod,
          'payment_status': _paymentStatus,
          'phone': _customerPhoneCtrl.text.isEmpty
              ? '-'
              : _customerPhoneCtrl.text,
          'address': _customerAddressCtrl.text.isEmpty
              ? '-'
              : _customerAddressCtrl.text,
          'notes': _notesCtrl.text,
        },
        items: _items
            .where((item) => item.productCtrl.text.isNotEmpty)
            .map(
              (item) => {
                'product': item.productCtrl.text,
                'price': double.tryParse(item.priceCtrl.text) ?? 0,
                'qty': double.tryParse(item.qtyCtrl.text) ?? 0,
              },
            )
            .toList(),
        isManualEdit: true,
      );

      if (mounted) Navigator.pop(context);

      // Tampilkan share sheet untuk unduh/simpan PDF
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("PDF siap dibagikan")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal membuat PDF: $e")));
      }
    }
  }

  Future<void> _sendToWhatsApp() async {
    if (_customerPhoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Masukkan nomor telepon customer terlebih dahulu!"),
        ),
      );
      return;
    }

    String waNumber = _customerPhoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (waNumber.startsWith('0')) waNumber = '62${waNumber.substring(1)}';

    String itemListText = "";
    for (var item in _items) {
      if (item.productCtrl.text.isNotEmpty) {
        String prodName = item.productCtrl.text;
        double qty = double.tryParse(item.qtyCtrl.text) ?? 0;
        double price = double.tryParse(item.priceCtrl.text) ?? 0;
        itemListText +=
            "- $qty x $prodName (${currencyFormat.format(price)})\n";
      }
    }

    final orderNumber = _invoiceNoCtrl.text.isEmpty
        ? 'INV-${DateTime.now().millisecondsSinceEpoch}'
        : _invoiceNoCtrl.text;

    String dpText = _paymentStatus == 'DP'
        ? "\n💳 *DP:* ${currencyFormat.format(double.tryParse(_dpCtrl.text) ?? 0)}\n💰 *Sisa Tagihan:* ${currencyFormat.format(_sisaTagihan)}"
        : "";

    String message =
        "Halo *${_customerNameCtrl.text.isEmpty ? 'Pelanggan' : _customerNameCtrl.text}*,\n\nTerima kasih telah mempercayai kami.\n\n📄 *Invoice:* $orderNumber\n📅 *Tanggal:* $_currentDate\n\n📦 *Produk:*\n$itemListText\n------------------------\n💰 *GRAND TOTAL: ${currencyFormat.format(_grandTotal)}*$dpText\n\n🏢 PT. Mamed Indonesia Group\n📍 Jl. Raya Sumber Agung - Randugede No.27\n☎ 082332116115 - 085784899882\n\nTerima kasih!";

    final Uri waUrl = Uri.parse(
      "https://wa.me/$waNumber?text=${Uri.encodeComponent(message)}",
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
  void dispose() {
    _customerNameCtrl.dispose();
    _customerAddressCtrl.dispose();
    _invoiceNoCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    _customerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    _dateCtrl.dispose();
    _dpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buat Manual Invoice"),
        backgroundColor: const Color(0xFF11213D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "CV. KIAN RAYA CEMERLANG",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Office: Jl. Raya Sumber Agung - Randugede No.27\nDk. Ngrandu, Ds. Sumber Agung, Kec. Plaosan\nKab. Magetan - Jawa Timur",
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Telp: 082332116115 - 085784899882",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Data Customer",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput("No. Order/INV", _invoiceNoCtrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInput(
                            "Tanggal",
                            _dateCtrl,
                            isReadOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      "Nama Customer (Instansi/Pribadi)",
                      _customerNameCtrl,
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      "No. Telp Pemesan",
                      _customerPhoneCtrl,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _buildInput(
                      "Alamat Customer",
                      _customerAddressCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF7F9FB),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Transfer Bank',
                              child: Text('Transfer Bank'),
                            ),
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'Cash On Delivery',
                              child: Text('COD'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInput("Catatan Tambahan", _notesCtrl, maxLines: 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 3. BAGIAN INPUT BARANG
            // ==========================================
            const Text(
              "Data Barang",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Column(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInput(
                            "Nama Barang",
                            item.productCtrl,
                            onChanged: (value) => _calculateTotal(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            "Qty",
                            item.qtyCtrl,
                            isNumber: true,
                            onChanged: (value) => _calculateTotal(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildInput(
                            "Harga Satuan",
                            item.priceCtrl,
                            isNumber: true,
                            onChanged: (value) => _calculateTotal(),
                          ),
                        ),
                        if (_items.length > 1) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _items[index].dispose();
                                _items.removeAt(index);
                                _calculateTotal();
                              });
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _items.add(_InvoiceItem());
                  });
                },
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF11213D),
                ),
                label: const Text(
                  "Tambah Barang",
                  style: TextStyle(
                    color: Color(0xFF11213D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 4. FITUR PEMBAYARAN (DP / LUNAS)
            // ==========================================
            const Text(
              "Status Pembayaran",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paymentStatus,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Lunas',
                      child: Text("LUNAS (Bayar Penuh)"),
                    ),
                    DropdownMenuItem(
                      value: 'DP',
                      child: Text("DP (Down Payment)"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _paymentStatus = value!;
                      _calculateTotal(); // Hitung ulang saat status ganti
                    });
                  },
                ),
              ),
            ),

            // Munculkan Input DP HANYA JIKA pilih DP
            if (_paymentStatus == 'DP') ...[
              const SizedBox(height: 10),
              _buildInput(
                "Masukkan Nominal DP (Rp)",
                _dpCtrl,
                isNumber: true,
                onChanged: (v) => _calculateTotal(),
              ),
            ],

            const SizedBox(height: 30),

            // ==========================================
            // 5. SUMMARY (TOTAL KESELURUHAN)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  _buildSummaryRow("Total Harga", _grandTotal),
                  if (_paymentStatus == 'DP') ...[
                    const Divider(),
                    _buildSummaryRow(
                      "DP Dibayar",
                      double.tryParse(_dpCtrl.text) ?? 0,
                      color: Colors.green,
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      "SISA TAGIHAN",
                      _sisaTagihan,
                      isBold: true,
                      color: Colors.red,
                    ),
                  ] else ...[
                    const Divider(),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Status",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "LUNAS",
                          style: TextStyle(
                            fontSize: 18,
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

            const SizedBox(height: 20),
            // HARDCODE FOOTER (INFO BANK)
            const Text(
              "NB: HARGA SUDAH TERMASUK ONGKIR",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Text(
              "DETAIL BANK: BCA CAB. SURABAYA\nCV. KIAN RAYA CEMERLANG\nRek: 258-285-8001",
              style: TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 30),
            // TOMBOL SIMPAN
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _createInvoicePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFF9C895,
                  ), // Warna orange aksen kamu
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Lihat & Cetak Invoice",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _downloadInvoicePdf,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF11213D)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Unduh Invoice PDF",
                  style: TextStyle(
                    color: Color(0xFF11213D),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sendToWhatsApp,
                icon: const Icon(Icons.wechat_outlined, color: Colors.white),
                label: const Text(
                  "Kirim ke WhatsApp",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget Helper biar codingan nggak berantakan
  Widget _buildInput(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: isNumber ? TextInputType.number : keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF7F9FB),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF11213D), width: 1.3),
        ),
      ),
      style: const TextStyle(fontSize: 15),
    );
  }

  // Widget Helper untuk baris Total
  Widget _buildSummaryRow(
    String title,
    double amount, {
    bool isBold = false,
    Color color = Colors.black,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
