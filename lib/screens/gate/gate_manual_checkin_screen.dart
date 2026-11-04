import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/gate_model.dart';
import '../../services/data_service.dart';
import 'gate_scan_result_screen.dart';

/// Halaman Input Manual Tiket untuk Kru Gate
/// Digunakan saat QR Code penonton tidak terbaca oleh pemindai kamera.
class GateManualCheckinScreen extends StatefulWidget {
  final GateModel gate;

  const GateManualCheckinScreen({
    super.key,
    required this.gate,
  });

  @override
  State<GateManualCheckinScreen> createState() =>
      _GateManualCheckinScreenState();
}

class _GateManualCheckinScreenState extends State<GateManualCheckinScreen> {
  final TextEditingController _searchController =
      TextEditingController(text: 'SWF-8891-2A');
  String _selectedFilter = 'Kode Booking';
  bool _isCheckedIn = false;

  final List<String> _filters = const ['Kode Booking', 'NIK / KTP', 'Nama'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handlePerformCheckIn() {
    final bookingCode = _searchController.text.trim().isEmpty
        ? 'SWF-8891-2A'
        : _searchController.text.trim();

    final record = DataService().checkInManual(
      gateId: widget.gate.id,
      bookingCode: bookingCode,
      attendeeName: 'Rafi Ahmad',
      category: 'Festival - 2 Orang',
      doorNumber: widget.gate.doorNumber,
      quantity: 2,
    );

    setState(() {
      _isCheckedIn = true;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GateScanResultScreen(
          record: record,
          gate: widget.gate,
          onScanNext: () {
            // Kembali ke layar scanner
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final bool hasMatch = query.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Header Gradien Violet/Ungu
          _buildHeader(),

          // 2. Konten Pencarian & Kartu Hasil
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Field
                  _buildSearchField(),
                  const SizedBox(height: 14),

                  // Filter Chips (Kode Booking, NIK / KTP, Nama)
                  _buildFilterChips(),
                  const SizedBox(height: 16),

                  // Info Hasil
                  Text(
                    hasMatch ? '1 hasil ditemukan' : 'Tidak ada hasil',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Result Card Penonton
                  if (hasMatch) ...[
                    _buildAttendeeCard(),
                    const SizedBox(height: 16),

                    // Kotak Peringatan KTP
                    _buildWarningBox(),
                    const SizedBox(height: 24),

                    // Tombol Aksi Check-in
                    _buildCheckInButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Input Manual',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cari tiket penonton',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B2A8C), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        decoration: InputDecoration(
          hintText: 'Cari tiket...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF475467),
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1B2A8C) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1B2A8C)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475467),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttendeeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C101828),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profil Penonton
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'RA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rafi Ahmad',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'NIK 3573 **** **** 0012',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isCheckedIn
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isCheckedIn ? 'Sudah check-in' : 'Belum check-in',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _isCheckedIn
                          ? const Color(0xFF065F46)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Detail Baris
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildRow('Kode booking', 'SWF-8891-2A'),
                const Divider(height: 22, color: Color(0xFFF1F5F9)),
                _buildRow('Kategori & jumlah', 'Festival - 2 Orang'),
                const Divider(height: 22, color: Color(0xFFF1F5F9)),
                _buildRow('Blok / nomor pintu', widget.gate.doorNumber),
                const Divider(height: 22, color: Color(0xFFF1F5F9)),
                _buildRow('Gate yang valid', widget.gate.fullTitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cocokkan KTP fisik dengan nama penonton',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF78350F),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'sebelum melakukan check-in manual.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handlePerformCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B2A8C),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Check-in Penonton Secara Manual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
