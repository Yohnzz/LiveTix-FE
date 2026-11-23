import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
import '../../../utils/uuid_utils.dart';
import '../widgets/promoter_step_indicator.dart';

class Step3TicketPricingScreen extends StatelessWidget {
  final List<PromoterTicketTier> tiers;
  final ValueChanged<List<PromoterTicketTier>> onTiersChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step3TicketPricingScreen({
    super.key,
    required this.tiers,
    required this.onTiersChanged,
    required this.onNext,
    required this.onBack,
  });

  static int calcAllInPrice(int price) {
    if (price <= 0) return 0;
    final tax = (price * 0.10).round();
    final appFee = (price * 0.02).round();
    final sub = price + tax + appFee;
    return ((sub + 999) ~/ 1000) * 1000;
  }

  void _removeTier(BuildContext context, int index) {
    final updated = List<PromoterTicketTier>.from(tiers)..removeAt(index);
    onTiersChanged(updated);
  }

  /// Bottom sheet untuk tambah / edit kategori tiket.
  /// Jika [existing] diisi, form masuk mode edit.
  void _showTierDialog(BuildContext context, {PromoterTicketTier? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? '${existing.price}' : '');
    final quotaCtrl = TextEditingController(
        text: existing != null ? '${existing.quota}' : '');
    final String quotaType = existing?.quotaType ?? 'Tiket';
    Color selectedColor = existing?.accentColor ?? const Color(0xFFC2185B);

    const palette = <String, Color>{
      'Merah': Color(0xFFEF4444),
      'Kuning': Color(0xFFFACC15),
      'Hijau': Color(0xFF22C55E),
      'Biru': Color(0xFF3B82F6),
      'Hitam': Color(0xFF111827),
      'Magenta': Color(0xFFC2185B),
      'Navy': Color(0xFF1B2A8C),
    };

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF475569)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    const fieldStyle = TextStyle(
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w600,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Theme(
        data: ThemeData.light(),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Kategori Tiket' : 'Tambah Kategori Tiket',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: Color(0xFF0F172A)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: fieldStyle,
                  decoration: deco('Nama Kategori (misal: VIP / Presale)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  style: fieldStyle,
                  decoration: deco('Harga Dasar Produser (Rp)').copyWith(
                    helperText:
                        'Otomatis ditambah pajak 10%, biaya aplikasi 2%, & pembulatan untuk pembeli',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quotaCtrl,
                  keyboardType: TextInputType.number,
                  style: fieldStyle,
                  decoration: deco('Jumlah Kuota'),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Warna Kategori:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in palette.entries) ...[
                              _buildColorChoice(
                                color: e.value,
                                tooltip: e.key,
                                selectedColor: selectedColor,
                                onSelect: (c) =>
                                    setModalState(() => selectedColor = c),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2A8C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      final quota = int.tryParse(quotaCtrl.text.trim()) ?? 0;
                      if (name.isEmpty || price <= 0 || quota <= 0) return;

                      final newTier = PromoterTicketTier(
                        id: existing?.id ?? UuidUtils.generateV4(),
                        name: name,
                        price: price,
                        quota: quota,
                        quotaType: quotaType,
                        accentColor: selectedColor,
                      );

                      if (isEdit) {
                        final updated = tiers
                            .map((t) => t.id == existing.id ? newTier : t)
                            .toList();
                        onTiersChanged(updated);
                      } else {
                        onTiersChanged([...tiers, newTier]);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      isEdit ? 'Simpan Perubahan' : 'Simpan Kategori',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    final totalCapacity = tiers.fold<int>(0, (sum, t) => sum + t.quota);
    final formattedCapacity =
        '${PromoterTicketTier.formatNumber(totalCapacity)} Tiket';

    return ValueListenableBuilder<bool>(
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

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar with Back and Sun
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: onBack,
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
                          onPressed: service.toggleTheme,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title & Subtitle
                    Text(
                      'Paket Harga Tiket',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Langkah 3 dari 5: Tambah & atur kategori harga tiket konser',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stepper (Steps 1, 2, 3 active dari 5 langkah)
                    const PromoterStepIndicator(currentStep: 3, totalSteps: 5),

                    const SizedBox(height: 24),

                    // Section Label
                    Text(
                      'Kategori Tiket Aktif',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // List of Tier Cards
                    if (tiers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 36,
                              color: subtextColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada kategori tiket',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Klik tombol "Tambah Kategori Tiket" di bawah untuk menambahkan kategori (VIP, Reguler, dll), kuota daya tampung, dan harga tiket.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tiers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final tier = tiers[index];
                          final isMagentaTier =
                              tier.accentColor == const Color(0xFFC2185B);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Vertical Color Stripe
                                Container(
                                  width: 4,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: tier.accentColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Tier Information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tier.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            tier.formattedPrice,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: isMagentaTier
                                                  ? const Color(0xFFC2185B)
                                                  : const Color(0xFF1B2A8C),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(Dasar)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subtextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tampil ke Pembeli: Rp ${PromoterTicketTier.formatNumber(calcAllInPrice(tier.price))}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        tier.formattedQuota,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit Icon Button
                                IconButton(
                                  tooltip: 'Edit kategori',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: subtextColor,
                                  ),
                                  onPressed: () =>
                                      _showTierDialog(context, existing: tier),
                                ),
                                // Trash Icon Button
                                IconButton(
                                  tooltip: 'Hapus kategori',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: Color(0xFFC2185B), // Magenta
                                  ),
                                  onPressed: () => _removeTier(context, index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 14),

                    // Outlined Button: "Tambah Kategori Tiket"
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => _showTierDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B2A8C),
                          backgroundColor: cardBg,
                          side: const BorderSide(
                            color: Color(0xFF1B2A8C),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Tambah Kategori Tiket',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B2A8C),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Area: Total Estimasi Kapasitas & Simpan & Tinjau Ringkasan
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Estimasi Kapasitas:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subtextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          formattedCapacity,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC2185B), // Magenta
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2A8C), // Navy
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Lanjut ke Pilih Gate Crew',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildColorChoice({
    required Color color,
    required String tooltip,
    required Color selectedColor,
    required ValueChanged<Color> onSelect,
  }) {
    final isSelected = selectedColor == color;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onSelect(color),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.white,
              width: isSelected ? 2.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}