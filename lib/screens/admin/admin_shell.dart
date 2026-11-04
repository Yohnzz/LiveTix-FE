import 'package:flutter/material.dart';
import '../../models/approval_models.dart';
import '../../services/admin_service.dart';
import 'admin_approval_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_users_screen.dart';
import 'widgets/admin_theme.dart';
import 'widgets/admin_widgets.dart';

/// Status navigasi yang perlu dibagikan antar layar admin.
class AdminNavigation {
  AdminNavigation._();

  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<ApprovalKind> approvalKind =
      ValueNotifier<ApprovalKind>(ApprovalKind.producer);

  static void reset() {
    tab.value = 0;
    approvalKind.value = ApprovalKind.producer;
  }

  static void openApproval(ApprovalKind kind) {
    approvalKind.value = kind;
    tab.value = 1;
  }

  static void openTab(int index) {
    tab.value = index;
  }
}

class AdminShell extends StatefulWidget {
  static const routeName = '/admin';

  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    AdminService().load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScope(
      child: ValueListenableBuilder<int>(
        valueListenable: AdminNavigation.tab,
        builder: (context, index, _) {
          return PopScope(
            canPop: index == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) AdminNavigation.tab.value = 0;
            },
            child: Scaffold(
              body: IndexedStack(
                index: index,
                children: const [
                  AdminDashboardScreen(),
                  AdminApprovalScreen(),
                  AdminUsersScreen(),
                  AdminProfileScreen(),
                ],
              ),
              bottomNavigationBar: AdminBottomNav(
                currentIndex: index,
                onTap: (i) => AdminNavigation.tab.value = i,
              ),
            ),
          );
        },
      ),
    );
  }
}
