import 'package:flutter/material.dart';
import '../models/concert_model.dart';
import '../models/ticket_order_model.dart';
import '../models/user_model.dart';

/// Database Dummy Pusat untuk Aplikasi LiveTix.
/// Data diambil langsung dari backend Supabase Cloud.
class DbDummy {
  // Status awal persetujuan aplikasi pada sesi lokal/dummy
  static const bool defaultGuestAgreementAccepted = false;

  // 1. Data Pengguna Terdaftar (Fallback lokal saat offline)
  static final List<UserModel> users = [
    const UserModel(
      id: '123456',
      name: 'Rafi Firmansyah',
      email: 'rafi@email.com',
      phone: '081234567890',
      password: '123456',
      role: 'User',
      ticketsBought: 0,
      concertsAttended: 0,
      reviewsCount: 0,
      nik: '3573011205950001',
      isVerified: true,
    ),
  ];

  // 2. Data Kota Populer
  static final List<CityModel> cities = [
    const CityModel(
      name: 'Malang',
      eventCount: 0,
      bgColor: Color(0xFFE8EEFB),
      textColor: Color(0xFF1D4ED8),
    ),
    const CityModel(
      name: 'Jakarta',
      eventCount: 0,
      bgColor: Color(0xFFFCE7F3),
      textColor: Color(0xFFBE185D),
    ),
    const CityModel(
      name: 'Bandung',
      eventCount: 0,
      bgColor: Color(0xFFFEF3C7),
      textColor: Color(0xFF92400E),
    ),
    const CityModel(
      name: 'Surabaya',
      eventCount: 0,
      bgColor: Color(0xFFF3E8FF),
      textColor: Color(0xFF7E22CE),
    ),
  ];

  // 3. Data Genre Musik
  static const List<String> genres = [
    'Semua',
    'Pop',
    'Rock',
    'Indie',
    'EDM',
  ];

  // 4. Data Pilihan Tanggal
  static const List<String> dates = [
    'Semua',
    'Oktober 2026',
    'November 2026',
    'Desember 2026',
  ];

  // 5. Data Konser Lengkap (Data murni dari database Supabase)
  static const List<ConcertModel> concerts = [];

  // 6. Data Tiket Awal Pengguna (Data murni dari database Supabase)
  static const List<UserTicketModel> initialUserTickets = [];
}
