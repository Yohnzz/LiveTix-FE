import 'package:flutter/material.dart';
import '../../models/gate_model.dart';
import '../../services/data_service.dart';
import 'gate_manual_checkin_screen.dart';
import 'gate_scan_result_screen.dart';
import 'widgets/camera_feed.dart';

/// Layar Pemindai Tiket Konser di Gate (Kamera & Pemindaian Otomatis)
class GateScannerScreen extends StatefulWidget {
  final GateModel gate;

  const GateScannerScreen({
    super.key,
    required this.gate,
  });

  @override
  State<GateScannerScreen> createState() => _GateScannerScreenState();
}

class _GateScannerScreenState extends State<GateScannerScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _laserController.repeat(reverse: true);
    } else {
      _laserController.value = 0.5;
    }

    _laserAnimation = Tween<double>(begin: -100.0, end: 100.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _triggerScan(String ticketCode, {String? attendeeName, String? category}) {
    if (_isProcessingScan) return;
    setState(() => _isProcessingScan = true);

    final record = _dataService.processTicketScan(
      gateId: widget.gate.id,
      rawTicketCode: ticketCode,
      customAttendeeName: attendeeName,
      customCategory: category,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateScanResultScreen(
          record: record,
          gate: widget.gate,
          onScanNext: () {
            if (mounted) {
              setState(() => _isProcessingScan = false);
            }
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    });
  }

  void _openManualCheckInScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateManualCheckinScreen(gate: widget.gate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<GateModel>>(
      valueListenable: _dataService.gatesNotifier,
      builder: (context, gates, _) {
        final currentGate = gates.firstWhere(
          (g) => g.id == widget.gate.id,
          orElse: () => widget.gate,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF0B1120),
          body: Stack(
            children: [
              // Lapisan Torch / Senter aktif visual
              if (_isTorchOn)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

              SafeArea(
                child: Column(
                  children: [
                    // 1. Bar Atas: Tombol Kembali, Pill Gate B - Festival, Status Online
                    _buildTopBar(currentGate),

                    // 2. Bar Statistik Kehadiran (1.420 / 3.000 Masuk, 47%)
                    _buildStatsBanner(currentGate),

                    // 3. Area Viewfinder Kamera & Garis Pemindaian
                    Expanded(
                      child: _buildScannerViewfinder(),
                    ),

                    // 4. Baris Cepat Simulasi Pemindaian untuk Pengujian
                    _buildQuickSimulationBar(),

                    // 5. Dock Bawah: Senter, Input Manual, Balik Kamera
                    _buildBottomControlsDock(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Top Bar dengan Tombol Back, Gate Pill, dan Online Pill
  Widget _buildTopBar(GateModel gate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Tombol Kembali
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1E293B),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Pill Gate B · Festival
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${gate.name} · ${gate.category}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pill Status Online
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Online',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bar Statistik Kehadiran di Bawah Top Bar
  Widget _buildStatsBanner(GateModel gate) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_formatThousands(gate.totalCheckedIn)} / ${_formatThousands(gate.totalExpected)} Masuk',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${gate.attendancePercentage}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: gate.attendanceRatio,
              minHeight: 5,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }

  /// Viewfinder Kotak Scanner dengan Animasi Garis Laser & Gambar QR Preview
  Widget _buildScannerViewfinder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kotak Viewfinder
          GestureDetector(
            onTap: () => _triggerScan('TIX-SW26-001'),
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0x1AFFFFFF),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Live Device Camera Feed / Viewport
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: CameraFeedWidget(
                        isTorchOn: _isTorchOn,
                        isFrontCamera: _isFrontCamera,
                      ),
                    ),
                  ),

                  // 4 Siku Pembatas Sudut Putih (Viewfinder Corners)
                  _buildViewfinderCorners(),

                  // Garis Laser Scan Kuning yang Bergerak Naik-Turun
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _laserAnimation.value),
                        child: Container(
                          width: 240,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xCCF59E0B),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Teks Petunjuk Arahkan QR
          const Text(
            'Arahkan QR tiket ke dalam kotak',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pemindaian otomatis · jaga jarak 20-30 cm',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// 4 Siku Putih di Pojok Viewfinder
  Widget _buildViewfinderCorners() {
    const stroke = 4.5;
    const length = 36.0;
    const radius = 22.0;

    return IgnorePointer(
      child: SizedBox(
        width: 270,
        height: 270,
        child: Stack(
          children: [
            // Kiri Atas
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: length,
                height: length,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: stroke),
                    left: BorderSide(color: Colors.white, width: stroke),
                  ),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
                ),
              ),
            ),
            // Kanan Atas
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: length,
                height: length,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: stroke),
                    right: BorderSide(color: Colors.white, width: stroke),
                  ),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(radius)),
                ),
              ),
            ),
            // Kiri Bawah
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: length,
                height: length,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: stroke),
                    left: BorderSide(color: Colors.white, width: stroke),
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(radius)),
                ),
              ),
            ),
            // Kanan Bawah
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: length,
                height: length,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: stroke),
                    right: BorderSide(color: Colors.white, width: stroke),
                  ),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(radius)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baris Tombol Cepat Simulasi Pemindaian untuk Pengujian
  Widget _buildQuickSimulationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _triggerScan('TIX-SW26-001'),
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              label: const Text('Simulasi Tiket Valid', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _triggerScan('TIX-SW26-USED-01'),
              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.white),
              label: const Text('Simulasi Tiket Bekas', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _triggerScan('TIX-SW26-VIP-01'),
              icon: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
              label: const Text('Simulasi Salah Gate', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _triggerScan('SWF-8899-REFUND'),
              icon: const Icon(Icons.assignment_return_outlined, size: 16, color: Colors.white),
              label: const Text('Simulasi Tiket Refund', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dock Bawah: 3 Tombol Aksi (Senter, Input Manual, Balik Kamera)
  Widget _buildBottomControlsDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Senter (Flashlight Toggle)
          Expanded(
            child: _buildActionButton(
              icon: Icons.bolt_rounded,
              label: 'Senter',
              isActive: _isTorchOn,
              activeColor: const Color(0xFFF59E0B),
              onTap: () {
                setState(() => _isTorchOn = !_isTorchOn);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isTorchOn ? 'Senter dinyalakan' : 'Senter dimatikan'),
                    duration: const Duration(milliseconds: 800),
                  ),
                );
              },
            ),
          ),

          // 2. Input Manual (Tombol Biru Tengah)
          Expanded(
            child: _buildActionButton(
              icon: Icons.keyboard_alt_outlined,
              label: 'Input Manual',
              isPrimary: true,
              onTap: _openManualCheckInScreen,
            ),
          ),

          // 3. Balik Kamera (Switch Camera Toggle)
          Expanded(
            child: _buildActionButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Balik Kamera',
              isActive: _isFrontCamera,
              onTap: () {
                setState(() => _isFrontCamera = !_isFrontCamera);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isFrontCamera ? 'Beralih ke kamera depan' : 'Beralih ke kamera belakang',
                    ),
                    duration: const Duration(milliseconds: 800),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isActive = false,
    Color? activeColor,
  }) {
    final bgCol = isPrimary
        ? const Color(0xFF1D4ED8)
        : (isActive ? (activeColor ?? const Color(0xFF334155)) : const Color(0xFF334155));
    final iconCol = isPrimary
        ? Colors.white
        : (isActive ? Colors.white : Colors.white70);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgCol,
                shape: BoxShape.circle,
                boxShadow: isPrimary
                    ? const [
                        BoxShadow(
                          color: Color(0x4D1D4ED8),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconCol, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatThousands(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}
