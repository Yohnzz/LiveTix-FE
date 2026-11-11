import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/customer_service_service.dart';
import '../../services/data_service.dart';
import '../../services/promoter_data_service.dart';

const Color _csPink = Color(0xFFC2185B);
const LinearGradient _csPinkGradient = LinearGradient(
  colors: [Color(0xFFC2185B), Color(0xFFE91E63)],
);

class ProducerCustomerServiceScreen extends StatefulWidget {
  final String? initialTopic;
  final String? subjectTitle;
  final String senderRole; // 'Produser' | 'User' | 'Gatecrew'
  final bool isAdminInbox;

  const ProducerCustomerServiceScreen({
    super.key,
    this.initialTopic,
    this.subjectTitle,
    this.senderRole = 'Produser',
    this.isAdminInbox = false,
  });

  @override
  State<ProducerCustomerServiceScreen> createState() =>
      _ProducerCustomerServiceScreenState();
}

class _ProducerCustomerServiceScreenState
    extends State<ProducerCustomerServiceScreen> {
  final CustomerServiceService _csService = CustomerServiceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State khusus Admin Inbox
  String _selectedAdminRoleTab = 'Produser'; // 'Produser' | 'User'
  String? _activeThreadId;

  final List<String> _producerQuickQuestions = const [
    'Cek status verifikasi konser saya',
    'Berapa lama proses pencairan dana?',
    'Bagaimana cara mengubah dokumen legalitas?',
    'Persetujuan Gate Crew belum aktif',
  ];

  final List<String> _userQuickQuestions = const [
    'Bagaimana cara melihat QR E-Tiket saya?',
    'Apakah tiket bisa dipindahtangankan?',
    'Konser dibatalkan, bagaimana proses refund?',
    'Pembayaran berhasil tapi tiket belum muncul',
  ];

  @override
  void initState() {
    super.initState();
    _csService.addListener(_onServiceUpdated);
    if (!widget.isAdminInbox) {
      final topic = widget.initialTopic ?? widget.subjectTitle;
      final thread = _csService.ensureThreadForAccount(
        role: widget.senderRole,
        initialTopic: topic,
      );
      _activeThreadId = thread.threadId;
    }
    _csService.fetchFromSupabase();
  }

  @override
  void dispose() {
    _csService.removeListener(_onServiceUpdated);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdated() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty || _activeThreadId == null) return;

    if (presetText == null) {
      _messageController.clear();
    }

    final currentUser = DataService().currentUser;
    final isProduser = widget.senderRole.toLowerCase() == 'produser';

    await _csService.sendMessage(
      threadId: _activeThreadId!,
      text: text,
      isFromAdmin: widget.isAdminInbox,
      senderName: widget.isAdminInbox
          ? 'Admin LiveTix'
          : (isProduser
              ? PromoterDataService().promoterName
              : (currentUser?.name ?? 'Pengguna LiveTix')),
      senderEmail: widget.isAdminInbox
          ? 'admin@livetix.com'
          : (currentUser?.email ??
              (isProduser ? 'produser@livetix.com' : 'user@livetix.com')),
      senderRole: widget.isAdminInbox ? 'Admin' : widget.senderRole,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DataService().isDarkModeNotifier,
      builder: (context, isDark, _) {
        if (widget.isAdminInbox && _activeThreadId == null) {
          return _buildAdminInboxScreen(isDark);
        }
        return _buildConversationScreen(isDark);
      },
    );
  }

  Widget _buildAdminInboxScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final threads = _csService.threadsByRole(_selectedAdminRoleTab);
    final produserThreadsCount = _csService.threadsByRole('Produser').length;
    final userThreadsCount = _csService.threadsByRole('User').length;
    final unreadProduser = _csService.unreadCountForRole('Produser');
    final unreadUser = _csService.unreadCountForRole('User');

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header bergaya Beranda Admin
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B2A8C), Color(0xFF4F46E5)],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B2A8C).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 20, 22),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'LAYANAN PENGGUNA & PRODUSER',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Customer Service Admin',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Kelompok chat berdasarkan Produser dan User',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sinkronkan pesan terbaru',
                          onPressed: () => _csService.fetchFromSupabase(),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Kelompok Chat: Produser vs User
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildRoleGroupTab(
                    label: 'Chat Produser ($produserThreadsCount)',
                    badgeCount: unreadProduser,
                    icon: Icons.business_center_rounded,
                    isSelected: _selectedAdminRoleTab == 'Produser',
                    isDark: isDark,
                    onTap: () =>
                        setState(() => _selectedAdminRoleTab = 'Produser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRoleGroupTab(
                    label: 'Chat User ($userThreadsCount)',
                    badgeCount: unreadUser,
                    icon: Icons.people_alt_rounded,
                    isSelected: _selectedAdminRoleTab == 'User',
                    isDark: isDark,
                    onTap: () => setState(() => _selectedAdminRoleTab = 'User'),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: threads.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 48,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada chat dari $_selectedAdminRoleTab',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final lastMsg = thread.lastMessage;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _csService.markThreadReadByAdmin(thread.threadId);
                          setState(() {
                            _activeThreadId = thread.threadId;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: thread.unreadAdminCount > 0
                                  ? const Color(0xFF4F46E5)
                                  : borderColor,
                              width: thread.unreadAdminCount > 0 ? 1.4 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: thread.userRole == 'Produser'
                                      ? const Color(0xFFEDE9FE)
                                      : const Color(0xFFE0E7FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  thread.userName.isNotEmpty
                                      ? thread.userName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            thread.userName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: thread.userRole == 'Produser'
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFDBEAFE),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            thread.userRole,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  thread.userRole == 'Produser'
                                                      ? const Color(0xFFB45309)
                                                      : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      thread.userEmail,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (lastMsg != null)
                                      Text(
                                        '${lastMsg.isFromAdmin ? "Admin: " : ""}${lastMsg.message}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight:
                                              thread.unreadAdminCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                          color: thread.unreadAdminCount > 0
                                              ? textPrimary
                                              : textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${thread.messages.length} pesan · ${_formatTime(thread.updatedAt)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: textSecondary,
                                          ),
                                        ),
                                        if (thread.unreadAdminCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${thread.unreadAdminCount} baru',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleGroupTab({
    required String label,
    required int badgeCount,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3730A3)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3730A3)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationScreen(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final thread = _activeThreadId != null
        ? _csService.getThreadById(_activeThreadId!)
        : null;
    final messages = thread?.messages ?? const <CsMessageModel>[];

    final quickQuestions = widget.senderRole.toLowerCase() == 'produser'
        ? _producerQuickQuestions
        : _userQuickQuestions;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            widget.isAdminInbox ? const Color(0xFF1B2A8C) : surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: widget.isAdminInbox ? Colors.white : textPrimary,
            size: 20,
          ),
          onPressed: () {
            if (widget.isAdminInbox && _activeThreadId != null) {
              setState(() => _activeThreadId = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: widget.isAdminInbox
                    ? null
                    : _csPinkGradient,
                color: widget.isAdminInbox
                    ? Colors.white.withValues(alpha: 0.18)
                    : null,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isAdminInbox
                    ? Icons.person_outline_rounded
                    : Icons.support_agent_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isAdminInbox
                        ? (thread?.userName ?? 'Percakapan Pengguna')
                        : 'Customer Service LiveTix',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.isAdminInbox ? Colors.white : textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.isAdminInbox
                              ? '${thread?.userRole ?? "User"} · ${thread?.userEmail ?? ""}'
                              : 'Terhubung dengan Admin LiveTix',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: widget.isAdminInbox
                                ? Colors.white.withValues(alpha: 0.85)
                                : textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang pesan',
            onPressed: () => _csService.fetchFromSupabase(),
            icon: Icon(
              Icons.refresh_rounded,
              color: widget.isAdminInbox ? Colors.white : textPrimary,
              size: 20,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: Column(
        children: [
          if (!widget.isAdminInbox)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOPIK BANTUAN CEPAT:',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickQuestions.map((q) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _sendMessage(q),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _csPink.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _csPink.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                q,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _csPink,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                // Di tampilan Admin: pesan dari Admin di kanan (isMine = true)
                // Di tampilan User/Produser: pesan dari User/Produser di kanan (isMine = !isFromAdmin)
                final isMine = widget.isAdminInbox
                    ? msg.isFromAdmin
                    : !msg.isFromAdmin;

                return Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isMine
                          ? (widget.isAdminInbox
                              ? const Color(0xFF3730A3)
                              : _csPink)
                          : surfaceColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 16),
                      ),
                      border: isMine ? null : Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              msg.isFromAdmin
                                  ? 'Admin Support LiveTix'
                                  : '${msg.senderName} (${msg.senderRole})',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: widget.isAdminInbox
                                    ? const Color(0xFF4F46E5)
                                    : _csPink,
                              ),
                            ),
                          ),
                        Text(
                          msg.message,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isMine ? Colors.white : textPrimary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(msg.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.75)
                                : textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: textPrimary,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: widget.isAdminInbox
                          ? 'Ketik balasan untuk ${thread?.userName ?? "pengguna"}...'
                          : 'Tulis pesan ke Admin Customer Service...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _sendMessage(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: widget.isAdminInbox
                          ? const LinearGradient(
                              colors: [Color(0xFF1B2A8C), Color(0xFF4F46E5)],
                            )
                          : _csPinkGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
