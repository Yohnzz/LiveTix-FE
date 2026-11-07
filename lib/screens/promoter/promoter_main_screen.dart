import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/promoter_data_service.dart';
import 'add_concert/add_concert_flow.dart';
import 'promoter_concert_list_screen.dart';
import 'promoter_dashboard_screen.dart';
import 'promoter_finance_screen.dart';
import 'promoter_profile_screen.dart';
import 'promoter_team_screen.dart';

class PromoterMainScreen extends StatefulWidget {
  final int initialTabIndex;

  const PromoterMainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PromoterMainScreen> createState() => _PromoterMainScreenState();
}

class _PromoterMainScreenState extends State<PromoterMainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _openAddConcert() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddConcertFlow()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    final List<Widget> pages = [
      PromoterDashboardScreen(
        onNavigateToConcerts: () => setState(() => _currentIndex = 1),
        onNavigateToProfile: () => setState(() => _currentIndex = 4),
        onAddConcertPressed: _openAddConcert,
      ),
      PromoterConcertListScreen(
        onAddConcertPressed: _openAddConcert,
      ),
      const PromoterTeamScreen(),
      const PromoterFinanceScreen(),
      const PromoterProfileScreen(),
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final bg = isDarkMode
            ? const Color(0xFF10131A)
            : const Color(0xFFF9FAFB);
        final bottomNavBg =
            isDarkMode ? const Color(0xFF161B26) : Colors.white;
        final bottomNavBorder =
            isDarkMode ? Colors.white12 : const Color(0xFFE4E7EC);

        final bottomNav = Container(
          decoration: BoxDecoration(
            color: bottomNavBg,
            border: Border(top: BorderSide(color: bottomNavBorder, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Dasbor', isDarkMode),
                _buildNavItem(1, Icons.music_note_outlined, Icons.music_note_rounded, 'Konser', isDarkMode),
                _buildNavItem(2, Icons.groups_outlined, Icons.groups_rounded, 'Team', isDarkMode),
                _buildNavItem(3, Icons.credit_card_outlined, Icons.credit_card_rounded, 'Keuangan', isDarkMode),
                _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profil', isDarkMode),
              ],
            ),
          ),
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDarkMode ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: bottomNavBg,
            systemNavigationBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              child: SizedBox.expand(
                child: IndexedStack(
                  index: _currentIndex,
                  children: pages,
                ),
              ),
            ),
            bottomNavigationBar: bottomNav,
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    bool isDarkMode,
  ) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? const Color(0xFFC2185B) // Magenta
        : (isDarkMode ? Colors.white60 : const Color(0xFF667085));

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? filledIcon : outlineIcon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
