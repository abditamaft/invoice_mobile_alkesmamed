import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // 🔥 TAMBAHAN: Import untuk Timer
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'pdf_invoice_service.dart';
import 'edit_invoice_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notification_service.dart';
import 'manual_invoice_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'mobile_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  final String adminName;
  const DashboardScreen({super.key, this.adminName = "Admin"});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color kPrimary = Color(0xFF11213D);
  static const Color kAccent = Color(0xFFF9C895);
  static const Color kBackground = Color(0xFFF8F9FB);

  List<dynamic> _orders = [];
  bool _isLoading = false;

  // 🔥 MEMORI UNTUK MENDETEKSI PERUBAHAN
  Map<String, String> _previousOrderStatuses = {};
  Set<String> _printedInvoices = {};
  SharedPreferences? _prefs;
  bool _isFirstLoad = true;

  // 🔥 TAMBAHAN: Timer untuk polling otomatis
  Timer? _pollingTimer;

  int _activeTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final currencyFormatter = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadPrintedInvoices(); // 🔥 Load dulu dari storage
    _fetchOrdersFromWeb();

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchOrdersFromWeb();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // 🔥 WAJIB: Hentikan timer saat keluar halaman
    _searchController.dispose();
    super.dispose();
  }

  // 🔥 Load daftar invoice yang sudah dicetak dari storage
  Future<void> _loadPrintedInvoices() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String> saved = _prefs?.getStringList('printed_invoices') ?? [];
    setState(() {
      _printedInvoices = saved.toSet();
    });
  }

  // 🔥 Simpan daftar invoice yang sudah dicetak ke storage
  Future<void> _savePrintedInvoices() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList('printed_invoices', _printedInvoices.toList());
  }

  Future<void> _fetchOrdersFromWeb() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://alkesmamed.com/api/orders'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> fetchedOrders = data['data'] ?? [];

        // 🔥 LOGIKA PENDETEKSI PERUBAHAN UNTUK NOTIFIKASI
        if (!_isFirstLoad) {
          for (var order in fetchedOrders) {
            String id = order['id'].toString();
            String currentStatus =
                order['status']?.toString().toLowerCase() ?? 'pending';

            String username =
                (order['shipping'] != null &&
                    order['shipping']['recipient_name'] != null)
                ? order['shipping']['recipient_name']
                : 'Pelanggan';
            num grandTotal = num.tryParse(order['grand_total'].toString()) ?? 0;
            String formattedTotal = currencyFormatter.format(grandTotal);

            // Cek apakah pesanan baru atau statusnya berubah
            if (!_previousOrderStatuses.containsKey(id) ||
                _previousOrderStatuses[id] != currentStatus) {
              String notifTitle = "Pesanan Update!";
              String notifBody = "";

              if (currentStatus == 'pending') {
                notifTitle = "🛒 Pesanan Baru Masuk!";
                notifBody =
                    "Pelanggan $username menunggu pembayaran sebesar $formattedTotal.";
              } else if (currentStatus == 'paid') {
                notifTitle = "✅ Pembayaran Berhasil!";
                notifBody =
                    "Pelanggan $username telah membayar sebesar $formattedTotal. Segera proses!";
              } else if (currentStatus == 'cancelled') {
                notifTitle = "❌ Pesanan Dibatalkan";
                notifBody =
                    "Pelanggan $username membatalkan pesanan senilai $formattedTotal.";
              }

              if (notifBody.isNotEmpty) {
                NotificationService.showNotification(
                  id: int.parse(id),
                  title: notifTitle,
                  body: notifBody,
                );
              }
            }
          }
        }

        // Simpan state saat ini ke memori
        Map<String, String> newMemory = {};
        for (var order in fetchedOrders) {
          newMemory[order['id'].toString()] =
              order['status']?.toString().toLowerCase() ?? 'pending';
        }

        setState(() {
          _orders = fetchedOrders;
          _previousOrderStatuses = newMemory;
          _isFirstLoad = false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Koneksi Error: Pastikan internet aktif!"),
          ),
        );
      }
    }
  }

  // --- LOGIKA FILTERING ---
  List<dynamic> get _filteredOrders {
    List<dynamic> list = _orders;

    if (_activeTab == 0) {
      // 🔥 Tab Lunas: tampilkan paid, processing, shipped (belum completed)
      list = list.where((o) {
        final s = o['status']?.toString().toLowerCase() ?? '';
        return s == 'paid' || s == 'processing' || s == 'shipped';
      }).toList();
    } else {
      // Tab Antrean: hanya pending
      list = list
          .where((o) => o['status']?.toString().toLowerCase() == 'pending')
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((order) {
        final invNumber = (order['invoice_number'] ?? "")
            .toString()
            .toLowerCase();
        final clientName =
            (order['shipping'] != null &&
                order['shipping']['recipient_name'] != null)
            ? order['shipping']['recipient_name'].toString().toLowerCase()
            : "pelanggan";
        return invNumber.contains(_searchQuery.toLowerCase()) ||
            clientName.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return list;
  }

  // --- FUNGSI CETAK PDF ---
  Future<void> _printPdfAction(dynamic orderData) async {
    List<dynamic> items = orderData['items'] ?? [];

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal: Data item produk kosong dari database!"),
        ),
      );
      return;
    }

    PdfInvoiceService.generateInvoice(orderData: orderData, items: items);
    // 🔥 Tandai invoice sudah dicetak dan simpan permanen
    setState(() {
      _printedInvoices.add(orderData['invoice_number'].toString());
    });
    await _savePrintedInvoices(); // 🔥 Simpan ke SharedPreferences
  }

  Future<void> _scanQRCode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileScannerScreen(
          onDetected: (invoice) {
            final foundOrder = _orders.firstWhere(
              (order) => order['invoice_number'] == invoice,
              orElse: () => null,
            );

            if (foundOrder != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Pesanan $invoice ditemukan! Membuka PDF..."),
                  backgroundColor: Colors.green,
                ),
              );
              _printPdfAction(foundOrder);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Gagal: Nomor Invoice tidak ditemukan!"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // --- BOTTOM SHEET DETAIL PESANAN ---
  void _showOrderDetail(BuildContext context, dynamic item) {
    String invNumber = item['invoice_number'] ?? "INV/XXX";

    final shipping = item['shipping'] ?? {};
    String clientName = shipping['recipient_name'] ?? "Pelanggan Baru";
    String phone = shipping['phone'] ?? "-";
    String address = shipping['full_address'] ?? "Alamat belum tersedia";

    String status = item['status']?.toString().toUpperCase() ?? "PENDING";
    num grandTotal = num.tryParse(item['grand_total'].toString()) ?? 0;
    num shippingCost = num.tryParse(item['shipping_cost'].toString()) ?? 0;

    List<dynamic> items = item['items'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(25, 20, 20, 20),
              decoration: const BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Detail Pesanan",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          invNumber,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusBadge(status, large: false),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ISI DETAIL
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "INFORMASI PENGIRIMAN",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDetailRow(
                      Icons.person_pin_rounded,
                      "Nama Penerima",
                      clientName,
                    ),
                    const Divider(height: 25),
                    _buildDetailRow(
                      Icons.phone_android_rounded,
                      "Kontak (No HP)",
                      phone,
                    ),
                    const Divider(height: 25),
                    _buildDetailRow(
                      Icons.location_on_rounded,
                      "Alamat Lengkap",
                      address,
                    ),

                    const SizedBox(height: 30),

                    Text(
                      "DAFTAR PRODUK (${items.length} Item)",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...items.map((prod) {
                      String prodName = prod['product_name'] ?? '-';
                      String variant = prod['variant_name'] ?? '';
                      String qty = prod['quantity']?.toString() ?? '0';
                      num price =
                          num.tryParse(prod['price']?.toString() ?? '0') ?? 0;
                      num subTotal = price * (num.tryParse(qty) ?? 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: kPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$prodName${variant.isNotEmpty ? ' ($variant)' : ''}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$qty x ${currencyFormatter.format(price)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormatter.format(subTotal),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 30),

                    Text(
                      "INFORMASI PEMBAYARAN",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDetailRow(
                      Icons.local_shipping_rounded,
                      "Ongkos Kirim",
                      currencyFormatter.format(shippingCost),
                    ),
                    const Divider(height: 25),
                    _buildDetailRow(
                      Icons.payments_rounded,
                      "Grand Total",
                      currencyFormatter.format(grandTotal),
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
            ),

            // TOMBOL BAWAH
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditInvoiceScreen(orderData: item),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.edit_document,
                            color: kPrimary,
                            size: 18,
                          ),
                          label: Text(
                            "EDIT",
                            style: GoogleFonts.poppins(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: kPrimary, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _printPdfAction(item);
                          },
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: kPrimary,
                          ),
                          label: Text(
                            "CETAK INVOICE",
                            style: GoogleFonts.poppins(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendInvoiceToWA(
                        item,
                        items,
                        clientName,
                        phone,
                        grandTotal,
                        shippingCost,
                      ),
                      icon: const Icon(
                        Icons.wechat_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        "KIRIM TAGIHAN KE WHATSAPP",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendInvoiceToWA(
    dynamic order,
    List<dynamic> items,
    String name,
    String phone,
    num grandTotal,
    num shippingCost,
  ) async {
    String waNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (waNumber.startsWith('0')) waNumber = '62${waNumber.substring(1)}';

    String itemListText = "";
    for (var prod in items) {
      String prodName = prod['product_name'] ?? '-';
      num qty = num.tryParse(prod['quantity']?.toString() ?? '0') ?? 0;
      num price = num.tryParse(prod['price']?.toString() ?? '0') ?? 0;
      itemListText +=
          "- $qty x $prodName (${currencyFormatter.format(price)})\n";
    }

    String message =
        "Halo *$name*,\nTerima kasih telah berbelanja di *PT. Mamed Indonesia Group*.\n\nBerikut rincian pesanan Anda:\n🧾 *No. Invoice:* ${order['invoice_number'] ?? '-'}\n📦 *Produk:*\n$itemListText\n🚚 *Ongkir:* ${currencyFormatter.format(shippingCost)}\n------------------------\n💰 *GRAND TOTAL: ${currencyFormatter.format(grandTotal)}*\n\nPesanan Anda berstatus: *${order['status']?.toString().toUpperCase()}*.\nTerima kasih!";

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

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: isHighlight ? Colors.green : kPrimary, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? Colors.green : kPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 150.0,
            pinned: true,
            elevation: 0,
            backgroundColor: kPrimary,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.sync, color: Colors.white),
                onPressed: _fetchOrdersFromWeb,
              ),
              GestureDetector(
                onTap: () => _showLogoutConfirmation(context),
                child: const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.person, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary, Color(0xFF1B355B)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 25, bottom: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selamat Pagi,",
                        style: GoogleFonts.poppins(
                          color: kAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.adminName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildStatCard(
                    "Pesanan Lunas",
                    "${_orders.where((o) {
                      final s = o['status']?.toString().toLowerCase() ?? '';
                      return s == 'paid' || s == 'processing' || s == 'shipped';
                    }).length}",
                    Icons.check_circle_rounded,
                    Colors.green,
                  ),
                  const SizedBox(width: 15),
                  _buildStatCard(
                    "Antrean Lainnya",
                    "${_orders.where((o) => o['status']?.toString().toLowerCase() == 'pending').length}",
                    Icons.pending_actions_rounded,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManualInvoiceScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.add_box_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: const Text(
                    "Buat Manual Invoice",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11213D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _buildTabItem(0, "Pesanan Lunas"),
                    _buildTabItem(1, "Antrean Lainnya"),
                  ],
                ),
              ),
            ),
          ),
          // 🔥 KOLOM PENCARIAN & TOMBOL SCAN QR CODE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // TextField Pencarian (Mengecil menyesuaikan ruang)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: "Cari nomor invoice / nama...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                        ), // Biar gak terlalu tinggi
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tombol Scan QR Code
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                      onPressed: _scanQRCode, // Panggil fungsi scan
                      tooltip: "Scan QR Invoice",
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _filteredOrders.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(child: Text("Tidak ada data pesanan")),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildOrderCard(_filteredOrders[index]),
                      childCount: _filteredOrders.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? kPrimary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic item) {
    String inv = item['invoice_number'] ?? "INV/XXX";
    String name = (item['shipping'] != null)
        ? item['shipping']['recipient_name']
        : "Pelanggan Baru";
    String status = item['status']?.toString().toUpperCase() ?? "PENDING";
    num total = num.tryParse(item['grand_total'].toString()) ?? 0;

    // 🔥 Cek apakah invoice ini sudah dicetak
    bool sudahCetak = _printedInvoices.contains(inv);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // 🔥 Warna card: abu-abu mati jika sudah cetak, putih jika belum
        color: sudahCetak ? const Color(0xFFE8E8E8) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: sudahCetak
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          // 🔥 Icon berubah jika sudah cetak
          backgroundColor: sudahCetak
              ? Colors.grey.shade300
              : kPrimary.withOpacity(0.05),
          child: Icon(
            sudahCetak ? Icons.check_circle : Icons.receipt_long,
            color: sudahCetak ? Colors.grey.shade600 : kPrimary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                inv,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: sudahCetak ? Colors.grey.shade600 : kPrimary,
                ),
              ),
            ),
            // 🔥 Badge "Sudah Cetak" / "Belum Cetak"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sudahCetak
                    ? Colors.grey.shade200
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sudahCetak
                      ? Colors.grey.shade400
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sudahCetak
                        ? Icons.print_rounded
                        : Icons.print_disabled_rounded,
                    size: 10,
                    color: sudahCetak
                        ? Colors.grey.shade600
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sudahCetak ? "Sudah Cetak" : "Belum Cetak",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: sudahCetak
                          ? Colors.grey.shade600
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: sudahCetak ? Colors.grey.shade500 : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currencyFormatter.format(total),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sudahCetak ? Colors.grey.shade500 : Colors.green,
              ),
            ),
          ],
        ),
        trailing: _buildStatusBadge(status),
        onTap: () => _showOrderDetail(context, item),
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool large = false}) {
    Color color = (status == 'PAID' || status == 'COMPLETED')
        ? Colors.green
        : Colors.orange;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 15 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar dari akun Admin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              // 🔥 Hapus sesi login dari SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('admin_name');
              await prefs.remove('login_timestamp');

              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (r) => false,
              );
            },
            child: const Text(
              "Ya, Keluar",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
