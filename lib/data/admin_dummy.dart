/// Data contoh Super Admin - seluruh data nyata diambil langsung dari Supabase.
class AdminDummy {
  AdminDummy._();

  static const Map<String, dynamic> stats = {
    'total_users': 0,
    'active_producers': 0,
    'active_concerts': 0,
  };

  static const List<Map<String, dynamic>> producers = [];
  static const List<Map<String, dynamic>> concerts = [];
  static const List<Map<String, dynamic>> users = [];
  static const Map<String, dynamic> refundOverview = {
    'total_refunded_label': 'Rp 0',
    'total_refunded_amount': 0,
    'refund_in_process_count': 0,
    'approved_percentage': 0,
    'pending_account_number_count': 0,
    'ready_to_transfer_count': 0,
  };
  static const List<Map<String, dynamic>> refundMonitoring = [];
}
