import 'package:flutter/material.dart';
import '../../../models/promoter_models.dart';
import '../../../services/promoter_data_service.dart';
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

  void _removeTier(BuildContext context, int index) {
    if (tiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 kategori tiket aktif.'),
          backgroundColor: Color(0xFFC2185B),
        ),
      );
      return;
    }
    final updated = List<PromoterTicketTier>.from(tiers)..removeAt(index);
    onTiersChanged(updated);
  }

  void _showAddTierDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final quotaCtrl = TextEditingController();
    String quotaType = 'Kursi';
    Color selectedColor = const Color(0xFFC2185B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
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
                  const Text(
                    'Tambah Kategori Tiket',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori (misal: VIP / Presale)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quotaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah Kuota',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: quotaType,
                    items: const [
                      DropdownMenuItem(value: 'Kursi', child: Text('Kursi')),
                      DropdownMenuItem(value: 'Orang', child: Text('Orang')),
                      DropdownMenuItem(value: 'Tiket', child: Text('Tiket')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => quotaType = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Warna Aksen: ', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setModalState(
                        () => selectedColor = const Color(0xFFC2185B)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2185B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == const Color(0xFFC2185B)
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setModalState(
                        () => selectedColor = const Color(0xFF1B2A8C)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A8C),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == const Color(0xFF1B2A8C)
                              ? Colors.black
                              : Colors.transparent,
                          width: 2,
                        ),
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
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      price: price,
                      quota: quota,
                      quotaType: quotaType,
                      accentColor: selectedColor,
                    );
                    onTiersChanged([...tiers, newTier]);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Simpan Kategori',
                    style: TextStyle(
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
                      'Langkah 3 dari 4: Tambah & ubah tier harga penjualan',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stepper (Steps 1, 2, 3 active)
                    const PromoterStepIndicator(currentStep: 3),

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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              // Trash Icon Button
                              IconButton(
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
                        onPressed: () => _showAddTierDialog(context),
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
                        'Simpan & Tinjau Ringkasan',
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
}
