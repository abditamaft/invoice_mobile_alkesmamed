import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'pdf_invoice_service.dart'; // 🔥 Import fungsi PDF yang baru kita buat

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

  int _activeTab = 0; // 0 = Lunas (Paid), 1 = Belum Lunas (Pending dll)
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
    _fetchOrdersFromWeb();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrdersFromWeb() async {
    setState(() => _isLoading = true);
    try {
      // 🔥 Ganti URL dengan URL API Hostinger Bos yang asli
      // Pastikan API Laravel Bos me-return: orders beserta relasi (with(['items', 'shipping']))
      final response = await http.get(
        Uri.parse('https://alkesmamed.com/api/orders'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders =
              data['data'] ??
              []; // Sesuaikan key 'data' atau 'orders' dari API Bos
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Koneksi Error: Pastikan internet aktif!")),
      );
    }
  }

  // --- LOGIKA FILTERING ---
  List<dynamic> get _filteredOrders {
    List<dynamic> list = _orders;

    // Tab 0 = Paid, Tab 1 = Bukan Paid
    if (_activeTab == 0) {
      list = list
          .where((o) => o['status']?.toString().toLowerCase() == 'paid')
          .toList();
    } else {
      list = list
          .where((o) => o['status']?.toString().toLowerCase() != 'paid')
          .toList();
    }

    // Fitur Pencarian
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

  // --- FUNGSI CETAK PDF DARI CARD/BOTTOM SHEET ---
  void _printPdfAction(dynamic orderData) {
    // Mencegah error jika items kosong dari API
    List<dynamic> items = orderData['items'] ?? [];

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal: Data item produk kosong dari database!"),
        ),
      );
      return;
    }

    // Panggil Service PDF
    PdfInvoiceService.generateInvoice(orderData: orderData, items: items);
  }

  // --- BOTTOM SHEET DETAIL PESANAN ---
  void _showOrderDetail(BuildContext context, dynamic item) {
    String invNumber = item['invoice_number'] ?? "INV/XXX";

    final shipping = item['shipping'] ?? {};
    String clientName = shipping['recipient_name'] ?? "Pelanggan Baru";
    String phone = shipping['phone'] ?? "-";
    String address = shipping['full_address'] ?? "Alamat belum tersedia";

    String status = item['status'] ?? "Pending";
    num grandTotal = num.tryParse(item['grand_total'].toString()) ?? 0;
    num shippingCost = num.tryParse(item['shipping_cost'].toString()) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              decoration: const BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(status, large: true),
                ],
              ),
            ),
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
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      Icons.person_pin_rounded,
                      "Nama Penerima",
                      clientName,
                    ),
                    const Divider(height: 30),
                    _buildDetailRow(
                      Icons.phone_android_rounded,
                      "Kontak (No HP)",
                      phone,
                    ),
                    const Divider(height: 30),
                    _buildDetailRow(
                      Icons.location_on_rounded,
                      "Alamat Lengkap",
                      address,
                    ),

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
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      Icons.local_shipping_rounded,
                      "Ongkos Kirim",
                      currencyFormatter.format(shippingCost),
                    ),
                    const Divider(height: 30),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Kembali",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Tutup bottom sheet
                        _printPdfAction(item); // 🔥 LANGSUNG CETAK PDF!
                      },
                      icon: const Icon(Icons.picture_as_pdf, color: kPrimary),
                      label: Text(
                        "CETAK INVOICE",
                        style: GoogleFonts.poppins(
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                    "${_orders.where((o) => o['status'] == 'paid').length}",
                    Icons.check_circle_rounded,
                    Colors.green,
                  ),
                  const SizedBox(width: 15),
                  _buildStatCard(
                    "Antrean Lainnya",
                    "${_orders.where((o) => o['status'] != 'paid').length}",
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: "Cari nomor invoice atau nama...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: kPrimary.withOpacity(0.05),
          child: const Icon(Icons.receipt_long, color: kPrimary),
        ),
        title: Text(
          inv,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              currencyFormatter.format(total),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
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
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (r) => false,
            ),
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
