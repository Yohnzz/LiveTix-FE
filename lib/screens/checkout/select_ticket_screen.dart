import 'package:flutter/material.dart';
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

    if (widget.initialTier != null && !widget.initialTier!.isSoldOut) {
      _selectedTier = widget.initialTier!;
    } else {
      _selectedTier = widget.concert.ticketTiers.firstWhere(
        (t) => !t.isSoldOut,
        orElse: () => const TicketTierModel(
          id: 'c1-fest',
          name: 'Festival',
          description: 'Berdiri depan panggung',
          price: 350000,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

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

    final currentUser = DataService().currentUser;
    final order = OrderModel(
      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      concert: widget.concert,
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
    // Menyiapkan tier area panggung dari data konser
    final vipTier = widget.concert.ticketTiers.firstWhere(
      (t) => t.id.contains('vip') || t.name.toLowerCase().contains('vip'),
      orElse: () => const TicketTierModel(
        id: 'c1-vip',
        name: 'VIP Lounge',
        description: 'Tempat duduk VIP eksklusif depan panggung',
        price: 750000,
      ),
    );

    final festTier = widget.concert.ticketTiers.firstWhere(
      (t) => t.id.contains('fest') || t.name.toLowerCase().contains('fest'),
      orElse: () => const TicketTierModel(
        id: 'c1-fest',
        name: 'Festival',
        description: 'Area berdiri di depan panggung',
        price: 350000,
      ),
    );

    final tribunATier = widget.concert.ticketTiers.firstWhere(
      (t) => t.id.contains('tribun-a') || t.name.toLowerCase() == 'tribun a',
      orElse: () => widget.concert.ticketTiers.firstWhere(
        (t) => t.name.toLowerCase().contains('tribun'),
        orElse: () => const TicketTierModel(
          id: 'c1-tribun-a',
          name: 'Tribun A',
          description: 'Tempat duduk bernomor sisi barat',
          price: 220000,
        ),
      ),
    );

    final tribunBTier = widget.concert.ticketTiers.firstWhere(
      (t) => t.id.contains('tribun-b') || t.name.toLowerCase() == 'tribun b',
      orElse: () => const TicketTierModel(
        id: 'c1-tribun-b',
        name: 'Tribun B',
        description: 'Tempat duduk bernomor sisi timur',
        price: 220000,
      ),
    );

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

          // 1. Area VIP Lounge (Eksklusif Dekat Panggung)
          _buildStageAreaCard(
            tier: vipTier,
            title: 'VIP LOUNGE',
            subtitle: 'Tempat duduk VIP eksklusif depan panggung',
            icon: Icons.star_rounded,
          ),
          const SizedBox(height: 10),

          // 2. Area Festival (Depan Panggung)
          _buildStageAreaCard(
            tier: festTier,
            title: 'FESTIVAL',
            subtitle: 'Area berdiri di depan panggung utama',
          ),
          const SizedBox(height: 10),

          // 3 & 4. Area Tribun A (Barat) & Tribun B (Timur)
          Row(
            children: [
              Expanded(
                child: _buildStageAreaCard(
                  tier: tribunATier,
                  title: 'TRIBUN A',
                  subtitle: 'Sisi Barat',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStageAreaCard(
                  tier: tribunBTier,
                  title: 'TRIBUN B',
                  subtitle: 'Sisi Timur',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Legenda Status Pemilihan
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Dipilih'),
              const SizedBox(width: 18),
              _buildLegendItem(Colors.white, 'Tersedia', hasBorder: true),
              const SizedBox(width: 18),
              _buildLegendItem(const Color(0xFFD1D5DB), 'Penuh'),
            ],
          ),
        ],
      ),
    );
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTier = tier;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
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
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(icon, size: 16, color: const Color(0xFFF59E0B)),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFF065F46) : AppColors.textDark,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF047857) : AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tier.formattedPrice,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF10B981) : AppColors.primary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                  '${_selectedTier.formattedPrice} / tiket',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
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
                text: 'Lanjutkan',
                onPressed: _proceedToOrderSummary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
