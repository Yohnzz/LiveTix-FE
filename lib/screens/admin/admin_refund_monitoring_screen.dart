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
    return AdminScope(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _service.refundOverviewNotifier,
          _service.refundMonitoringNotifier,
        ]),
        builder: (context, _) {
          final overview = _service.refundOverviewNotifier.value;
          final items = _service.refundMonitoringNotifier.value;
          final textSec = AdminColors.textSecondaryOf(context);
          final accent = AdminColors.accentOf(context);
          final dangerCol = AdminColors.dangerOf(context);

          return Scaffold(
            backgroundColor: AdminColors.bgOf(context),
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
                              Text(
                                'Total dikembalikan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                overview.totalRefundedLabel,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
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
                              Text(
                                'Perlu tindakan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSec,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${overview.actionNeededCount}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: dangerCol,
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
                _buildTabBar(context, items.length),

                // Konten Daftar Konser
                Expanded(
                  child: _buildTabContent(context, items),
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
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, int runningCount) {
    final tabs = [
      'Berjalan ($runningCount)',
      'Selesai',
      'Perlu data',
    ];
    final surface = AdminColors.surfaceOf(context);
    final border = AdminColors.borderOf(context);
    final accent = AdminColors.accentOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: border),
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
                      color: isSelected ? accent : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? accent : textSec,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(
      BuildContext context, List<RefundMonitoringModel> items) {
    if (_selectedTab != 'Berjalan') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tidak ada refund dengan status ${_selectedTab.toLowerCase()}.',
            style: TextStyle(
              fontSize: 14,
              color: AdminColors.textSecondaryOf(context),
            ),
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
        return _buildMonitoringCard(context, item);
      },
    );
  }

  Widget _buildMonitoringCard(
      BuildContext context, RefundMonitoringModel item) {
    final progress = item.totalTickets > 0
        ? (item.refundedTickets / item.totalTickets).clamp(0.0, 1.0)
        : 0.0;
    final isGreen = item.percent >= 50;
    final accent = AdminColors.accentOf(context);
    final successCol = AdminColors.successOf(context);
    final percentColor = isGreen ? successCol : accent;
    final progressColor = isGreen ? const Color(0xFF10B981) : accent;
    final formattedRefunded = ApprovalFormat.thousands(item.refundedTickets);
    final formattedTotal = ApprovalFormat.thousands(item.totalTickets);
    final formattedAmount = ApprovalFormat.rupiah(item.refundedAmount);
    final textPri = AdminColors.textPrimaryOf(context);
    final textSec = AdminColors.textSecondaryOf(context);

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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminColors.warningBgOf(context),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Berjalan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.warningOf(context),
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
                style: TextStyle(
                  fontSize: 13,
                  color: textSec,
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
              backgroundColor: AdminColors.isDark(context)
                  ? AdminColors.darkBorder
                  : const Color(0xFFE5E7EB),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: textSec,
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    'Lihat ›',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
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
