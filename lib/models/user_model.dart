class UserModel {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role; // 'User' | 'Produser' | 'Admin'
  final int ticketsBought;
  final int concertsAttended;
  final int reviewsCount;

  const UserModel({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.role = 'User',
    this.ticketsBought = 12,
    this.concertsAttended = 9,
    this.reviewsCount = 4,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
