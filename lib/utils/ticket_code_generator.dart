import 'dart:math';

/// Utility untuk pembuatan kode tiket aman dan resolusi alokasi Gate penonton.
class TicketCodeGenerator {
  TicketCodeGenerator._();

  /// Menghasilkan kode tiket panjang dan aman berformat:
  /// `LTX_NIK_username_tanggalbeli_kodeunik`
  ///
  /// Mencegah brute force atau tebak-tebakan kode tiket di pintu gerbang masuk.
  static String generateSecureTicketCode({
    required String? nik,
    required String? customerName,
    required DateTime? purchaseDate,
    required String orderId,
  }) {
    // 1. NIK (16 digit)
    final rawNik = (nik ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final cleanDigits = orderId.replaceAll(RegExp(r'[^0-9]'), '');
    final effectiveNik = rawNik.length >= 10
        ? (rawNik.length >= 16
            ? rawNik.substring(0, 16)
            : rawNik.padRight(16, '0'))
        : '3507${('${cleanDigits}123456789012').substring(0, 12)}';

    // 2. Username / Sanitized Name (huruf & angka kecil, tanpa spasi/simbol)
    String cleanName = (customerName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanName.isEmpty) cleanName = 'user';
    if (cleanName.length > 16) cleanName = cleanName.substring(0, 16);

    // 3. Tanggal Beli (YYYYMMDD)
    final date = purchaseDate ?? DateTime.now();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final dateStr = '$y$m$d';

    // 4. Kode Unik (6 karakter alfanumerik uppercase acak / kombinasi orderId)
    final cleanOrder =
        orderId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    const randomChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final randSuffix = List.generate(
      4,
      (_) => randomChars[Random().nextInt(randomChars.length)],
    ).join();

    final uniqueCode = cleanOrder.length >= 3
        ? '${cleanOrder.substring(cleanOrder.length - 3)}$randSuffix'
        : '${(Random().nextInt(90) + 10)}$randSuffix';

    return 'LTX_${effectiveNik}_${cleanName}_${dateStr}_$uniqueCode';
  }

  /// Menentukan Pos Gate masuk yang tepat berdasarkan daftar gate yang ditambahkan Produser
  /// dan kategori/tier tiket yang dibeli.
  static String resolveGateForTier({
    required List<String> gates,
    required String tierName,
  }) {
    final validGates = gates
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    if (validGates.isEmpty) return 'Gate A';
    if (validGates.length == 1) return validGates.first;

    final cleanTier = tierName.toLowerCase();

    // Prioritas 1: Cocokkan kata kunci kategori dengan nama Gate yang ditambahkan Produser
    for (final g in validGates) {
      final cleanG = g.toLowerCase();
      if ((cleanTier.contains('vip') || cleanTier.contains('vvip')) &&
          (cleanG.contains('vip') ||
              cleanG.contains('utama') ||
              cleanG.contains('vvip'))) {
        return g;
      }
      if ((cleanTier.contains('festival') || cleanTier.contains('fest')) &&
          (cleanG.contains('festival') || cleanG.contains('fest'))) {
        return g;
      }
      if (cleanTier.contains('tribun') && cleanG.contains('tribun')) {
        return g;
      }
      if ((cleanTier.contains('reguler') || cleanTier.contains('regular')) &&
          (cleanG.contains('reguler') || cleanG.contains('regular'))) {
        return g;
      }
      if (cleanTier.contains('early') && cleanG.contains('early')) {
        return g;
      }
    }

    // Prioritas 2: Jika tidak ada kecocokan eksplisit, gunakan Gate pertama produser
    return validGates.first;
  }
}
