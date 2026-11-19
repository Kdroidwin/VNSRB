import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/_base/data/base_menu_sections.dart';
import 'package:vndb_lite/src/features/_base/presentation/lower_parts/bottom_progress_indicator_state.dart';
import 'package:vndb_lite/src/features/theme/theme_data_provider.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';

import '../../../../util/context_shortcut.dart';

class TabsBottomNavbar extends ConsumerWidget {
  const TabsBottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.onlyProgressIndicator = false,
  });

  final int selectedIndex;
  final void Function(int)? onTap;
  final bool onlyProgressIndicator;

  static final double heightBottomNav = responsiveUI.own(0.15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final japaneseUi = ref.watch(japaneseUiProvider);
    final showSelectedLabels =
        ref.watch(settingsGeneralStateProvider).showNavigationLabelsOnTap;
    final isFloating =
        ref.watch(settingsGeneralStateProvider).floatingBottomNavigation;
    const japaneseLabels = ['ホーム', '検索', 'コレクション', 'その他'];
    final menus = BASE_TAB_MENU_SECTIONS.entries.indexed;

    final Widget navigationBar;
    if (isFloating) {
      final radius = BorderRadius.circular(responsiveUI.own(0.045));
      navigationBar = Container(
        margin: EdgeInsets.fromLTRB(
          responsiveUI.own(0.035),
          responsiveUI.own(0.012),
          responsiveUI.own(0.035),
          responsiveUI.own(0.018),
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kColor(context).primary.withAlpha(238),
              kColor(context).primary.withAlpha(250),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(150, 0, 0, 0),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color:
                      selected
                          ? kColor(context).secondary
                          : kColor(context).secondary.withAlpha(120),
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return styleText(
                  fontSize: responsiveUI.normalSize * 0.85,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: kColor(context).tertiary,
                );
              }),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: kColor(context).secondary.withAlpha(24),
              labelBehavior:
                  showSelectedLabels
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysHide,
              selectedIndex: selectedIndex,
              onDestinationSelected: onTap,
              destinations: [
                for (final (index, menu) in menus)
                  NavigationDestination(
                    icon: Icon(
                      menu.value.nonActiveIcon,
                      size: responsiveUI.standardIcon,
                    ),
                    selectedIcon: Icon(
                      menu.value.activeIcon,
                      size: responsiveUI.standardIcon,
                    ),
                    label:
                        japaneseUi ? japaneseLabels[index] : menu.value.title,
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      navigationBar = SizedBox(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kColor(context).primary.withAlpha(140),
                kColor(context).primary.withAlpha(220),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(150, 0, 0, 0),
                spreadRadius: 2,
                blurRadius: 6,
              ),
            ],
          ),
          child: BottomNavigationBar(
            showSelectedLabels: showSelectedLabels,
            showUnselectedLabels: false,
            items: [
              for (final (index, menu) in menus)
                BottomNavigationBarItem(
                  icon: Icon(
                    menu.value.nonActiveIcon,
                    size: responsiveUI.standardIcon,
                  ),
                  activeIcon: Icon(
                    menu.value.activeIcon,
                    size: responsiveUI.standardIcon,
                  ),
                  label: japaneseUi ? japaneseLabels[index] : menu.value.title,
                ),
            ],
            onTap: onTap,
            elevation: 0,
            enableFeedback: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedLabelStyle: styleText(
              fontSize: responsiveUI.normalSize * 0.85,
              fontWeight: FontWeight.bold,
              color: kColor(context).tertiary,
            ),
            unselectedLabelStyle: styleText(
              fontSize: responsiveUI.normalSize,
              color: kColor(context).tertiary,
            ),
            currentIndex: selectedIndex,
            selectedFontSize: responsiveUI.normalSize,
            unselectedFontSize: responsiveUI.normalSize,
            selectedItemColor: kColor(context).secondary,
            unselectedItemColor: kColor(context).secondary.withAlpha(120),
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (!onlyProgressIndicator) navigationBar,
        Consumer(
          builder: (context, ref, child) {
            if (!ref.watch(bottomProgressIndicatorProvider)) {
              return const SizedBox.shrink();
            }

            return SizedBox(
              width: kScreenWidth(context),
              height: responsiveUI.own(0.01),
              child: LinearProgressIndicator(
                backgroundColor: kColor(context).secondary,
                color: kColor(context).primary,
              ),
            );
          },
        ),
      ],
    );
  }
}
