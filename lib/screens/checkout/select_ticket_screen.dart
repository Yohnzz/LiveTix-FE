import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/ticket_order_model.dart';
import '../../services/data_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../auth/login_screen.dart';
import 'order_summary_screen.dart';

class SelectTicketScreen extends StatefulWidget {
  final ConcertModel concert;
  final TicketTierModel? initialTier;

  const SelectTicketScreen({
    super.key,
    required this.concert,
    this.initialTier,
  });

  @override
  State<SelectTicketScreen> createState() => _SelectTicketScreenState();
}

class _SelectTicketScreenState extends State<SelectTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  late TicketTierModel _selectedTier;
  late List<TicketTierModel> _availableTiers;
  int _quantity = 2; // Default sesuai Figma (2 tiket)
  final int _maxQuantity = 4;
  final int _serviceFee = 15000;

  @override
  void initState() {
    super.initState();
    final currentUser = DataService().currentUser;

    // Edge Case: Jika user belum login (Guest), arahkan kembali ke LoginScreen
    if (currentUser == null) {
      _nameController = TextEditingController();
      _emailController = TextEditingController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu untuk memesan tiket'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    } else {
      // Ambil otomatis dari auth state / user profil yang login
      _nameController = TextEditingController(text: currentUser.name);
      _emailController = TextEditingController(text: currentUser.email);
    }

    _availableTiers = widget.concert.ticketTiers.isNotEmpty
        ? List.from(widget.concert.ticketTiers)
        : [
            const TicketTierModel(
              id: 'c1-vip',
              name: 'VIP Lounge',
              description: 'Tempat duduk VIP eksklusif depan panggung',
              price: 750000,
            ),
            const TicketTierModel(
              id: 'c1-fest',
              name: 'Festival',
              description: 'Area berdiri di depan panggung utama',
              price: 350000,
            ),
            const TicketTierModel(
              id: 'c1-tribun-a',
              name: 'Tribun A',
              description: 'Sisi Barat',
              price: 220000,
            ),
            const TicketTierModel(
              id: 'c1-tribun-b',
              name: 'Tribun B',
              description: 'Sisi Timur',
              price: 220000,
            ),
          ];

    if (widget.initialTier != null && !widget.initialTier!.isEffectivelySoldOut) {
      _selectedTier = widget.initialTier!;
    } else {
      _selectedTier = _availableTiers.firstWhere(
        (t) => !t.isEffectivelySoldOut,
        orElse: () => _availableTiers.first,
      );
    }

    DataService().stockVersionNotifier.addListener(_onRealtimeStockUpdate);
    _loadLiveTiersIfNeeded();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _applyConcertTiers(ConcertModel? live) {
    if (live == null || live.ticketTiers.isEmpty || !mounted) return;
    _safeSetState(() {
      _availableTiers = List.from(live.ticketTiers);
      final updatedSelected =
          _availableTiers.where((t) => t.id == _selectedTier.id).firstOrNull;
      if (updatedSelected != null) {
        _selectedTier = updatedSelected;
      } else {
        _selectedTier = _availableTiers.firstWhere(
          (t) => !t.isEffectivelySoldOut,
          orElse: () => _availableTiers.first,
        );
      }
    });
  }

  void _onRealtimeStockUpdate() {
    _applyConcertTiers(DataService().cachedConcertById(widget.concert.id));
  }

  Future<void> _loadLiveTiersIfNeeded() async {
    final live = await DataService().getConcertById(widget.concert.id);
    _applyConcertTiers(live);
  }

  @override
  void dispose() {
    DataService().stockVersionNotifier.removeListener(_onRealtimeStockUpdate);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _hasStockError =>
      _selectedTier.isEffectivelySoldOut ||
      _quantity > _selectedTier.availableStock;

  int get _subtotal => _selectedTier.price * _quantity;
  int get _taxAndAdmin => (_subtotal * 0.1).round() + 6500; // Formula pajak & admin
  int get _total => _subtotal + _serviceFee + _taxAndAdmin;

  String _formatCurrency(int amount) {
    final buffer = StringBuffer('Rp');
    final str = amount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  void _proceedToOrderSummary() {
    if (!_formKey.currentState!.validate()) return;

    final available = _selectedTier.availableStock;
    if (_selectedTier.isEffectivelySoldOut || _quantity > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maaf, tiket yang tersedia saat ini hanya tersisa $available tiket. Silakan kurangi jumlah pembelian.',
          ),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    final currentUser = DataService().currentUser;
    final order = OrderModel(
      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      concert: widget.concert.copyWith(ticketTiers: _availableTiers),
      tier: _selectedTier,
      quantity: _quantity,
      customerName: currentUser?.name ?? _nameController.text.trim(),
      customerEmail: currentUser?.email ?? _emailController.text.trim(),
      ticketPrice: _selectedTier.price,
      serviceFee: _serviceFee,
      taxAndAdmin: _taxAndAdmin,
      totalAmount: _subtotal + _serviceFee + _taxAndAdmin,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pilih tiket',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Denah Venue / Panggung
              _buildVenueMap(),
              const SizedBox(height: 24),

              // Jumlah Tiket
              _buildQuantitySection(),
              const SizedBox(height: 24),

              // Data Pemesan (Read-Only Auto-Fill)
              _buildCustomerDataSection(),
              const SizedBox(height: 120), // Spacing untuk bottom bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomSummaryBar(),
    );
  }

  Widget _buildVenueMap() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Panggung Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A1B2A8C),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_external_on_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'PANGGUNG UTAMA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Render tier tiket dinamis sesuai konfigurasi produser konser
          ..._buildDynamicTierCards(),
          const SizedBox(height: 16),

          // Legenda Status Pemilihan
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Dipilih'),
              _buildLegendItem(Colors.white, 'Tersedia', hasBorder: true),
              _buildLegendItem(const Color(0xFFD1D5DB), 'Penuh'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicTierCards() {
    final widgets = <Widget>[];
    final tiers = _availableTiers;

    // 1. Prioritaskan tier VIP / VVIP di depan / paling dekat panggung jika ada
    final vipTiers =
        tiers.where((t) => t.name.toLowerCase().contains('vip')).toList();
    final nonVipTiers =
        tiers.where((t) => !t.name.toLowerCase().contains('vip')).toList();

    for (final vip in vipTiers) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildStageAreaCard(
            tier: vip,
            title: vip.name.toUpperCase(),
            subtitle: vip.description.isNotEmpty
                ? vip.description
                : 'Tempat duduk VIP eksklusif depan panggung',
            icon: Icons.star_rounded,
          ),
        ),
      );
    }

    // 2. Tampilkan tier non-VIP (bila ada nama pendek berpasangan seperti Tribun A & Tribun B)
    int i = 0;
    while (i < nonVipTiers.length) {
      final current = nonVipTiers[i];
      final isShortName = current.name.length <= 14;
      final hasNext = i + 1 < nonVipTiers.length;
      final next = hasNext ? nonVipTiers[i + 1] : null;
      final isNextShort = next != null && next.name.length <= 14;

      if (hasNext && isShortName && isNextShort && nonVipTiers.length > 2) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildStageAreaCard(
                    tier: current,
                    title: current.name.toUpperCase(),
                    subtitle: current.description.isNotEmpty
                        ? current.description
                        : 'Area ${current.name}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStageAreaCard(
                    tier: next,
                    title: next.name.toUpperCase(),
                    subtitle: next.description.isNotEmpty
                        ? next.description
                        : 'Area ${next.name}',
                  ),
                ),
              ],
            ),
          ),
        );
        i += 2;
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildStageAreaCard(
              tier: current,
              title: current.name.toUpperCase(),
              subtitle: current.description.isNotEmpty
                  ? current.description
                  : 'Area resmi ${current.name}',
            ),
          ),
        );
        i += 1;
      }
    }

    return widgets;
  }

  Widget _buildStageAreaCard({
    required TicketTierModel tier,
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    // Mengecek apakah area ini sedang aktif dipilih
    final isSelected = _selectedTier.id == tier.id ||
        _selectedTier.name.toLowerCase() == tier.name.toLowerCase();
    final isSoldOut = tier.isEffectivelySoldOut;
    final available = tier.availableStock;

    return GestureDetector(
      onTap: isSoldOut
          ? null
          : () {
              setState(() {
                _selectedTier = tier;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSoldOut
              ? const Color(0xFFF3F4F6)
              : isSelected
                  ? const Color(0xFFECFDF5)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSoldOut
                ? const Color(0xFFE5E7EB)
                : isSelected
                    ? const Color(0xFF10B981)
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && !isSoldOut
              ? const [
                  BoxShadow(
                    color: Color(0x1410B981),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected && !isSoldOut)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                  )
                else if (icon != null && !isSoldOut)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
                  ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSoldOut
                          ? const Color(0xFF9CA3AF)
                          : isSelected
                              ? const Color(0xFF065F46)
                              : AppColors.textDark,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              isSoldOut ? 'Tiket Penuh / Terjual Habis' : subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isSoldOut
                    ? const Color(0xFF9CA3AF)
                    : isSelected
                        ? const Color(0xFF047857)
                        : AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSoldOut ? 'Habis' : '${tier.formattedPrice} · Sisa $available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSoldOut
                    ? const Color(0xFF9CA3AF)
                    : isSelected
                        ? const Color(0xFF10B981)
                        : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: AppColors.border, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildQuantitySection() {
    final availableStock = _selectedTier.availableStock;
    final exceedsStock = _hasStockError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jumlah tiket',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedTier.formattedPrice} / tiket · Tersedia $availableStock tiket',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: exceedsStock ? const Color(0xFFB91C1C) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    color: _quantity > 1 ? AppColors.textDark : AppColors.textGrey,
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: exceedsStock ? const Color(0xFFB91C1C) : AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    color: _quantity < _maxQuantity ? AppColors.primary : AppColors.textGrey,
                    onPressed: _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (exceedsStock) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maaf, tiket yang tersedia saat ini hanya tersisa $availableStock tiket. Silakan kurangi jumlah pembelian.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.info_outline, size: 13, color: AppColors.textGrey),
            SizedBox(width: 4),
            Text(
              'Maksimal 4 tiket per akun',
              style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Data pemesan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF667085)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Data diambil dari akun kamu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'E-Tiket akan dikirimkan otomatis ke email akun terdaftar',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Nama lengkap',
          icon: Icons.person_outline,
          controller: _nameController,
          readOnly: true,
          helperText: 'Otomatis terisi dari profil akun LiveTix kamu',
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Email',
          icon: Icons.mail_outline,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
          helperText: 'Otomatis terisi dari profil akun LiveTix kamu',
        ),
      ],
    );
  }

  Widget _buildBottomSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedTier.name} · $_quantity tiket',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(_total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: PrimaryButton(
                text: _hasStockError ? 'Stok Tidak Cukup' : 'Lanjutkan',
                onPressed: _hasStockError ? null : _proceedToOrderSummary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
