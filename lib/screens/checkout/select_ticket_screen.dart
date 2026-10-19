import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../models/ticket_order_model.dart';
import '../../services/dummy_data_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
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
    final currentUser = DummyDataService().currentUserNotifier.value;
    _nameController = TextEditingController(text: currentUser?.name ?? 'Rafi Ahmad');
    _emailController = TextEditingController(text: currentUser?.email ?? 'rafi@email.com');

    if (widget.initialTier != null && !widget.initialTier!.isSoldOut) {
      _selectedTier = widget.initialTier!;
    } else {
      _selectedTier = widget.concert.ticketTiers.firstWhere(
        (t) => !t.isSoldOut,
        orElse: () => const TicketTierModel(
          id: 'fest',
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
  int get _total => _subtotal + _serviceFee;

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

    final order = OrderModel(
      orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      concert: widget.concert,
      tier: _selectedTier,
      quantity: _quantity,
      customerName: _nameController.text.trim(),
      customerEmail: _emailController.text.trim(),
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

              // Data Pemesan
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Text(
              'PANGGUNG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Area Festival (Depan Panggung)
          GestureDetector(
            onTap: () {
              final fest = widget.concert.ticketTiers.firstWhere(
                (t) => t.name.toLowerCase().contains('fest'),
                orElse: () => _selectedTier,
              );
              setState(() => _selectedTier = fest);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _selectedTier.name.toLowerCase().contains('fest')
                    ? const Color(0xFFECFDF5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedTier.name.toLowerCase().contains('fest')
                      ? const Color(0xFF10B981)
                      : AppColors.border,
                  width: _selectedTier.name.toLowerCase().contains('fest') ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedTier.name.toLowerCase().contains('fest'))
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                        ),
                      const Text(
                        'FESTIVAL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Area berdiri di depan panggung',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tribun A & Tribun B
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final tribun = widget.concert.ticketTiers.firstWhere(
                      (t) => t.name.toLowerCase().contains('tribun'),
                      orElse: () => _selectedTier,
                    );
                    setState(() => _selectedTier = tribun);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedTier.name.toLowerCase().contains('tribun')
                          ? const Color(0xFFECFDF5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTier.name.toLowerCase().contains('tribun')
                            ? const Color(0xFF10B981)
                            : AppColors.border,
                        width: _selectedTier.name.toLowerCase().contains('tribun') ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'TRIBUN A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final tribun = widget.concert.ticketTiers.firstWhere(
                      (t) => t.name.toLowerCase().contains('tribun'),
                      orElse: () => _selectedTier,
                    );
                    setState(() => _selectedTier = tribun);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'TRIBUN B',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Legenda
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah tiket',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sisa 214 tiket',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
            // Counter - / +
            Container(
              decoration: BoxDecoration(
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
        const Text(
          'Data pemesan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Tiket akan dikirimkan ke email terdaftar',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Nama lengkap',
          icon: Icons.person_outline,
          controller: _nameController,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Email',
          icon: Icons.mail_outline,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
        ),
      ],
    );
  }

  Widget _buildBottomSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breakdown Rincian
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_quantity}x Tiket ${_selectedTier.name}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                Text(
                  _formatCurrency(_subtotal),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biaya layanan',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                Text(
                  _formatCurrency(_serviceFee),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  _formatCurrency(_total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              text: 'Lanjut ke pembayaran',
              onPressed: _proceedToOrderSummary,
            ),
          ],
        ),
      ),
    );
  }
}
