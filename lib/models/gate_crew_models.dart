class GateCrewAssignmentModel {
  final String id;
  final String concertId;
  final String concertTitle;
  final String venue;
  final String gateName;
  final DateTime assignedAt;

  const GateCrewAssignmentModel({
    required this.id,
    required this.concertId,
    required this.concertTitle,
    required this.venue,
    this.gateName = 'Gate A',
    required this.assignedAt,
  });

  factory GateCrewAssignmentModel.fromJson(Map<String, dynamic> json) {
    return GateCrewAssignmentModel(
      id: json['id'] as String? ?? '',
      concertId: (json['concert_id'] ?? json['concertId'] ?? '') as String,
      concertTitle: (json['concert_title'] ??
          json['concertTitle'] ??
          'Soundwave Fest 2026') as String,
      venue: (json['venue'] ?? 'Stadion Gajayana, Malang') as String,
      gateName: (json['gate_name'] ?? json['gateName'] ?? 'Gate A') as String,
      assignedAt: DateTime.tryParse(json['assigned_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'concert_id': concertId,
        'concert_title': concertTitle,
        'venue': venue,
        'gate_name': gateName,
        'assigned_at': assignedAt.toIso8601String(),
      };

  GateCrewAssignmentModel copyWith({
    String? id,
    String? concertId,
    String? concertTitle,
    String? venue,
    String? gateName,
    DateTime? assignedAt,
  }) {
    return GateCrewAssignmentModel(
      id: id ?? this.id,
      concertId: concertId ?? this.concertId,
      concertTitle: concertTitle ?? this.concertTitle,
      venue: venue ?? this.venue,
      gateName: gateName ?? this.gateName,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }
}

class GateCrewMemberModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final GateCrewAssignmentModel? activeAssignment;
  final String approvalStatus; // 'approved' | 'pending' | 'rejected'
  final String defaultPassword;
  final String producerId;
  final String producerName;
  final String producerEmail;

  const GateCrewMemberModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.activeAssignment,
    this.approvalStatus = 'approved',
    this.defaultPassword = 'crewgate123',
    this.producerId = 'producer-1',
    this.producerName = 'Soundwave Entertainment',
    this.producerEmail = 'produser@livetix.com',
  });

  bool get isAssigned => activeAssignment != null;
  bool get isApproved => approvalStatus.toLowerCase() == 'approved';
  bool get isPendingApproval => approvalStatus.toLowerCase() == 'pending';
  bool get isRejected => approvalStatus.toLowerCase() == 'rejected';

  GateCrewMemberModel copyWith({
    String? name,
    String? email,
    String? phone,
    GateCrewAssignmentModel? activeAssignment,
    bool clearAssignment = false,
    String? approvalStatus,
    String? defaultPassword,
    String? producerId,
    String? producerName,
    String? producerEmail,
  }) {
    return GateCrewMemberModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      activeAssignment:
          clearAssignment ? null : (activeAssignment ?? this.activeAssignment),
      approvalStatus: approvalStatus ?? this.approvalStatus,
      defaultPassword: defaultPassword ?? this.defaultPassword,
      producerId: producerId ?? this.producerId,
      producerName: producerName ?? this.producerName,
      producerEmail: producerEmail ?? this.producerEmail,
    );
  }

  factory GateCrewMemberModel.fromJson(Map<String, dynamic> json) {
    GateCrewAssignmentModel? assignment;
    if (json['active_assignment'] is Map<String, dynamic>) {
      assignment = GateCrewAssignmentModel.fromJson(
          json['active_assignment'] as Map<String, dynamic>);
    } else if (json['concert_id'] != null &&
        (json['concert_id'] as String).isNotEmpty) {
      assignment = GateCrewAssignmentModel(
        id: (json['assignment_id'] ?? '') as String,
        concertId: json['concert_id'] as String,
        concertTitle: (json['concert_title'] ?? 'Soundwave Fest 2026') as String,
        venue: (json['venue'] ?? 'Stadion Gajayana, Malang') as String,
        gateName: (json['gate_name'] ?? 'Gate A') as String,
        assignedAt: DateTime.tryParse(json['assigned_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }

    return GateCrewMemberModel(
      id: json['id'] as String? ?? '',
      name: (json['name'] ?? json['full_name'] ?? 'Petugas Gate') as String,
      email: (json['email'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      activeAssignment: assignment,
      approvalStatus: (json['approval_status'] ??
          json['approvalStatus'] ??
          'approved') as String,
      defaultPassword:
          (json['default_password'] ?? 'crewgate123') as String,
      producerId: (json['producer_id'] ??
          json['producerId'] ??
          'producer-1') as String,
      producerName: (json['producer_name'] ??
          json['producerName'] ??
          'Soundwave Entertainment') as String,
      producerEmail: (json['producer_email'] ??
          json['producerEmail'] ??
          'produser@livetix.com') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'approval_status': approvalStatus,
        'default_password': defaultPassword,
        'producer_id': producerId,
        'producer_name': producerName,
        'producer_email': producerEmail,
        'active_assignment': activeAssignment?.toJson(),
      };
}

class TicketScanValidationResult {
  final bool isValid;
  final String status; // 'Berhasil', 'Ditolak (Salah Gate)', 'Ditolak (Habis Kuota)', 'Ditolak (Salah Konser)', 'Ditolak (Invalid)', 'Ditolak (Direfund)'
  final String? invalidReason;
  final String ticketId;
  final String bookingCode;
  final String ticketCode;
  final String attendeeName;
  final String category;
  final String gateName;
  final String concertId;
  final String concertTitle;
  final int quota;
  final int used;
  final bool isWrongGate;

  const TicketScanValidationResult({
    required this.isValid,
    required this.status,
    this.invalidReason,
    this.ticketId = '',
    this.bookingCode = '',
    this.ticketCode = '',
    this.attendeeName = 'Pengunjung',
    this.category = 'Reguler',
    this.gateName = 'Gate A',
    this.concertId = '',
    this.concertTitle = '',
    this.quota = 1,
    this.used = 0,
    this.isWrongGate = false,
  });

  int get remaining => (quota - used).clamp(0, quota);
}


