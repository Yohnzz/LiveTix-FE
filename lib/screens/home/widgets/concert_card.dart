import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/concert_model.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Ikon Vinyl / Target Piringan Hitam
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: concert.iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _VinylIcon(color: concert.iconColor),
              ),
            ),
            const SizedBox(width: 14),

            // Info Konser: Judul & Tanggal/Venue
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    concert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${concert.date} · ${concert.venue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Harga
            Text(
              concert.formattedPrice,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
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
