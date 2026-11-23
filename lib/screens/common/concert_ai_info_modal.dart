import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/app_colors.dart';
import '../../models/concert_model.dart';
import '../../services/ai_backend_service.dart';
import '../concert/concert_detail_screen.dart';

class _ChatMessage {
  final bool isUser;
  final String text;
  final ConcertModel? concert;
  final List<ConcertModel> matchedConcerts;
  final bool isAmbiguous;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.concert,
    this.matchedConcerts = const [],
    this.isAmbiguous = false,
  });
}

/// Modal Interaktif Asisten Info Konser AI (Fitur 1)
/// Terhubung langsung ke database via AI Backend Service
class ConcertAiInfoModal extends StatefulWidget {
  final String? initialQuery;

  const ConcertAiInfoModal({super.key, this.initialQuery});

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConcertAiInfoModal(initialQuery: initialQuery),
    );
  }

  @override
  State<ConcertAiInfoModal> createState() => _ConcertAiInfoModalState();
}

class _ConcertAiInfoModalState extends State<ConcertAiInfoModal> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiBackendService _aiService = AiBackendService();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    'Jelaskan mengenai konser HS',
    'Berapa harga tiket Hindia 2027?',
    'Ada konser apa saja di Malang?',
  ];

  @override
  void initState() {
    super.initState();
    // Pesan sambutan awal
    _messages.add(
      const _ChatMessage(
        isUser: false,
        text:
            'Halo! Saya **LiveTix AI Assistant** yang terhubung langsung ke database konser kami.\n\nAnda bisa menanyakan detail konser, jadwal, lokasi venue, hingga rincian harga kategori tiket resmi. Ada konser yang ingin Anda ketahui?',
      ),
    );

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendQuery(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendQuery(String queryText) async {
    final clean = queryText.trim();
    if (clean.isEmpty || _isLoading) return;

    _queryController.clear();
    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: clean));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _aiService.askConcertInfo(clean);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _messages.add(
        _ChatMessage(
          isUser: false,
          text: response.message,
          concert: response.concert,
          matchedConcerts: response.matchedConcerts,
          isAmbiguous: response.ambiguous,
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // Menghindari tertutup navigation button 3-tombol pada Android
    final double extraBottomSpace = bottomInset > 0
        ? 14.0
        : (systemBottomPadding > 0 ? (systemBottomPadding + 10.0) : 18.0);

    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: screenHeight * 0.85,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asisten Info Konser LiveTix',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Terhubung ke Database Konser',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Quick Suggestion Chips (hanya jika pesan belum banyak)
          if (_messages.length <= 2)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPrompts.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          p,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF312E81).withValues(alpha: 0.5)
                            : const Color(0xFFEEF2FF),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF4338CA)
                              : const Color(0xFFC7D2FE),
                        ),
                        onPressed: _isLoading ? null : () => _sendQuery(p),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Chat Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                return _buildMessageBubble(
                  context,
                  msg,
                  isDark: isDark,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI sedang memeriksa database konser...',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Query Input Box (terlindungi dari tombol navigasi 3-tombol sistem)
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, extraBottomSpace),
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _queryController,
                      enabled: !_isLoading,
                      onSubmitted: _sendQuery,
                      style: TextStyle(fontSize: 13.5, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan konser (contoh: "Jelaskan konser HS")...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _isLoading
                        ? null
                        : () => _sendQuery(_queryController.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  Widget _buildMessageBubble(
    BuildContext context,
    _ChatMessage msg, {
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // AI Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 6),
                Text(
                  'LiveTix AI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: msg.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 13.5,
                  color: textPrimary,
                  height: 1.45,
                ),
                strong: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.45,
                ),
                em: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: textPrimary,
                  height: 1.45,
                ),
                listBullet: TextStyle(
                  fontSize: 13.5,
                  color: textPrimary,
                  height: 1.45,
                ),
                h1: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                h2: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                h3: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                blockquote: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                code: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                ),
              ),
            ),

            // Tampilkan Kartu Konser jika ada satu konser terpilih
            if (msg.concert != null) ...[
              const SizedBox(height: 14),
              _buildConcertCard(context, msg.concert!, isDark: isDark),
            ],

            // Jika ambigu (banyak pilihan konser), tampilkan tombol cepat untuk masing-masing konser
            if (msg.isAmbiguous && msg.matchedConcerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.matchedConcerts.map((c) {
                  return ActionChip(
                    avatar: const Icon(Icons.music_note, size: 14),
                    label: Text(
                      c.title,
                      style: TextStyle(fontSize: 12, color: textPrimary),
                    ),
                    onPressed: () => _sendQuery('Jelaskan detail konser ${c.title}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConcertCard(BuildContext context, ConcertModel concert, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  concert.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                concert.formattedPrice,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            concert.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  concert.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.confirmation_number_outlined, size: 16),
              label: const Text('Buka Detail & Pesan Tiket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ConcertDetailScreen(concert: concert),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
