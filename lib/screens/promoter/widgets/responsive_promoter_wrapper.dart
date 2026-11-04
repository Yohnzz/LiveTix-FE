import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/promoter_data_service.dart';

class ResponsivePromoterWrapper extends StatelessWidget {
  final Widget child;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool showAppBar;
  final PreferredSizeWidget? appBar;

  const ResponsivePromoterWrapper({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.showAppBar = false,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final service = PromoterDataService();

    return ValueListenableBuilder<bool>(
      valueListenable: service.isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final defaultBg =
            isDarkMode ? const Color(0xFF10131A) : const Color(0xFFF9FAFB);
        final bg = backgroundColor ?? defaultBg;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDarkMode ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: bg,
            systemNavigationBarIconBrightness:
                isDarkMode ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            appBar: appBar,
            body: SafeArea(
              top: !showAppBar,
              bottom: bottomNavigationBar == null,
              child: SizedBox.expand(
                child: child,
              ),
            ),
            bottomNavigationBar: bottomNavigationBar,
          ),
        );
      },
    );
  }
}
