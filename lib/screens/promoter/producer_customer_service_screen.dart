import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ai_customer_service.dart';
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

  // State khusus Admin Inbox & AI Copilot
  String _selectedAdminRoleTab = 'Produser'; // 'Produser' | 'User'
  String? _activeThreadId;
  bool _isLoadingAiDraft = false;
  bool _isLoadingAiSummary = false;

  // State lampiran gambar untuk analisis AI
  Uint8List? _attachedImageBytes;
  String? _attachedImageName;

  final List<String> _producerQuickQuestions = const [
    'Cek status verifikasi konser saya',
    'Syarat dokumen KTP & Lembar Penanggung Jawab',
    'Berapa lama proses pencairan dana & minimal saldo?',
    'Ketentuan potongan fee platform 2%',
    'Bagaimana cara menambah dan menugaskan Gate Crew?',
  ];

  final List<String> _userQuickQuestions = const [
    'Bagaimana cara scan QR E-Tiket di pintu gate?',
    'Metode pembayaran apa saja yang didukung?',
    'Pembayaran berhasil tapi tiket belum muncul',
    'Konser dibatalkan, bagaimana proses refund 100%?',
    'Apakah tiket konser bisa dipindahtangankan?',
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _attachedImageBytes = bytes;
          _attachedImageName = picked.name;
        });
      }
    } catch (e) {
      debugPrint('Gagal memilih gambar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Lampirkan Gambar untuk Analisis AI',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kirim bukti transfer, e-tiket, atau tangkapan layar kendala untuk dianalisis langsung oleh AI.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Pilih dari Galeri Foto',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Buka galeri perangkat Anda',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _csPink.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: _csPink,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Ambil Foto Kamera',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Ambil foto langsung dengan kamera',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    final hasImage = _attachedImageBytes != null && _attachedImageBytes!.isNotEmpty;
    if ((text.isEmpty && !hasImage) || _activeThreadId == null) return;

    String? imageBase64;
    if (hasImage) {
      imageBase64 = base64Encode(_attachedImageBytes!);
      setState(() {
        _attachedImageBytes = null;
        _attachedImageName = null;
      });
    }

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
      imageBase64: imageBase64,
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

  Future<void> _generateAdminDraft(CsThreadModel thread) async {
    if (_isLoadingAiDraft) return;
    setState(() => _isLoadingAiDraft = true);

    try {
      final draft = await AiCustomerService().generateAdminDraftReply(
        messages: thread.messages,
        userRole: thread.userRole,
        userName: thread.userName,
      );

      if (!mounted) return;
      setState(() {
        _messageController.text = draft;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draf balasan AI berhasil disiapkan. Silakan sesuaikan lalu kirim.',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat draf AI: $e',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAiDraft = false);
    }
  }

  Future<void> _showAiSummaryDialog(CsThreadModel thread, bool isDark) async {
    if (_isLoadingAiSummary) return;
    setState(() => _isLoadingAiSummary = true);

    String summary;
    try {
      summary = await AiCustomerService().summarizeThread(
        messages: thread.messages,
        userRole: thread.userRole,
        userName: thread.userName,
      );
    } catch (e) {
      summary = 'Gagal memuat ringkasan AI: $e';
    } finally {
      if (mounted) setState(() => _isLoadingAiSummary = false);
    }

    if (!mounted) return;

    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ringkasan AI Percakapan',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '${thread.userName} (${thread.userRole})',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      summary,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(
                        'Buat Draf Balasan Otomatis',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _generateAdminDraft(thread);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                                              ' baru',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        else if (lastMsg != null &&
                                            (lastMsg.senderRole == 'AI Support' ||
                                                lastMsg.senderName.contains('AI')))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: const Color(0xFF8B5CF6)
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.auto_awesome,
                                                  size: 10,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Dibalas AI',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        const Color(0xFF7C3AED),
                                                  ),
                                                ),
                                              ],
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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final double extraBottomSpace = bottomInset > 0
        ? 12.0
        : (systemBottomPadding > 0 ? (systemBottomPadding + 10.0) : 20.0);

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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF10B981),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isAdminInbox ? 'AI Copilot' : 'AI 24/7',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
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
              itemCount: messages.length +
                  (_csService.isAiRespondingForThread(thread?.threadId ?? '')
                      ? 1
                      : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2E1065).withValues(alpha: 0.4)
                            : const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                              : const Color(0xFFDDD6FE),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'LiveTix AI Assistant sedang mengetik...',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? const Color(0xFFDDD6FE)
                                  : const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = messages[index];
                final isAiMessage = msg.senderRole == 'AI Support' ||
                    msg.senderName.toLowerCase().contains('ai');
                // Di tampilan Admin: pesan dari Admin di kanan (isMine = true)
                // Di tampilan User/Produser: pesan dari User/Produser di kanan (isMine = !isFromAdmin)
                final isMine = widget.isAdminInbox
                    ? msg.isFromAdmin
                    : !msg.isFromAdmin;

                Color bubbleBg;
                Border? bubbleBorder;
                if (isMine) {
                  bubbleBg = widget.isAdminInbox
                      ? (isAiMessage
                          ? const Color(0xFF4338CA)
                          : const Color(0xFF3730A3))
                      : _csPink;
                  bubbleBorder = null;
                } else if (isAiMessage) {
                  bubbleBg = isDark
                      ? const Color(0xFF2E1065).withValues(alpha: 0.45)
                      : const Color(0xFFF5F3FF);
                  bubbleBorder = Border.all(
                    color: isDark
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                        : const Color(0xFFDDD6FE),
                    width: 1.2,
                  );
                } else {
                  bubbleBg = surfaceColor;
                  bubbleBorder = Border.all(color: borderColor);
                }

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
                      color: bubbleBg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 16),
                      ),
                      border: bubbleBorder,
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
                        if (isAiMessage)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 11,
                                    color: isMine
                                        ? Colors.white
                                        : const Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMine
                                        ? 'Balasan AI Otomatis'
                                        : 'LiveTix AI Assistant ✨',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isMine
                                          ? Colors.white
                                          : const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (!isMine)
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
                        // Render Gambar Lampiran jika ada
                        if (msg.imageBase64 != null && msg.imageBase64!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(msg.imageBase64!),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          )
                        else if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                msg.imageUrl!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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

          // Admin AI Copilot Actions Bar (khusus Admin Inbox)
          if (widget.isAdminInbox && thread != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isLoadingAiSummary
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6366F1),
                              ),
                            )
                          : const Icon(Icons.summarize_outlined, size: 16),
                      label: Text(
                        'Ringkas Isu AI',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _isLoadingAiSummary
                          ? null
                          : () => _showAiSummaryDialog(thread, isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isLoadingAiDraft
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        'Draf Balasan AI',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _isLoadingAiDraft
                          ? null
                          : () => _generateAdminDraft(thread),
                    ),
                  ),
                ],
              ),
            ),

          // Preview Gambar yang dipilih (sebelum dikirim)
          if (_attachedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _attachedImageBytes!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 4),
                            Text(
                              'AI Vision Siap Menganalisis',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _attachedImageName ?? 'Foto terlampir',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    onPressed: () {
                      setState(() {
                        _attachedImageBytes = null;
                        _attachedImageName = null;
                      });
                    },
                    tooltip: 'Hapus lampiran',
                  ),
                ],
              ),
            ),

          // Input Bar (dilindungi SafeArea agar tidak tertutup navigation button 3-tombol sistem)
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, 10, 14, extraBottomSpace),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: widget.isAdminInbox
                          ? const Color(0xFF4F46E5)
                          : _csPink,
                      size: 24,
                    ),
                    onPressed: _showImagePickerSheet,
                    tooltip: 'Lampirkan Gambar (Analisis AI)',
                  ),
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
                            : 'Tulis pesan atau lampirkan foto...',
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
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
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
          ),
        ],
      ),
    );
  }
}
