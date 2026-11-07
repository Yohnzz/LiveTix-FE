import 'package:flutter/foundation.dart';
import '../models/gate_crew_models.dart';
import 'data_service.dart';
import 'supabase_service.dart';

class AddGateCrewBatchResult {
  final bool isSuccess;
  final String message;
  final List<GateCrewMemberModel> addedMembers;
  final List<String> duplicateEmails;
  final List<String> invalidEmails;

  const AddGateCrewBatchResult({
    required this.isSuccess,
    required this.message,
    this.addedMembers = const [],
    this.duplicateEmails = const [],
    this.invalidEmails = const [],
  });
}

class GateCrewService {
  static final GateCrewService _instance = GateCrewService._internal();
  factory GateCrewService() => _instance;
  GateCrewService._internal() {
    _seedInitialCrew();
  }

  static const String defaultSystemCrewPassword = 'crewgate123';

  static const String csvTemplateContent =
      'email,nama_opsional,no_hp_opsional\n'
      'crew1.event@livetix.com,Petugas Gate 1,081234567801\n'
      'crew2.event@livetix.com,Petugas Gate 2,081234567802\n';

  final ValueNotifier<List<GateCrewMemberModel>> teamCrewNotifier =
      ValueNotifier<List<GateCrewMemberModel>>([]);

  void _seedInitialCrew() {
    if (SupabaseService.isInitialized) {
      teamCrewNotifier.value = [];
      return;
    }
    teamCrewNotifier.value = [
      GateCrewMemberModel(
        id: 'd0000000-0000-0000-0000-000000000004',
        name: 'Budi Petugas Gate A',
        email: 'gatecrew@livetix.com',
        phone: '081377889900',
        approvalStatus: 'approved',
        defaultPassword: defaultSystemCrewPassword,
        activeAssignment: GateCrewAssignmentModel(
          id: 'cgc-001',
          concertId: 'featured-1',
          concertTitle: 'Soundwave Fest 2026',
          venue: 'Stadion Gajayana, Malang',
          gateName: 'Gate A',
          assignedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ),
      const GateCrewMemberModel(
        id: 'd0000000-0000-0000-0000-000000000005',
        name: 'Siti Petugas Cadangan',
        email: 'gatecrew2@livetix.com',
        phone: '081388990011',
        approvalStatus: 'approved',
        defaultPassword: defaultSystemCrewPassword,
        activeAssignment: null,
      ),
      const GateCrewMemberModel(
        id: 'crew-003',
        name: 'Andi Ramadhan',
        email: 'andi.gate@livetix.com',
        phone: '081399001122',
        approvalStatus: 'approved',
        defaultPassword: defaultSystemCrewPassword,
        activeAssignment: null,
      ),
      const GateCrewMemberModel(
        id: 'crew-004',
        name: 'Deni Saputra',
        email: 'deni.gate@livetix.com',
        phone: '081311223344',
        approvalStatus: 'approved',
        defaultPassword: defaultSystemCrewPassword,
        activeAssignment: null,
      ),
    ];
  }

  /// Mengekstrak daftar email dari isi file CSV / Excel (.csv / .tsv / teks tabel)
  static List<String> parseEmailsFromCsvOrExcelContent(String rawContent) {
    final lines = rawContent
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<String> extracted = [];
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      // Lewati baris header
      if (i == 0 &&
          (lower.startsWith('email') ||
              lower.contains('nama_opsional') ||
              lower.contains('daftar email'))) {
        continue;
      }

      // Cari token email pada kolom pertama atau di dalam baris
      final matches = emailRegex.allMatches(line);
      for (final match in matches) {
        final candidate = match.group(0)?.trim().toLowerCase() ?? '';
        if (candidate.isNotEmpty) {
          extracted.add(candidate);
        }
      }
    }
    return extracted;
  }

  /// Memuat daftar Gate Crew & penugasan murni dari Supabase jika terhubung
  Future<void> loadTeam() async {
    if (!SupabaseService.isInitialized) return;

    try {
      final crewProfiles = await SupabaseService.client
          .from('profiles')
          .select('id, name, full_name, email, phone, role, approval_status')
          .ilike('role', 'gatecrew');

      final assignments = await SupabaseService.client
          .from('concert_gate_crews')
          .select('*, concerts(title, venue)');

      final Map<String, GateCrewAssignmentModel> assignmentMap = {};
      for (final a in assignments) {
        final crewId = a['crew_id'] as String?;
        if (crewId != null) {
          final rawConcert = a['concerts'];
          final concertTitle = rawConcert is Map
              ? (rawConcert['title'] as String? ?? 'Konser LiveTix')
              : 'Konser LiveTix';
          final venue = rawConcert is Map
              ? (rawConcert['venue'] as String? ?? 'Venue Konser')
              : 'Venue Konser';

          assignmentMap[crewId] = GateCrewAssignmentModel(
            id: a['id'] as String? ?? '',
            concertId: a['concert_id'] as String? ?? '',
            concertTitle: concertTitle,
            venue: venue,
            gateName: a['gate_name'] as String? ?? 'Gate A',
            assignedAt:
                DateTime.tryParse(a['assigned_at'] as String? ?? '') ??
                    DateTime.now(),
          );
        }
      }

      final List<GateCrewMemberModel> loaded = [];
      for (final row in crewProfiles) {
        final id = row['id'] as String;
        final email = (row['email'] ?? '') as String;
        final rawName = (row['name'] ?? row['full_name'] ?? '') as String;
        final fallbackName = email.contains('@')
            ? 'Gate Crew (${email.split('@').first})'
            : 'Petugas Gate';
        loaded.add(GateCrewMemberModel(
          id: id,
          name: rawName.trim().isNotEmpty ? rawName.trim() : fallbackName,
          email: email,
          phone: (row['phone'] ?? '') as String,
          approvalStatus: (row['approval_status'] as String?) ?? 'approved',
          defaultPassword: defaultSystemCrewPassword,
          activeAssignment: assignmentMap[id],
        ));
      }

      teamCrewNotifier.value = loaded;
    } catch (e) {
      debugPrint('Error loadTeam GateCrewService: $e');
    }
  }

  /// Produser mengajukan penambahan 1 atau banyak akun Gate Crew (manual maupun CSV/Excel).
  /// Password default diatur sistem (`crewgate123`) dan wajib menunggu persetujuan Admin.
  /// Semua email divalidasi harus unik (tidak boleh duplikat di input maupun di sistem).
  Future<AddGateCrewBatchResult> requestAddGateCrewsByProducer({
    required List<String> rawEmails,
  }) async {
    final cleaned = rawEmails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      return const AddGateCrewBatchResult(
        isSuccess: false,
        message: 'Masukkan minimal 1 alamat email Gate Crew.',
      );
    }

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    final List<String> invalidEmails = [];
    for (final email in cleaned) {
      if (!emailRegex.hasMatch(email)) {
        invalidEmails.add(email);
      }
    }
    if (invalidEmails.isNotEmpty) {
      return AddGateCrewBatchResult(
        isSuccess: false,
        message:
            'Format email tidak valid: ${invalidEmails.join(', ')}. Periksa kembali input Anda.',
        invalidEmails: invalidEmails,
      );
    }

    // Cek duplikasi di dalam input itu sendiri
    final Set<String> seenInBatch = {};
    final Set<String> duplicates = {};
    for (final email in cleaned) {
      if (!seenInBatch.add(email)) {
        duplicates.add(email);
      }
    }

    // Cek duplikasi terhadap akun Gate Crew yang sudah terdaftar
    final existingEmails = teamCrewNotifier.value
        .map((c) => c.email.trim().toLowerCase())
        .toSet();
    for (final email in cleaned) {
      if (existingEmails.contains(email)) {
        duplicates.add(email);
      }
    }

    if (duplicates.isNotEmpty) {
      return AddGateCrewBatchResult(
        isSuccess: false,
        message:
            'Email harus bersifat unik dan tidak boleh sama. Ditemukan email duplikat/sudah terdaftar: ${duplicates.join(', ')}',
        duplicateEmails: duplicates.toList(),
      );
    }

    final List<GateCrewMemberModel> createdList = [];
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final baseTs = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < cleaned.length; i++) {
      final email = cleaned[i];
      final prefix = email.split('@').first;
      final readableName =
          'Crew ${prefix.isNotEmpty ? '${prefix[0].toUpperCase()}${prefix.substring(1)}' : 'Gate'}';
      final newId = 'crew-$baseTs-$i';

      final member = GateCrewMemberModel(
        id: newId,
        name: readableName,
        email: email,
        phone: '-',
        approvalStatus: 'pending',
        defaultPassword: defaultSystemCrewPassword,
        activeAssignment: null,
      );

      createdList.add(member);
      current.insert(0, member);

      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': newId,
            'name': readableName,
            'full_name': readableName,
            'email': email,
            'phone': '-',
            'role': 'Gatecrew',
            'approval_status': 'pending',
          });
        } catch (e) {
          debugPrint('Error requestAddGateCrewsByProducer Supabase: $e');
        }
      }
    }

    teamCrewNotifier.value = current;

    return AddGateCrewBatchResult(
      isSuccess: true,
      message:
          '${createdList.length} akun Gate Crew berhasil diajukan (Password default: $defaultSystemCrewPassword) dan menunggu persetujuan Admin.',
      addedMembers: createdList,
    );
  }

  /// Admin menyetujui akun Gate Crew yang diajukan Produser
  Future<GateCrewMemberModel?> approveGateCrewByAdmin(String crewId) async {
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx == -1) return null;

    final updated = current[idx].copyWith(approvalStatus: 'approved');
    current[idx] = updated;
    teamCrewNotifier.value = current;

    // Daftarkan kredensial login dengan password default sistem `crewgate123`
    DataService().registerGateCrewAccountInMemory(
      id: updated.id,
      name: updated.name,
      email: updated.email,
      phone: updated.phone,
      password: updated.defaultPassword,
    );

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').update({
          'approval_status': 'approved',
        }).eq('id', crewId);
      } catch (e) {
        debugPrint('Error approveGateCrewByAdmin Supabase: $e');
      }
    }
    return updated;
  }

  /// Admin menolak pengajuan akun Gate Crew
  Future<void> rejectGateCrewByAdmin(String crewId) async {
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    current.removeWhere((c) => c.id == crewId);
    teamCrewNotifier.value = current;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').delete().eq('id', crewId);
      } catch (e) {
        debugPrint('Error rejectGateCrewByAdmin Supabase: $e');
      }
    }
  }

  /// Tambah Gate Crew baru langsung oleh Admin (otomatis disetujui)
  Future<GateCrewMemberModel> createGateCrewByAdmin({
    required String name,
    required String email,
    String phone = '',
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final newId = 'crew-${DateTime.now().millisecondsSinceEpoch}';

    final newMember = GateCrewMemberModel(
      id: newId,
      name: name.trim(),
      email: trimmedEmail,
      phone: phone.trim(),
      approvalStatus: 'approved',
      defaultPassword: defaultSystemCrewPassword,
      activeAssignment: null,
    );

    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    current.insert(0, newMember);
    teamCrewNotifier.value = current;

    DataService().registerGateCrewAccountInMemory(
      id: newMember.id,
      name: newMember.name,
      email: newMember.email,
      phone: newMember.phone,
      password: defaultSystemCrewPassword,
    );

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': newId,
          'name': name.trim(),
          'full_name': name.trim(),
          'email': trimmedEmail,
          'phone': phone.trim(),
          'role': 'Gatecrew',
          'approval_status': 'approved',
        });
      } catch (e) {
        debugPrint('Error createGateCrewByAdmin Supabase: $e');
      }
    }

    return newMember;
  }

  /// Produser meng-invite / menugaskan Gate Crew ke konser tertentu
  Future<void> inviteCrewToConcert({
    required String crewId,
    required String concertId,
    required String concertTitle,
    required String venue,
    String gateName = 'Gate A',
  }) async {
    final assignment = GateCrewAssignmentModel(
      id: 'cgc-${DateTime.now().millisecondsSinceEpoch}',
      concertId: concertId,
      concertTitle: concertTitle,
      venue: venue,
      gateName: gateName,
      assignedAt: DateTime.now(),
    );

    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx != -1) {
      current[idx] = current[idx].copyWith(activeAssignment: assignment);
      teamCrewNotifier.value = current;
    }

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('concert_gate_crews').upsert({
          'id': assignment.id,
          'concert_id': concertId,
          'crew_id': crewId,
          'gate_name': gateName,
          'assigned_at': assignment.assignedAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error inviteCrewToConcert Supabase: $e');
      }
    }
  }

  /// Produser membatalkan penugasan Gate Crew dari konser
  Future<void> removeCrewFromConcert({
    required String crewId,
    required String concertId,
  }) async {
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx != -1) {
      current[idx] = current[idx].copyWith(clearAssignment: true);
      teamCrewNotifier.value = current;
    }

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client
            .from('concert_gate_crews')
            .delete()
            .match({'concert_id': concertId, 'crew_id': crewId});
      } catch (e) {
        debugPrint('Error removeCrewFromConcert Supabase: $e');
      }
    }
  }

  /// Cek apakah user Gate Crew yang sedang login memiliki tugas aktif
  GateCrewAssignmentModel? getAssignmentForUser(String userId,
      {String? userEmail}) {
    final lowerEmail = userEmail?.trim().toLowerCase();
    for (final member in teamCrewNotifier.value) {
      if (!member.isApproved) continue;
      if (member.id == userId ||
          (lowerEmail != null &&
              member.email.toLowerCase() == lowerEmail &&
              lowerEmail.isNotEmpty)) {
        return member.activeAssignment;
      }
    }
    return null;
  }
}
