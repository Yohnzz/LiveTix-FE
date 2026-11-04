import 'package:flutter/material.dart';
import '../../services/promoter_data_service.dart';
import '../../utils/file_picker_helper.dart';
import 'widgets/responsive_promoter_wrapper.dart';

class CustomerChatMessage {
  final String text;
  final bool isUser;
  final String time;

  const CustomerChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class ProducerCustomerServiceScreen extends StatefulWidget {
  final String ticketNumber;
  final String issueTitle;
  final String? subjectTitle;
  final String statusText;

  const ProducerCustomerServiceScreen({
    super.key,
    this.ticketNumber = '#CS-890218',
    this.issueTitle = 'Kendala Verifikasi Upload Konser',
    this.subjectTitle,
    this.statusText = 'TERJAWAB',
  });

  @override
  State<ProducerCustomerServiceScreen> createState() =>
      _ProducerCustomerServiceScreenState();
}

class _ProducerCustomerServiceScreenState
    extends State<ProducerCustomerServiceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<CustomerChatMessage> _messages = [
    const CustomerChatMessage(
      text: 'Tidak Bisa Upload masss',
      isUser: true,
      time: 'Hari ini, 10:15 WIB',
    ),
    const CustomerChatMessage(
      text:
          'Halo Java Promotor, mohon maaf atas kendalanya. Harap pastikan format poster Anda (.jpg/.png) dengan resolusi maksimal 10MB.',
      isUser: false,
      time: 'Hari ini, 10:18 WIB',
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = (customText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final timeStr = 'Hari ini, $hour:$minute WIB';

    setState(() {
      _messages.add(
        CustomerChatMessage(
          text: text,
          isUser: true,
          time: timeStr,
        ),
      );
      if (customText == null) {
        _messageController.clear();
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment() async {
    final picked = await pickNativeFile();
    if (picked != null && picked.trim().isNotEmpty) {
      _sendMessage('Lampiran: ${picked.trim()}');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih file dokumen / screenshot kendala'),
          backgroundColor: Color(0xFF1B2A8C),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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
          final inputBg =
              isDarkMode ? const Color(0xFF161C2A) : const Color(0xFFF2F4F7);

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Top Section & Ticket Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar with Kembali & Theme Toggle (Figma Image 3)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 4),
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

                        const SizedBox(height: 6),

                        // Title & Subtitle (Figma Image 3)
                        Text(
                          'Customer Service',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajukan aduan tiket & bantuan langsung',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Ticket Status Card (Figma Image 3)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDarkMode ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Nomor Tiket: ${widget.ticketNumber}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: subtextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF3), // Soft green
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.statusText,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF027A48), // Dark green
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.subjectTitle ?? widget.issueTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chat Message List (Figma Image 3)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildChatBubble(
                          message: msg,
                          isDarkMode: isDarkMode,
                          textColor: textColor,
                          subtextColor: subtextColor,
                        );
                      },
                    ),
                  ),

                  // Bottom Input Bar (Figma Image 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: cardBorder)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          // + Attachment Icon Button
                          InkWell(
                            onTap: _pickAttachment,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF1E283A)
                                    : const Color(0xFFF2F4F7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Color(0xFF667085),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Text Input Pill
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: _messageController,
                                  onSubmitted: (_) => _sendMessage(),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: textColor,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Tulis pesan Anda...',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF98A2B3),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Send Button (Magenta Circle with arrow)
                          InkWell(
                            onTap: () => _sendMessage(),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFFC2185B), // Magenta
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatBubble({
    required CustomerChatMessage message,
    required bool isDarkMode,
    required Color textColor,
    required Color subtextColor,
  }) {
    if (message.isUser) {
      // User message: right aligned, Navy background, white text
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1B2A8C), // Navy
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(
                fontSize: 10.5,
                color: subtextColor,
              ),
            ),
          ],
        ),
      );
    } else {
      // Admin response: left aligned, White card with subtle border, dark text
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1E283A)
                    : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white12
                      : const Color(0xFFE4E7EC),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: isDarkMode ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(
                fontSize: 10.5,
                color: subtextColor,
              ),
            ),
          ],
        ),
      );
    }
  }
}
