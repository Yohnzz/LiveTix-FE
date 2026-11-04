import 'package:flutter/material.dart';
import '../../models/promoter_models.dart';
import '../../services/promoter_data_service.dart';
import 'promoter_withdrawal_status_screen.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class PromoterWithdrawalHistoryScreen extends StatelessWidget {
  const PromoterWithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ResponsivePromoterWrapper(
      child: ValueListenableBuilder<bool>(
        valueListenable: service.isDarkModeNotifier,
        builder: (context, isDarkMode, _) {
          final textColor =
              isDarkMode ? Colors.white : const Color(0xFF101828);
          final subtextColor =
              isDarkMode ? Colors.white70 : const Color(0xFF667085);
          final cardBg =
              isDarkMode ? const Color(0xFF1B2232) : Colors.white;
          final cardBorder =
              isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar with Kembali & Theme Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                              color: textColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.wb_sunny_outlined,
                        size: 22,
                        color: textColor,
                      ),
                      tooltip: 'Ganti Tema',
                      onPressed: service.toggleTheme,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title & Subtitle
                Text(
                  'Riwayat Penarikan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daftar pengajuan penarikan dana produser',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                  ),
                ),

                const SizedBox(height: 20),

                // Reactive Withdrawal History List
                ValueListenableBuilder<List<PromoterWithdrawalRecord>>(
                  valueListenable: service.withdrawalRecordsNotifier,
                  builder: (context, records, _) {
                    if (records.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: subtextColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada riwayat penarikan dana.',
                              style: TextStyle(
                                fontSize: 14,
                                color: subtextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = records[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PromoterWithdrawalStatusScreen(record: item),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: _buildWithdrawalCard(
                            item: item,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWithdrawalCard({
    required PromoterWithdrawalRecord item,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.dateTimeStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subtextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.status.bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: item.status.textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Amount & Bank Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                item.formattedAmount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                item.bankAccount,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: subtextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Row 3: Ref ID
          Text(
            'Ref ID: ${item.refId}',
            style: TextStyle(
              fontSize: 11,
              color: subtextColor,
            ),
          ),

          // Optional Row 4: Rejection Reason in Red
          if (item.rejectionReason != null &&
              item.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.rejectionReason!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD92D20), // Red error
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
