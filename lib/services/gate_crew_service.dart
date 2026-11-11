import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/gate_crew_models.dart';
import '../models/ticket_order_model.dart';
import '../utils/local_storage.dart';
import 'data_service.dart';
import 'promoter_data_service.dart';
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
  static const String _localCacheKey = 'livetix_gate_crews_cache_v2';

  static const String csvTemplateContent =
      'email,nama_opsional,no_hp_opsional\n'
      'crew1.event@livetix.com,Petugas Gate 1,081234567801\n'
      'crew2.event@livetix.com,Petugas Gate 2,081234567802\n';

  final ValueNotifier<List<GateCrewMemberModel>> teamCrewNotifier =
      ValueNotifier<List<GateCrewMemberModel>>([]);

  static String _generateValidUuid(int seed) {
    final hex = seed.abs().toRadixString(16).padLeft(12, '0');
    final tail = hex.length > 12 ? hex.substring(hex.length - 12) : hex;
    final mid = ((seed ~/ 1000) % 0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'd0000000-$mid-4000-8000-$tail';
  }

  void _persistToLocalCache(List<GateCrewMemberModel> list) {
    try {
      LocalStorage.setItem(
        _localCacheKey,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  List<GateCrewMemberModel> _readFromLocalCache() {
    try {
      final raw = LocalStorage.getItem(_localCacheKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(GateCrewMemberModel.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  void _seedInitialCrew() {
    final cached = _readFromLocalCache();
    if (cached.isNotEmpty) {
      teamCrewNotifier.value = cached;
    }
    if (SupabaseService.isInitialized) {
      loadTeam();
      return;
    }
    // Fallback minimal untuk lingkungan unit test & offline saat belum terkoneksi Supabase
    if (teamCrewNotifier.value.isEmpty) {
      teamCrewNotifier.value = [
        GateCrewMemberModel(
          id: '400000',
          name: 'Petugas Gate A',
          email: 'gatecrew@livetix.com',
          phone: '081377889900',
          approvalStatus: 'approved',
          defaultPassword: defaultSystemCrewPassword,
          activeAssignment: GateCrewAssignmentModel(
            id: 'cgc-001',
            concertId: 'c1',
            concertTitle: 'Konser LiveTix',
            venue: 'Stadion Utama',
            gateName: 'Gate A',
            assignedAt: DateTime.now(),
          ),
        ),
      ];
    }
  }

  /// Mengekstrak daftar email dari isi file CSV / Excel (.csv / .tsv / teks tabel)
  static List<String> parseEmailsFromCsvOrExcelContent(String rawContent) {
    final lines = rawContent
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<String> extracted = [];
    final emailRegex =
        RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');

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
          .select()
          .ilike('role', 'gatecrew');

      List<dynamic> assignments = const [];
      try {
        assignments = await SupabaseService.client
            .from('concert_gate_crews')
            .select('*');
      } catch (_) {}

      final Map<String, GateCrewAssignmentModel> assignmentMap = {};
      final Map<String, GateCrewAssignmentModel> assignmentByEmail = {};
      final Map<String, Map<String, dynamic>> rawAssignmentRowsByEmail = {};
      final Map<String, Map<String, dynamic>> rawAssignmentRowsByCrewId = {};
      for (final a in assignments) {
        final crewId = (a['crew_id'] ?? a['crew_user_id'])?.toString();
        final crewEmail =
            (a['crew_email'] ?? '')?.toString().trim().toLowerCase();
        if ((crewId != null && crewId.isNotEmpty) ||
            (crewEmail != null && crewEmail.isNotEmpty)) {
          final concertIdStr = a['concert_id']?.toString() ?? '';
          final rawConcert = a['concerts'];
          var concertTitle = rawConcert is Map
              ? (rawConcert['title'] as String? ??
                  (a['concert_title'] as String? ?? ''))
              : (a['concert_title'] as String? ?? '');
          var venue = rawConcert is Map
              ? (rawConcert['venue'] as String? ??
                  (a['venue'] as String? ?? ''))
              : (a['venue'] as String? ?? '');

          if (concertTitle.isEmpty || venue.isEmpty) {
            final known = await DataService().getConcertById(concertIdStr);
            if (known != null) {
              if (concertTitle.isEmpty) concertTitle = known.title;
              if (venue.isEmpty) venue = known.venue;
            }
          }

          final model = GateCrewAssignmentModel(
            id: a['id']?.toString() ?? '',
            concertId: concertIdStr,
            concertTitle:
                concertTitle.isNotEmpty ? concertTitle : 'Konser LiveTix',
            venue: venue.isNotEmpty ? venue : 'Venue Konser',
            gateName:
                (a['gate_name'] ?? a['gate_section'])?.toString() ?? 'Gate A',
            assignedAt: DateTime.tryParse(
                    (a['assigned_at'] ?? a['created_at'])?.toString() ?? '') ??
                DateTime.now(),
          );

          if (crewId != null && crewId.isNotEmpty) {
            assignmentMap[crewId] = model;
            rawAssignmentRowsByCrewId[crewId] = Map<String, dynamic>.from(a);
          }
          if (crewEmail != null && crewEmail.isNotEmpty) {
            assignmentByEmail[crewEmail] = model;
            rawAssignmentRowsByEmail[crewEmail] = Map<String, dynamic>.from(a);
          }
        }
      }

      final cachedByEmail = <String, GateCrewMemberModel>{
        for (final c in _readFromLocalCache()) c.email.toLowerCase(): c,
        for (final c in teamCrewNotifier.value) c.email.toLowerCase(): c,
      };

      final List<GateCrewMemberModel> loaded = [];
      final Set<String> seenEmails = {};
      final Set<String> seenIds = {};

      for (final row in crewProfiles) {
        final id = (row['id'] ?? '').toString();
        final email = (row['email'] ?? '').toString().trim().toLowerCase();
        if (email.isNotEmpty) seenEmails.add(email);
        if (id.isNotEmpty) seenIds.add(id);
        final cached = cachedByEmail[email];

        final rawName =
            (row['name'] ?? row['full_name'] ?? '').toString().trim();
        final fallbackName = email.contains('@')
            ? 'Gate Crew (${email.split('@').first})'
            : 'Petugas Gate';

        final rawProducerId = (row['producer_id'] ??
                cached?.producerId ??
                'b0000000-0000-0000-0000-000000000002')
            .toString();
        final rawProducerName = (row['producer_name'] ??
                cached?.producerName ??
                'Soundwave Entertainment')
            .toString();
        final rawProducerEmail = (row['producer_email'] ??
                cached?.producerEmail ??
                'produser@livetix.com')
            .toString();

        loaded.add(GateCrewMemberModel(
          id: id,
          name: rawName.isNotEmpty ? rawName : fallbackName,
          email: email,
          phone: (row['phone'] ?? cached?.phone ?? '-').toString(),
          approvalStatus:
              (row['approval_status'] ?? cached?.approvalStatus ?? 'approved')
                  .toString(),
          defaultPassword: defaultSystemCrewPassword,
          producerId: rawProducerId,
          producerName: rawProducerName,
          producerEmail: rawProducerEmail,
          activeAssignment: assignmentMap[id] ??
              assignmentByEmail[email] ??
              cached?.activeAssignment,
        ));
      }

      // Pastikan seluruh crew yang tercatat pada concert_gate_crews tetap termuat meskipun belum ada di tabel profiles
      for (final a in assignments) {
        final crewId = (a['crew_id'] ?? a['crew_user_id'] ?? '').toString();
        final crewEmail =
            (a['crew_email'] ?? '').toString().trim().toLowerCase();
        if (crewEmail.isEmpty && crewId.isEmpty) continue;
        if ((crewEmail.isNotEmpty && seenEmails.contains(crewEmail)) ||
            (crewId.isNotEmpty && seenIds.contains(crewId))) {
          continue;
        }
        if (crewEmail.isNotEmpty) seenEmails.add(crewEmail);
        if (crewId.isNotEmpty) seenIds.add(crewId);

        final cached = cachedByEmail[crewEmail];
        final rawName = (a['crew_name'] ?? cached?.name ?? '').toString().trim();
        final fallbackName = crewEmail.contains('@')
            ? 'Gate Crew (${crewEmail.split('@').first})'
            : 'Petugas Gate';

        loaded.add(GateCrewMemberModel(
          id: crewId.isNotEmpty ? crewId : (cached?.id ?? crewEmail),
          name: rawName.isNotEmpty ? rawName : fallbackName,
          email: crewEmail.isNotEmpty ? crewEmail : (cached?.email ?? ''),
          phone: (a['phone'] ?? cached?.phone ?? '-').toString(),
          approvalStatus: cached?.approvalStatus ?? 'approved',
          defaultPassword: defaultSystemCrewPassword,
          producerId: cached?.producerId ?? 'b0000000-0000-0000-0000-000000000002',
          producerName: cached?.producerName ?? 'Soundwave Entertainment',
          producerEmail: cached?.producerEmail ?? 'produser@livetix.com',
          activeAssignment: assignmentByEmail[crewEmail] ??
              assignmentMap[crewId] ??
              cached?.activeAssignment,
        ));
      }

      // Pertahankan item di cache lokal yang belum tersinkron karena RLS / constraint
      for (final entry in cachedByEmail.entries) {
        if (!seenEmails.contains(entry.key)) {
          loaded.insert(0, entry.value);
        }
      }

      teamCrewNotifier.value = loaded;
      _persistToLocalCache(loaded);
    } catch (e) {
      debugPrint('Error loadTeam GateCrewService: $e');
    }
  }

  /// Produser mengajukan penambahan 1 atau banyak akun Gate Crew (manual maupun CSV/Excel).
  /// Password default diatur sistem (`crewgate123`) dan wajib menunggu persetujuan Admin.
  /// Semua email divalidasi harus unik (tidak boleh duplikat di input maupun di sistem).
  Future<AddGateCrewBatchResult> requestAddGateCrewsByProducer({
    required List<String> rawEmails,
    String? producerId,
    String? producerName,
    String? producerEmail,
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

    final currentUser = DataService().currentUser;
    final resolvedProducerId = (producerId?.trim().isNotEmpty == true)
        ? producerId!.trim()
        : (currentUser?.id.trim().isNotEmpty == true
            ? currentUser!.id.trim()
            : 'b0000000-0000-0000-0000-000000000002');
    final resolvedProducerName = (producerName?.trim().isNotEmpty == true)
        ? producerName!.trim()
        : PromoterDataService().promoterName;
    final resolvedProducerEmail = (producerEmail?.trim().isNotEmpty == true)
        ? producerEmail!.trim()
        : (currentUser?.email.trim().isNotEmpty == true
            ? currentUser!.email.trim()
            : 'produser@livetix.com');

    final List<GateCrewMemberModel> createdList = [];
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final baseTs = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < cleaned.length; i++) {
      final email = cleaned[i];
      final prefix = email.split('@').first;
      final readableName =
          'Crew ${prefix.isNotEmpty ? '${prefix[0].toUpperCase()}${prefix.substring(1)}' : 'Gate'}';
      String newId = _generateValidUuid(baseTs + i);

      if (SupabaseService.isInitialized) {
        bool savedViaRpc = false;
        try {
          final rpcId = await SupabaseService.client.rpc(
            'upsert_gate_crew_account',
            params: {
              'p_email': email,
              'p_name': readableName,
              'p_phone': '-',
              'p_approval_status': 'pending',
              'p_password': defaultSystemCrewPassword,
            },
          );
          if (rpcId != null && rpcId.toString().isNotEmpty) {
            newId = rpcId.toString();
            savedViaRpc = true;
          }
        } catch (rpcErr) {
          debugPrint('RPC upsert_gate_crew_account fallback: $rpcErr');
        }

        // Pastikan kolom producer_id, producer_name, producer_email & profil tersimpan di tabel profiles
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': newId,
            'username':
                '${prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}_${(baseTs + i) % 100000}',
            'name': readableName,
            'full_name': readableName,
            'email': email,
            'phone': '-',
            'role': 'Gatecrew',
            'approval_status': 'pending',
            'verification_status': 'pending',
            'producer_id': resolvedProducerId,
            'producer_name': resolvedProducerName,
            'producer_email': resolvedProducerEmail,
          });
        } catch (_) {
          if (!savedViaRpc) {
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
          } else {
            try {
              await SupabaseService.client.from('profiles').update({
                'producer_id': resolvedProducerId,
                'producer_name': resolvedProducerName,
                'producer_email': resolvedProducerEmail,
              }).eq('id', newId);
            } catch (_) {}
          }
        }
      }

      final member = GateCrewMemberModel(
        id: newId,
        name: readableName,
        email: email,
        phone: '-',
        approvalStatus: 'pending',
        defaultPassword: defaultSystemCrewPassword,
        producerId: resolvedProducerId,
        producerName: resolvedProducerName,
        producerEmail: resolvedProducerEmail,
        activeAssignment: null,
      );

      createdList.add(member);
      current.insert(0, member);
    }

    teamCrewNotifier.value = current;
    _persistToLocalCache(current);

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
    _persistToLocalCache(current);

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
        await SupabaseService.client.rpc(
          'upsert_gate_crew_account',
          params: {
            'p_email': updated.email,
            'p_name': updated.name,
            'p_phone': updated.phone,
            'p_approval_status': 'approved',
            'p_password': updated.defaultPassword,
          },
        );
      } catch (_) {}
      try {
        await SupabaseService.client.from('profiles').update({
          'approval_status': 'approved',
          'verification_status': 'approved',
          'is_verified': true,
        }).or('id.eq.$crewId,email.eq.${updated.email}');
      } catch (e) {
        debugPrint('Error approveGateCrewByAdmin Supabase: $e');
      }
    }
    return updated;
  }

  /// Admin menolak pengajuan akun Gate Crew (status diubah menjadi 'rejected' agar tampil di filter Ditolak)
  Future<GateCrewMemberModel?> rejectGateCrewByAdmin(String crewId) async {
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx == -1) return null;

    final updated = current[idx].copyWith(
      approvalStatus: 'rejected',
      clearAssignment: true,
    );
    current[idx] = updated;
    teamCrewNotifier.value = current;
    _persistToLocalCache(current);

    if (SupabaseService.isInitialized) {
      try {
        if (updated.email.isNotEmpty) {
          await SupabaseService.client
              .from('profiles')
              .update({
                'approval_status': 'rejected',
                'verification_status': 'rejected',
              })
              .or('id.eq.$crewId,email.eq.${updated.email}');
        } else {
          await SupabaseService.client.from('profiles').update({
            'approval_status': 'rejected',
            'verification_status': 'rejected',
          }).eq('id', crewId);
        }
      } catch (e) {
        debugPrint('Error rejectGateCrewByAdmin Supabase: $e');
      }
    }
    return updated;
  }

  /// Tambah Gate Crew baru langsung oleh Admin (otomatis disetujui)
  Future<GateCrewMemberModel> createGateCrewByAdmin({
    required String name,
    required String email,
    String phone = '',
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final seed = DateTime.now().millisecondsSinceEpoch;
    String newId = _generateValidUuid(seed);

    if (SupabaseService.isInitialized) {
      try {
        final rpcId = await SupabaseService.client.rpc(
          'upsert_gate_crew_account',
          params: {
            'p_email': trimmedEmail,
            'p_name': name.trim(),
            'p_phone': phone.trim(),
            'p_approval_status': 'approved',
            'p_password': defaultSystemCrewPassword,
          },
        );
        if (rpcId != null && rpcId.toString().isNotEmpty) {
          newId = rpcId.toString();
        }
      } catch (_) {
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
    }

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
    _persistToLocalCache(current);

    DataService().registerGateCrewAccountInMemory(
      id: newMember.id,
      name: newMember.name,
      email: newMember.email,
      phone: newMember.phone,
      password: defaultSystemCrewPassword,
    );

    return newMember;
  }

  /// Produser meng-invite / menugaskan Gate Crew ke konser tertentu
  Future<void> inviteCrewToConcert({
    required String crewId,
    required String concertId,
    required String concertTitle,
    required String venue,
    String gateName = 'Gate A',
    String? crewEmail,
    String? crewName,
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
    final member = idx != -1 ? current[idx] : null;
    final resolvedEmail = (crewEmail?.trim().isNotEmpty == true)
        ? crewEmail!.trim().toLowerCase()
        : (member?.email.trim().toLowerCase() ?? '');
    final resolvedName = (crewName?.trim().isNotEmpty == true)
        ? crewName!.trim()
        : (member?.name ?? 'Petugas Gate');

    if (idx != -1) {
      current[idx] = current[idx].copyWith(activeAssignment: assignment);
      teamCrewNotifier.value = current;
      _persistToLocalCache(current);
    }

    if (SupabaseService.isInitialized) {
      await _upsertConcertGateCrewRow(
        concertId: concertId,
        concertTitle: concertTitle,
        venue: venue,
        crewId: crewId,
        crewEmail: resolvedEmail,
        crewName: resolvedName,
        gateName: gateName,
        assignedAt: assignment.assignedAt,
      );
    }
  }

  /// Helper aman untuk insert atau update penugasan Gate Crew tanpa bentrok constraint 23505 atau FK
  Future<void> _upsertConcertGateCrewRow({
    required String concertId,
    required String concertTitle,
    required String venue,
    required String crewId,
    required String crewEmail,
    required String crewName,
    String? phone,
    required String gateName,
    required DateTime assignedAt,
  }) async {
    final bool isUuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(crewId);
    final payload = <String, dynamic>{
      'concert_id': concertId,
      'concert_title': concertTitle,
      'venue': venue,
      'crew_id': crewId,
      if (isUuid) 'crew_user_id': crewId,
      if (crewEmail.isNotEmpty) 'crew_email': crewEmail,
      if (crewName.isNotEmpty) 'crew_name': crewName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'gate_name': gateName,
      'gate_section': gateName,
      'assigned_at': assignedAt.toIso8601String(),
    };

    try {
      dynamic existing;
      if (crewEmail.isNotEmpty) {
        existing = await SupabaseService.client
            .from('concert_gate_crews')
            .select('id')
            .eq('concert_id', concertId)
            .ilike('crew_email', crewEmail)
            .maybeSingle();
      }
      if (existing == null && isUuid) {
        existing = await SupabaseService.client
            .from('concert_gate_crews')
            .select('id')
            .eq('concert_id', concertId)
            .eq('crew_user_id', crewId)
            .maybeSingle();
      }
      if (existing != null && existing['id'] != null) {
        await SupabaseService.client
            .from('concert_gate_crews')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await SupabaseService.client.from('concert_gate_crews').insert(payload);
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('23505') || errStr.contains('23503')) {
        // Fallback: hapus/abaikan kolom FK crew_user_id atau update berdasarkan crew_email/crew_id
        final fallbackPayload = Map<String, dynamic>.from(payload)
          ..remove('crew_user_id');
        try {
          if (crewEmail.isNotEmpty) {
            final res = await SupabaseService.client
                .from('concert_gate_crews')
                .update(fallbackPayload)
                .eq('concert_id', concertId)
                .ilike('crew_email', crewEmail)
                .select();
            if (res.isEmpty) {
              await SupabaseService.client
                  .from('concert_gate_crews')
                  .insert(fallbackPayload);
            }
          } else {
            await SupabaseService.client
                .from('concert_gate_crews')
                .insert(fallbackPayload);
          }
        } catch (err2) {
          debugPrint('Error fallback upsert concert_gate_crews: $err2');
        }
      } else {
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
    final email = idx != -1 ? current[idx].email.trim().toLowerCase() : '';
    if (idx != -1) {
      current[idx] = current[idx].copyWith(clearAssignment: true);
      teamCrewNotifier.value = current;
      _persistToLocalCache(current);
    }

    if (SupabaseService.isInitialized) {
      try {
        var query = SupabaseService.client
            .from('concert_gate_crews')
            .delete()
            .eq('concert_id', concertId);
        if (email.isNotEmpty) {
          await query.or(
              'crew_id.eq.$crewId,crew_user_id.eq.$crewId,crew_email.ilike.$email');
        } else {
          await query.or('crew_id.eq.$crewId,crew_user_id.eq.$crewId');
        }
      } catch (e) {
        debugPrint('Error removeCrewFromConcert Supabase: $e');
      }
    }
  }

  /// Produser mengundang Gate Crew baru dan langsung menugaskannya ke pos gate tertentu
  Future<GateCrewMemberModel> inviteAndAssignCrewByProducer({
    required String concertId,
    required String concertTitle,
    required String email,
    required String name,
    required String phone,
    required String gateName,
  }) async {
    final baseTs = DateTime.now().millisecondsSinceEpoch;
    final newId = _generateValidUuid(baseTs);
    final resolvedName = name.trim().isNotEmpty ? name.trim() : 'Crew Gate';
    final resolvedEmail = email.trim().toLowerCase();
    final resolvedPhone = phone.trim().isNotEmpty ? phone.trim() : '-';

    final assignment = GateCrewAssignmentModel(
      id: 'cgc-$baseTs',
      concertId: concertId,
      concertTitle: concertTitle,
      venue: 'Stadion Utama',
      gateName: gateName,
      assignedAt: DateTime.now(),
    );

    final member = GateCrewMemberModel(
      id: newId,
      name: resolvedName,
      email: resolvedEmail,
      phone: resolvedPhone,
      approvalStatus: 'approved',
      defaultPassword: defaultSystemCrewPassword,
      activeAssignment: assignment,
    );

    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    current.insert(0, member);
    teamCrewNotifier.value = current;
    _persistToLocalCache(current);

    DataService().registerGateCrewAccountInMemory(
      id: newId,
      name: resolvedName,
      email: resolvedEmail,
      phone: resolvedPhone,
      password: defaultSystemCrewPassword,
    );

    if (SupabaseService.isInitialized) {
      // 1. Coba simpan ke profiles (terpisah agar error FK auth.users tidak menghalangi penyimpanan concert_gate_crews)
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': newId,
          'name': resolvedName,
          'full_name': resolvedName,
          'email': resolvedEmail,
          'phone': resolvedPhone,
          'role': 'Gatecrew',
          'approval_status': 'approved',
          'verification_status': 'approved',
        });
      } catch (e) {
        debugPrint('Warning upsert profiles for invited crew (ignored safely): $e');
      }

      // 2. Simpan penugasan ke concert_gate_crews
      await _upsertConcertGateCrewRow(
        concertId: concertId,
        concertTitle: concertTitle,
        venue: 'Stadion Utama',
        crewId: newId,
        crewEmail: resolvedEmail,
        crewName: resolvedName,
        phone: resolvedPhone,
        gateName: gateName,
        assignedAt: assignment.assignedAt,
      );
    }

    return member;
  }

  /// Produser mengubah pos gate penugasan kru tertentu
  Future<void> updateCrewGateAssignment({
    required String crewId,
    required String concertId,
    required String newGateName,
  }) async {
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final idx = current.indexWhere((c) => c.id == crewId);
    if (idx != -1 && current[idx].activeAssignment != null) {
      final updatedAssignment =
          current[idx].activeAssignment!.copyWith(gateName: newGateName);
      current[idx] = current[idx].copyWith(activeAssignment: updatedAssignment);
      teamCrewNotifier.value = current;
      _persistToLocalCache(current);

      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('concert_gate_crews').update({
            'gate_name': newGateName,
            'gate_section': newGateName,
          }).eq('concert_id', concertId).eq('crew_email', current[idx].email);
        } catch (_) {}
      }
    }
  }

  /// Membagi seluruh Gate Crew yang ditugaskan secara merata ke seluruh pos gate yang tersedia
  Future<void> autoDistributeCrewAcrossGates({
    required String concertId,
    required String concertTitle,
    required List<String> gates,
  }) async {
    if (gates.isEmpty) return;
    final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
    final assigned = current
        .where((c) =>
            c.activeAssignment != null &&
            (c.activeAssignment!.concertId == concertId ||
                c.activeAssignment!.concertTitle.toLowerCase() ==
                    concertTitle.toLowerCase()))
        .toList();

    for (var i = 0; i < assigned.length; i++) {
      final targetGate = gates[i % gates.length];
      final crew = assigned[i];
      final updatedAssignment =
          crew.activeAssignment!.copyWith(gateName: targetGate);
      final idx = current.indexWhere((c) => c.id == crew.id);
      if (idx != -1) {
        current[idx] = crew.copyWith(activeAssignment: updatedAssignment);
      }
      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('concert_gate_crews').update({
            'gate_name': targetGate,
            'gate_section': targetGate,
          }).eq('concert_id', concertId).eq('crew_email', crew.email);
        } catch (_) {}
      }
    }
    teamCrewNotifier.value = current;
    _persistToLocalCache(current);
  }

  /// Cek apakah user Gate Crew yang sedang login memiliki tugas aktif (memori & cache)
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

  /// Query langsung status penugasan Gate Crew dari tabel `concert_gate_crews` di Supabase
  Future<GateCrewAssignmentModel?> fetchDirectAssignmentForUser({
    required String userId,
    String? userEmail,
  }) async {
    if (!SupabaseService.isInitialized) {
      return getAssignmentForUser(userId, userEmail: userEmail);
    }
    try {
      final lowerEmail = userEmail?.trim().toLowerCase() ?? '';
      final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(userId);

      List<dynamic> rows = const [];
      final baseQuery = SupabaseService.client
          .from('concert_gate_crews')
          .select('*, concerts(title, venue, is_active, status)');

      if (isUuid && lowerEmail.isNotEmpty) {
        rows = await baseQuery.or(
            'crew_user_id.eq.$userId,crew_id.eq.$userId,crew_email.ilike.$lowerEmail');
      } else if (isUuid) {
        rows = await baseQuery.or('crew_user_id.eq.$userId,crew_id.eq.$userId');
      } else if (lowerEmail.isNotEmpty) {
        rows = await baseQuery
            .or('crew_id.eq.$userId,crew_email.ilike.$lowerEmail');
      } else {
        rows = await baseQuery.eq('crew_id', userId);
      }

      if (rows.isNotEmpty) {
        final a = rows.first;
        final rawConcert = a['concerts'];
        final concertTitle = rawConcert is Map
            ? (rawConcert['title'] as String? ??
                (a['concert_title'] as String? ?? 'Konser LiveTix'))
            : (a['concert_title'] as String? ?? 'Konser LiveTix');
        final venue = rawConcert is Map
            ? (rawConcert['venue'] as String? ??
                (a['venue'] as String? ?? 'Venue Konser'))
            : (a['venue'] as String? ?? 'Venue Konser');

        final assignment = GateCrewAssignmentModel(
          id: a['id']?.toString() ?? '',
          concertId: a['concert_id']?.toString() ?? '',
          concertTitle: concertTitle,
          venue: venue,
          gateName:
              (a['gate_name'] ?? a['gate_section'])?.toString() ?? 'Gate A',
          assignedAt: DateTime.tryParse(
                  (a['assigned_at'] ?? a['created_at'])?.toString() ?? '') ??
              DateTime.now(),
        );

        // Update ke notifier memori
        final current = List<GateCrewMemberModel>.from(teamCrewNotifier.value);
        final idx = current.indexWhere((c) =>
            c.id == userId ||
            (lowerEmail.isNotEmpty && c.email.toLowerCase() == lowerEmail));
        if (idx != -1) {
          current[idx] = current[idx].copyWith(activeAssignment: assignment);
          teamCrewNotifier.value = current;
          _persistToLocalCache(current);
        }
        return assignment;
      }
    } catch (e) {
      debugPrint('Error fetchDirectAssignmentForUser Supabase: $e');
    }
    return getAssignmentForUser(userId, userEmail: userEmail);
  }

  /// Catat riwayat check-in tiket ke Supabase `ticket_checkins` dan cache lokal
  Future<bool> recordTicketCheckIn({
    required String concertId,
    required String concertTitle,
    required String bookingCode,
    required String attendeeName,
    required String category,
    required String gateName,
    required String crewId,
    required String crewEmail,
    required String crewName,
    required int scannedCount,
    required int quota,
    required String status,
    String? notes,
  }) async {
    final entry = {
      'id': 'chk-${DateTime.now().millisecondsSinceEpoch}',
      'concert_id': concertId,
      'concert_title': concertTitle,
      'ticket_code': bookingCode,
      'booking_code': bookingCode,
      'attendee_name': attendeeName,
      'name': attendeeName,
      'category': category,
      'gate_name': gateName,
      'crew_id': crewId,
      'crew_email': crewEmail,
      'crew_name': crewName,
      'scanned_count': scannedCount,
      'scannedCount': scannedCount,
      'quota': quota,
      'status': status,
      'notes': notes,
      'time': 'Baru saja',
      'bookingCode': bookingCode,
      'checked_in_at': DateTime.now().toIso8601String(),
    };

    // Simpan ke cache lokal
    try {
      final cacheKey = 'livetix_checkins_${concertId}_$gateName';
      final existingRaw = LocalStorage.getItem(cacheKey);
      final List<dynamic> list =
          existingRaw != null ? jsonDecode(existingRaw) as List<dynamic> : [];
      list.insert(0, entry);
      LocalStorage.setItem(cacheKey, jsonEncode(list.take(100).toList()));
    } catch (_) {}

    // Simpan ke Supabase jika terhubung
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('ticket_checkins').insert({
          'concert_id': concertId,
          'concert_title': concertTitle,
          'ticket_code': bookingCode,
          'booking_code': bookingCode,
          'attendee_name': attendeeName,
          'category': category,
          'gate_name': gateName,
          'crew_id': crewId,
          'crew_email': crewEmail,
          'crew_name': crewName,
          'scanned_count': scannedCount,
          'quota': quota,
          'status': status,
          'notes': notes,
        });
        return true;
      } catch (e) {
        debugPrint('Error recordTicketCheckIn Supabase: $e');
      }
    }
    return true;
  }

  /// Ambil riwayat log check-in terkini dari database Supabase / cache lokal
  Future<List<Map<String, dynamic>>> loadCheckInHistory({
    required String concertId,
    String gateName = 'Gate A',
  }) async {
    if (SupabaseService.isInitialized) {
      try {
        final rows = await SupabaseService.client
            .from('ticket_checkins')
            .select()
            .eq('concert_id', concertId)
            .order('checked_in_at', ascending: false)
            .limit(30);

        if (rows.isNotEmpty) {
          return rows.map<Map<String, dynamic>>((r) {
            return {
              'name': (r['attendee_name'] ?? 'Pengunjung').toString(),
              'category': (r['category'] ?? 'Reguler').toString(),
              'bookingCode':
                  (r['booking_code'] ?? r['ticket_code'] ?? '-').toString(),
              'time': 'Tervalidasi',
              'status': (r['status'] ?? 'Berhasil').toString(),
              'scannedCount': (r['scanned_count'] as num?)?.toInt() ?? 1,
              'quota': (r['quota'] as num?)?.toInt() ?? 1,
            };
          }).toList();
        }
      } catch (e) {
        debugPrint('Error loadCheckInHistory Supabase: $e');
      }
    }

    try {
      final cacheKey = 'livetix_checkins_${concertId}_$gateName';
      final raw = LocalStorage.getItem(cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}

    return const [];
  }

  /// Ambil ringkasan statistik scan gate dari Supabase
  Future<Map<String, int>> loadGateCheckInStats({
    required String concertId,
  }) async {
    int checkedIn = 0;
    int rejected = 0;

    if (SupabaseService.isInitialized) {
      try {
        final rows = await SupabaseService.client
            .from('ticket_checkins')
            .select('status, scanned_count')
            .eq('concert_id', concertId);

        for (final r in rows) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          if (status.contains('berhasil')) {
            checkedIn += (r['scanned_count'] as num?)?.toInt() ?? 1;
          } else if (status.contains('tolak') || status.contains('invalid')) {
            rejected += 1;
          }
        }
        return {'totalCheckedIn': checkedIn, 'totalRejected': rejected};
      } catch (e) {
        debugPrint('Error loadGateCheckInStats Supabase: $e');
      }
    }

    return {'totalCheckedIn': checkedIn, 'totalRejected': rejected};
  }

  /// Verifikasi keaslian dan status tiket langsung ke database Supabase dan memori lokal
  Future<TicketScanValidationResult> verifyTicketInDatabase({
    required String scannedCode,
    required String currentConcertId,
    required String currentGate,
  }) async {
    final cleanCode = scannedCode.trim();
    if (cleanCode.isEmpty) {
      return const TicketScanValidationResult(
        isValid: false,
        status: 'Ditolak (Invalid)',
        invalidReason: 'Kode barcode/QR tiket kosong.',
      );
    }

    Map<String, dynamic>? ticketRow;
    String customerName = 'Pengunjung LiveTix';

    // 1. Cek langsung ke tabel tickets di Supabase
    if (SupabaseService.isInitialized) {
      try {
        final query = SupabaseService.client
            .from('tickets')
            .select('*, orders(customer_name, customer_email, customer_phone)');

        List<dynamic> rows = [];
        try {
          rows = await query.or(
              'ticket_code.eq.$cleanCode,id.eq.$cleanCode,order_id.eq.$cleanCode');
        } catch (_) {}

        if (rows.isEmpty) {
          try {
            rows = await SupabaseService.client
                .from('tickets')
                .select(
                    '*, orders(customer_name, customer_email, customer_phone)')
                .ilike('ticket_code', '%$cleanCode%');
          } catch (_) {}
        }

        if (rows.isNotEmpty) {
          ticketRow = rows.first as Map<String, dynamic>;
          final rawOrder = ticketRow['orders'];
          if (rawOrder is Map && rawOrder['customer_name'] != null) {
            customerName = rawOrder['customer_name'].toString();
          }
        }
      } catch (e) {
        debugPrint('Error query tickets Supabase: $e');
      }
    }

    // 2. Fallback jika offline atau ada di memori DataService userTickets
    if (ticketRow == null) {
      final userTickets = DataService().userTicketsNotifier.value;
      for (final t in userTickets) {
        if (t.bookingCode.toLowerCase() == cleanCode.toLowerCase() ||
            t.id.toLowerCase() == cleanCode.toLowerCase() ||
            (t.qrData != null &&
                t.qrData!.toLowerCase() == cleanCode.toLowerCase()) ||
            cleanCode.contains(t.bookingCode) ||
            cleanCode.contains(t.id)) {
          ticketRow = {
            'id': t.id,
            'ticket_code': t.bookingCode,
            'order_id': t.id,
            'concert_id': currentConcertId,
            'concert_title': t.concertTitle,
            'tier_name': t.category,
            'gate_name': t.gate.isNotEmpty ? t.gate : 'Gate A',
            'status': t.status.toUpperCase() == 'REFFUND'
                ? 'DIREFUND'
                : (t.isCompleted ? 'SUDAH DIPAKAI' : 'AKTIF'),
            'qr_scan_quota': t.qrScanQuota,
            'qr_scans_used': t.qrScansUsed,
          };
          customerName = DataService().currentUser?.name.isNotEmpty == true
              ? DataService().currentUser!.name
              : 'Pengunjung LiveTix';
          break;
        }
      }
    }

    // 3. Jika tiket sama sekali tidak ditemukan di sistem
    if (ticketRow == null) {
      return TicketScanValidationResult(
        isValid: false,
        status: 'Ditolak (Tidak Ditemukan)',
        invalidReason:
            'Kode tiket "$cleanCode" tidak terdaftar di sistem. Pastikan tiket dibeli secara resmi melalui LiveTix.',
        bookingCode: cleanCode,
        ticketCode: cleanCode,
      );
    }

    final ticketId = ticketRow['id']?.toString() ?? '';
    final ticketCode = (ticketRow['ticket_code'] ?? ticketRow['id'] ?? cleanCode).toString();
    final bookingCode = (ticketRow['order_id'] ?? ticketRow['ticket_code'] ?? cleanCode).toString();
    final concertId = ticketRow['concert_id']?.toString() ?? '';
    final concertTitle = (ticketRow['concert_title'] ?? 'Konser LiveTix').toString();
    final tierName = (ticketRow['tier_name'] ?? ticketRow['category'] ?? 'Reguler').toString();
    final gateName = (ticketRow['gate_name'] ?? 'Gate A').toString();
    final status = (ticketRow['status'] ?? 'AKTIF').toString().toUpperCase();
    final quota = (ticketRow['qr_scan_quota'] as num?)?.toInt() ?? 1;
    final used = (ticketRow['qr_scans_used'] as num?)?.toInt() ?? 0;

    // 4. Validasi Konser
    if (currentConcertId.isNotEmpty &&
        concertId.isNotEmpty &&
        concertId != currentConcertId &&
        !concertId.contains(currentConcertId) &&
        !currentConcertId.contains(concertId)) {
      return TicketScanValidationResult(
        isValid: false,
        status: 'Ditolak (Salah Konser)',
        invalidReason:
            'Tiket ini terdaftar untuk konser "$concertTitle", bukan untuk konser ini.',
        ticketId: ticketId,
        ticketCode: ticketCode,
        bookingCode: bookingCode,
        attendeeName: customerName,
        category: tierName,
        gateName: gateName,
        concertId: concertId,
        concertTitle: concertTitle,
        quota: quota,
        used: used,
      );
    }

    // 5. Validasi Status Refund / Pembatalan
    if (status.contains('REFUND') ||
        status.contains('BATAL') ||
        status.contains('CANCEL')) {
      return TicketScanValidationResult(
        isValid: false,
        status: 'Ditolak (Direfund)',
        invalidReason:
            'Tiket ini telah dibatalkan / direfund dan tidak berlaku lagi untuk masuk.',
        ticketId: ticketId,
        ticketCode: ticketCode,
        bookingCode: bookingCode,
        attendeeName: customerName,
        category: tierName,
        gateName: gateName,
        concertId: concertId,
        concertTitle: concertTitle,
        quota: quota,
        used: used,
      );
    }

    // 6. Validasi Pos Gate Sesuai Kategori / Gate yang Ditetapkan Produser
    final cleanCurrentGate = currentGate
        .replaceAll(RegExp(r'\(.*\)'), '')
        .trim()
        .toLowerCase();
    final cleanTicketGate = gateName
        .replaceAll(RegExp(r'\(.*\)'), '')
        .trim()
        .toLowerCase();

    if (cleanTicketGate.isNotEmpty &&
        cleanCurrentGate.isNotEmpty &&
        cleanTicketGate != cleanCurrentGate &&
        !cleanTicketGate.contains(cleanCurrentGate) &&
        !cleanCurrentGate.contains(cleanTicketGate)) {
      return TicketScanValidationResult(
        isValid: false,
        isWrongGate: true,
        status: 'Ditolak (Salah Gate)',
        invalidReason:
            'Salah Pos Gate! Kategori "$tierName" dialokasikan melalui $gateName. Saat ini Anda bertugas di $currentGate. Silakan arahkan penonton ke $gateName.',
        ticketId: ticketId,
        ticketCode: ticketCode,
        bookingCode: bookingCode,
        attendeeName: customerName,
        category: tierName,
        gateName: gateName,
        concertId: concertId,
        concertTitle: concertTitle,
        quota: quota,
        used: used,
      );
    }

    // 7. Validasi Kuota Scan Tiket (Multi-scan)
    final remaining = quota - used;
    if (remaining <= 0 || status == 'SUDAH DIPAKAI' || status == 'USED') {
      return TicketScanValidationResult(
        isValid: false,
        status: 'Ditolak (Habis Kuota)',
        invalidReason:
            'Seluruh kuota tiket ($quota tiket) sudah pernah digunakan untuk check-in.',
        ticketId: ticketId,
        ticketCode: ticketCode,
        bookingCode: bookingCode,
        attendeeName: customerName,
        category: tierName,
        gateName: gateName,
        concertId: concertId,
        concertTitle: concertTitle,
        quota: quota,
        used: used,
      );
    }

    // 8. Seluruh Validasi Lulus -> TIKET VALID RESMI
    return TicketScanValidationResult(
      isValid: true,
      status: 'Berhasil',
      ticketId: ticketId,
      ticketCode: ticketCode,
      bookingCode: bookingCode,
      attendeeName: customerName,
      category: tierName,
      gateName: gateName,
      concertId: concertId,
      concertTitle: concertTitle,
      quota: quota,
      used: used,
    );
  }

  /// Eksekusi Check-in Pengunjung ke Database Supabase
  Future<bool> executeCheckIn({
    required TicketScanValidationResult ticket,
    required int countToUse,
    required String gateName,
    required String crewId,
    required String crewName,
    required String crewEmail,
    required String concertTitle,
  }) async {
    final newUsed = ticket.used + countToUse;
    final isFullyUsed = newUsed >= ticket.quota;
    final newStatus = isFullyUsed ? 'SUDAH DIPAKAI' : 'AKTIF';

    // 1. Update Supabase tabel tickets
    if (SupabaseService.isInitialized && ticket.ticketId.isNotEmpty) {
      try {
        await SupabaseService.client.from('tickets').update({
          'qr_scans_used': newUsed,
          'status': newStatus,
          if (isFullyUsed) 'used_at': DateTime.now().toIso8601String(),
        }).eq('id', ticket.ticketId);
      } catch (e) {
        debugPrint('Error updating ticket by id: $e');
        try {
          await SupabaseService.client.from('tickets').update({
            'qr_scans_used': newUsed,
            'status': newStatus,
            if (isFullyUsed) 'used_at': DateTime.now().toIso8601String(),
          }).eq('ticket_code', ticket.ticketCode);
        } catch (_) {}
      }
    }

    // 2. Sinkronkan tiket di DataService userTickets (in-memory)
    final userTickets =
        List<UserTicketModel>.from(DataService().userTicketsNotifier.value);
    final idx = userTickets.indexWhere((t) =>
        t.id == ticket.ticketId ||
        t.bookingCode == ticket.ticketCode ||
        t.bookingCode == ticket.bookingCode);
    if (idx != -1) {
      final old = userTickets[idx];
      userTickets[idx] = old.copyWith(
        qrScansUsed: newUsed,
        isCompleted: isFullyUsed,
        status: isFullyUsed ? 'Selesai' : old.status,
      );
      DataService().userTicketsNotifier.value = userTickets;
    }

    // 3. Catat transaksi check-in ke tabel ticket_checkins
    await recordTicketCheckIn(
      concertId: ticket.concertId,
      concertTitle: concertTitle,
      bookingCode: ticket.bookingCode,
      attendeeName: ticket.attendeeName,
      category: ticket.category,
      gateName: gateName,
      crewId: crewId,
      crewEmail: crewEmail,
      crewName: crewName,
      scannedCount: countToUse,
      quota: ticket.quota,
      status: countToUse > 1 ? 'Berhasil (Rombongan)' : 'Berhasil',
    );

    return true;
  }
}
