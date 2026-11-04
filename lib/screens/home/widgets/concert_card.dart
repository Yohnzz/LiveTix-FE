import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/concert_model.dart';
import '../../../widgets/concert_media.dart';

class ConcertCard extends StatelessWidget {
  final ConcertModel concert;
  final VoidCallback? onTap;

  const ConcertCard({
    super.key,
    required this.concert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isDark = AppColors.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackPriceBelow =
                constraints.maxWidth < 280 || textScale > 1.25;

            return Row(
              children: [
                // Logo Konser Persegi (1:1 dari Produser, fallback ikon vinyl)
                ConcertSquareLogo(
                  concert: concert,
                  size: 54,
                  borderRadius: 14,
                  fallbackChild: _VinylIcon(color: concert.iconColor),
                ),
                const SizedBox(width: 14),

                // Info Konser: Judul, Tanggal/Venue, serta Harga adaptif pada layar sempit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        concert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${concert.date} · ${concert.venue}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                        ),
                      ),
                      if (stackPriceBelow) ...[
                        const SizedBox(height: 4),
                        Text(
                          concert.formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryDark : AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!stackPriceBelow) ...[
                  const SizedBox(width: 8),
                  Text(
                    concert.formattedPrice,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VinylIcon extends StatelessWidget {
  final Color color;

  const _VinylIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lingkaran luar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          // Titik pusat
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          // Lubang pusat kecil putih
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
