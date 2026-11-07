import 'package:flutter/material.dart';

class DailySalesData {
  final String dayLabel;
  final String fullDayName;
  final double valueK; // in thousands (e.g. 4.0 for 4k)
  final int ticketsSold;
  final int revenueAmount;
  final bool isPeak;

  const DailySalesData({
    required this.dayLabel,
    required this.fullDayName,
    required this.valueK,
    required this.ticketsSold,
    required this.revenueAmount,
    this.isPeak = false,
  });
}

class SalesTrendBarChart extends StatefulWidget {
  final bool isDarkMode;
  final List<DailySalesData>? salesData;

  const SalesTrendBarChart({
    super.key,
    required this.isDarkMode,
    this.salesData,
  });

  @override
  State<SalesTrendBarChart> createState() => _SalesTrendBarChartState();
}

class _SalesTrendBarChartState extends State<SalesTrendBarChart> {
  int? _selectedBarIndex;

  // Default data matching the user's reference image:
  // Mon: ~4.0k, Tues: ~2.2k, Wed: ~3.4k, Thurs: ~4.5k (Peak, Purple), Fri: ~2.5k, Sat: ~3.3k, Sun: ~2.1k
  late final List<DailySalesData> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.salesData ??
        const [
          DailySalesData(
            dayLabel: 'Mon',
            fullDayName: 'Senin',
            valueK: 4.0,
            ticketsSold: 4000,
            revenueAmount: 1200000000,
          ),
          DailySalesData(
            dayLabel: 'Tues',
            fullDayName: 'Selasa',
            valueK: 2.2,
            ticketsSold: 2200,
            revenueAmount: 660000000,
          ),
          DailySalesData(
            dayLabel: 'Wed',
            fullDayName: 'Rabu',
            valueK: 3.4,
            ticketsSold: 3400,
            revenueAmount: 1020000000,
          ),
          DailySalesData(
            dayLabel: 'Thurs',
            fullDayName: 'Kamis',
            valueK: 4.5,
            ticketsSold: 4500,
            revenueAmount: 1350000000,
            isPeak: true,
          ),
          DailySalesData(
            dayLabel: 'Fri',
            fullDayName: 'Jumat',
            valueK: 2.5,
            ticketsSold: 2500,
            revenueAmount: 750000000,
          ),
          DailySalesData(
            dayLabel: 'Sat',
            fullDayName: 'Sabtu',
            valueK: 3.3,
            ticketsSold: 3300,
            revenueAmount: 990000000,
          ),
          DailySalesData(
            dayLabel: 'Sun',
            fullDayName: 'Minggu',
            valueK: 2.1,
            ticketsSold: 2100,
            revenueAmount: 630000000,
          ),
        ];

    // Default select peak day (Thursday) to showcase stats
    _selectedBarIndex = 3;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1B2232) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E7EC);
    final axisTextColor = isDark ? Colors.white60 : const Color(0xFF667085);
    final defaultBarColor =
        isDark ? const Color(0xFF26324A) : const Color(0xFFF2F4F7);
    const peakBarColor = Color(0xFF8B5CF6); // Vibrant purple from reference
    final gridLineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEAECF0);

    const double chartMaxK = 5.0; // scale from 0 to 5.0k so 4k is top grid line
    const yGridValues = [4.0, 3.0, 2.0, 1.0, 0.0];

    final selected =
        _selectedBarIndex != null ? _data[_selectedBarIndex!] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info: Active day selection tooltip or summary
          if (selected != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${selected.fullDayName} (${selected.dayLabel})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF101828),
                              ),
                            ),
                          ),
                          if (selected.isPeak) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4EBFF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PEAK TERTINGGI',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C3AED),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatNumber(selected.ticketsSold)} Tiket Terjual · ${_formatRupiah(selected.revenueAmount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: selected.isPeak
                              ? const Color(0xFF8B5CF6)
                              : axisTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF222B3D)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: peakBarColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total 22k',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF344054),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Chart Area: Y-Axis + Grid Lines + Bars
          SizedBox(
            height: 165,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-Axis Labels Column (4k, 3k, 2k, 1k, 0)
                SizedBox(
                  width: 24,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: yGridValues.map((val) {
                      final label = val == 0.0 ? '0' : '${val.toInt()}k';
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: axisTextColor,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 8),

                // Main Plot Area with Grid Lines and Bars
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final plotWidth = constraints.maxWidth;
                      final plotHeight = constraints.maxHeight;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Dotted / Dashed Grid Lines (aligned with Y labels)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DottedGridPainter(
                                gridLineColor: gridLineColor,
                                divisions: yGridValues.length - 1,
                              ),
                            ),
                          ),

                          // Bars Row
                          Positioned.fill(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(_data.length, (index) {
                                final item = _data[index];
                                final isSelected =
                                    _selectedBarIndex == index;
                                final isPeak = item.isPeak;

                                // Height proportional to chartMaxK
                                final barHeightFraction =
                                    (item.valueK / chartMaxK).clamp(0.05, 1.0);
                                final barHeight =
                                    plotHeight * barHeightFraction;

                                // Bar width responsive (24 to 34)
                                final barWidth = (plotWidth / _data.length * 0.65)
                                    .clamp(22.0, 34.0);

                                Color barColor;
                                if (isPeak) {
                                  barColor = peakBarColor;
                                } else if (isSelected) {
                                  barColor = isDark
                                      ? const Color(0xFF3B4863)
                                      : const Color(0xFFD0D5DD);
                                } else {
                                  barColor = defaultBarColor;
                                }

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedBarIndex = index;
                                    });
                                  },
                                  child: Container(
                                    color: Colors.transparent, // Hit test target
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: barWidth,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: barColor,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(8),
                                        ),
                                        boxShadow: isPeak
                                            ? [
                                                BoxShadow(
                                                  color: peakBarColor
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // X-Axis Day Labels Row (Mon, Tues, Wed, Thurs, Fri, Sat, Sun)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Row(
              children: List.generate(_data.length, (index) {
                final item = _data[index];
                final isSelected = _selectedBarIndex == index;
                final isPeak = item.isPeak;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBarIndex = index;
                      });
                    },
                    child: Center(
                      child: Text(
                        item.dayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isPeak || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isPeak
                              ? (isDark ? Colors.white : const Color(0xFF101828))
                              : (isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF101828))
                                  : axisTextColor),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String _formatRupiah(int amount) {
    if (amount >= 1000000000) {
      final val = (amount / 1000000000).toStringAsFixed(1);
      return 'Rp$val M';
    }
    if (amount >= 1000000) {
      final val = (amount / 1000000).toStringAsFixed(0);
      return 'Rp$val Jt';
    }
    return 'Rp${_formatNumber(amount)}';
  }
}

class _DottedGridPainter extends CustomPainter {
  final Color gridLineColor;
  final int divisions;

  const _DottedGridPainter({
    required this.gridLineColor,
    required this.divisions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final stepY = size.height / divisions;

    for (int i = 0; i <= divisions; i++) {
      final y = i * stepY;

      // Draw subtle dotted line
      double startX = 0;
      const double dashWidth = 4.0;
      const double dashSpace = 4.0;

      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedGridPainter oldDelegate) {
    return oldDelegate.gridLineColor != gridLineColor ||
        oldDelegate.divisions != divisions;
  }
}
