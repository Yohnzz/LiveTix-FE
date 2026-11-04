import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/ticket_order_model.dart';
import '../../services/dummy_data_service.dart';
import 'refund_status_screen.dart';

class RefundDestinationScreen extends StatefulWidget {
  final UserTicketModel ticket;

  const RefundDestinationScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<RefundDestinationScreen> createState() => _RefundDestinationScreenState();
}

class _RefundDestinationScreenState extends State<RefundDestinationScreen> {
  // 0: Bank, 1: E-wallet
  int _selectedMethodTab = 0;

  final List<String> _bankProviders = const ['BCA', 'Mandiri', 'BNI', 'BRI'];
  final List<String> _ewalletProviders = const ['GoPay', 'OVO', 'DANA', 'ShopeePay'];

  String _selectedProvider = 'BCA';
  late final TextEditingController _nameController;
  late final TextEditingController _accountNumberController;
  bool _isConfirmed = true;

  @override
  void initState() {
    super.initState();
    final currentUser = DummyDataService().currentUserNotifier.value;
    _nameController = TextEditingController(
      text: currentUser?.name ?? '',
    );
    _accountNumberController = TextEditingController(text: '8808 1234 5678 9012');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _onMethodTabChanged(int index) {
    setState(() {
      _selectedMethodTab = index;
      _selectedProvider = index == 0 ? _bankProviders.first : _ewalletProviders.first;
      if (index == 1) {
        _accountNumberController.text = '0812 3456 7890';
      } else {
        _accountNumberController.text = '8808 1234 5678 9012';
      }
    });
  }

  void _showConfirmationBottomSheet() {
    if (!_isConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pastikan untuk mencentang konfirmasi data terlebih dahulu'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    final methodType = _selectedMethodTab == 0 ? 'Bank' : 'E-wallet';
    final provider = _selectedProvider;
    final accountName = _nameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Judul Bottom Sheet
              const Text(
                'Periksa data refund',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),

              // Kotak Abu-Abu Detail Rekening
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      methodType == 'Bank' ? 'Bank $provider' : '$provider E-Wallet',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountNumber,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'a.n. $accountName',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Baris Jumlah Refund
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jumlah refund',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475467)),
                  ),
                  Text(
                    widget.ticket.formattedPrice,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Box Peringatan Kuning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setelah dikirim, data tidak bisa diubah.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Salah nomor = dana bisa hilang.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol "Ya, data sudah benar"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final refund = DummyDataService().submitRefund(
                      ticketId: widget.ticket.id,
                      methodType: methodType,
                      providerName: provider,
                      accountHolderName: accountName,
                      accountNumber: accountNumber,
                    );

                    Navigator.pop(ctx); // Tutup bottom sheet
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RefundStatusScreen(refund: refund),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A8C), // Navy sesuai Figma
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Ya, data sudah benar',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol "Ubah data"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1B2A8C)),
                    foregroundColor: const Color(0xFF1B2A8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Ubah data',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = _selectedMethodTab == 0 ? _bankProviders : _ewalletProviders;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tujuan refund',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle
            Text(
              'Pilih ke mana dana ${widget.ticket.formattedPrice} akan dikirim.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 20),

            // Tab Segmented: Bank & E-wallet
            _buildSegmentedTab(),
            const SizedBox(height: 20),

            // Provider Pills: BCA, Mandiri, BNI, BRI / GoPay, OVO, etc.
            _buildProviderPills(providers),
            const SizedBox(height: 24),

            // Label & Form Input: Nama Pemilik Rekening
            Text(
              _selectedMethodTab == 0 ? 'Nama pemilik rekening' : 'Nama akun e-wallet',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1B2A8C), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Label & Form Input: Nomor Rekening / Nomor HP
            Text(
              _selectedMethodTab == 0 ? 'Nomor rekening' : 'Nomor HP e-wallet',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1B2A8C), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1B2A8C), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Banner Kuning Peringatan
            _buildNoticeBanner(),
            const SizedBox(height: 20),

            // Checkbox Konfirmasi
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isConfirmed = !_isConfirmed),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _isConfirmed ? const Color(0xFF1B2A8C) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isConfirmed ? const Color(0xFF1B2A8C) : const Color(0xFFD0D5DD),
                      ),
                    ),
                    child: _isConfirmed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Saya memastikan data di atas sudah benar.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF344054),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Tombol Lanjutkan
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _showConfirmationBottomSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A8C), // Navy
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Lanjutkan',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onMethodTabChanged(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedMethodTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMethodTab == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Bank',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _selectedMethodTab == 0 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedMethodTab == 0 ? AppColors.textDark : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onMethodTabChanged(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedMethodTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMethodTab == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'E-wallet',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _selectedMethodTab == 1 ? FontWeight.w700 : FontWeight.w500,
                    color: _selectedMethodTab == 1 ? AppColors.textDark : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderPills(List<String> providers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: providers.map((provider) {
          final isSelected = _selectedProvider == provider;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedProvider = provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1B2A8C) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  provider,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF344054),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEF3C7)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pastikan nomor sudah benar.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF78350F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Dana yang terkirim ke rekening yang salah tidak dapat ditarik kembali. Nama harus sama dengan akun LiveTix kamu.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF92400E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
