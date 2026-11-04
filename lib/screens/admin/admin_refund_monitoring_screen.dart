import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_refund_detail_screen.dart';
import 'admin_shell.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Layar Monitoring Refund (Image 2).
class AdminRefundMonitoringScreen extends StatefulWidget {
  const AdminRefundMonitoringScreen({super.key});

  @override
  State<AdminRefundMonitoringScreen> createState() =>
      _AdminRefundMonitoringScreenState();
}

class _AdminRefundMonitoringScreenState
    extends State<AdminRefundMonitoringScreen> {
  final AdminService _service = AdminService();
  String _selectedTab = 'Berjalan';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _service.refundOverviewNotifier,
        _service.refundMonitoringNotifier,
      ]),
      builder: (context, _) {
        final overview = _service.refundOverviewNotifier.value;
        final items = _service.refundMonitoringNotifier.value;

        return Scaffold(
          backgroundColor: AdminColors.background,
          body: Column(
            children: [
              // Header Gradien Monitoring Refund (Image 2)
              AdminHeader(
                title: 'Monitoring Refund',
                subtitle: 'Pantau pengembalian dana konser dibatalkan',
                onBack: () => Navigator.of(context).maybePop(),
              ),

              // 2 Kartu Metrik di Atas Tab Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: AdminCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total dikembalikan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              overview.totalRefundedLabel,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2A8C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perlu tindakan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${overview.actionNeededCount}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tab Bar (Berjalan (2), Selesai, Perlu data)
              _buildTabBar(items.length),

              // Konten Daftar Konser
              Expanded(
                child: _buildTabContent(items),
              ),
            ],
          ),
          bottomNavigationBar: AdminBottomNav(
            currentIndex: 0,
            onTap: (index) {
              AdminNavigation.tab.value = index;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        );
      },
    );
  }

  Widget _buildTabBar(int runningCount) {
    final tabs = [
      'Berjalan ($runningCount)',
      'Selesai',
      'Perlu data',
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AdminColors.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((label) {
            final isRunning = label.startsWith('Berjalan');
            final tabKey = isRunning
                ? 'Berjalan'
                : (label == 'Selesai' ? 'Selesai' : 'Perlu data');
            final isSelected = _selectedTab == tabKey;

            return InkWell(
              onTap: () => setState(() => _selectedTab = tabKey),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF1B2A8C)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1B2A8C)
                        : AdminColors.textGrey,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(List<RefundMonitoringModel> items) {
    if (_selectedTab != 'Berjalan') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tidak ada refund dengan status ${_selectedTab.toLowerCase()}.',
            style: const TextStyle(fontSize: 14, color: AdminColors.textGrey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMonitoringCard(item);
      },
    );
  }

  Widget _buildMonitoringCard(RefundMonitoringModel item) {
    final progress = item.totalTickets > 0
        ? (item.refundedTickets / item.totalTickets).clamp(0.0, 1.0)
        : 0.0;
    final isGreen = item.percent >= 50;
    final percentColor =
        isGreen ? const Color(0xFF059669) : const Color(0xFF1B2A8C);
    final progressColor =
        isGreen ? const Color(0xFF10B981) : const Color(0xFF1B2A8C);
    final formattedRefunded = ApprovalFormat.thousands(item.refundedTickets);
    final formattedTotal = ApprovalFormat.thousands(item.totalTickets);
    final formattedAmount = ApprovalFormat.rupiah(item.refundedAmount);

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Judul Konser & Badge Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Berjalan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris 2: Hitungan Tiket & Persentase
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$formattedRefunded / $formattedTotal tiket',
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminColors.textGrey,
                ),
              ),
              Text(
                '${item.percent}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: percentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Baris 3: Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),

          // Baris 4: Dana Kembali & Tombol Lihat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Dana kembali: $formattedAmount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textGrey,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminRefundDetailScreen(
                        concertId: item.concertId,
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    'Lihat ›',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A8C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
