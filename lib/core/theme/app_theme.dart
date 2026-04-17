import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';
import 'app_button_theme.dart';
import 'app_input_theme.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    scaffoldBackgroundColor: AppColors.lightBackground,
    canvasColor: AppColors.lightBackground,
    cardColor: AppColors.lightSurface,
    hintColor: AppColors.lightHint,
    disabledColor: AppColors.lightDisabled,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    splashColor: AppColors.lightPrimary.withValues(alpha: 0.08),
    highlightColor: AppColors.lightPrimary.withValues(alpha: 0.04),
    focusColor: AppColors.lightPrimary.withValues(alpha: 0.12),
    hoverColor: AppColors.lightPrimary.withValues(alpha: 0.04),

    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
      surface: AppColors.lightSurface,
      error: AppColors.lightError,
      onPrimary: AppColors.lightOnPrimary,
      onSecondary: AppColors.lightOnSecondary,
      onSurface: AppColors.lightOnSurface,
      onError: AppColors.lightOnError,
    ),

    textTheme: AppTextTheme.lightTextTheme,
    primaryTextTheme: AppTextTheme.lightTextTheme,

    iconTheme: const IconThemeData(
      color: AppColors.lightIcon,
      size: 24,
      opacity: 1.0,
    ),
    primaryIconTheme: const IconThemeData(
      color: AppColors.lightOnPrimary,
      size: 24,
      opacity: 1.0,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightOnSurface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.lightOnSurface, size: 24),
      actionsIconTheme: const IconThemeData(
        color: AppColors.lightOnSurface,
        size: 24,
      ),
      titleTextStyle: AppTextTheme.lightTextTheme.titleLarge?.copyWith(
        color: AppColors.lightOnSurface,
        fontWeight: FontWeight.w600,
      ),
      toolbarTextStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightOnSurface,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.lightBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      titleSpacing: 16,
      toolbarHeight: 56,
    ),

    bottomAppBarTheme: const BottomAppBarThemeData(
      color: AppColors.lightSurface,
      elevation: 8,
      shape: CircularNotchedRectangle(),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.lightPrimary,
      unselectedLabelColor: AppColors.lightHint,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.lightPrimary, width: 2),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      overlayColor: WidgetStateProperty.all(
        AppColors.lightPrimary.withValues(alpha: 0.08),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.lightPrimary,
      unselectedItemColor: AppColors.lightHint,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: AppTextTheme.lightTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextTheme.lightTextTheme.labelSmall,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedIconTheme: const IconThemeData(
        size: 24,
        color: AppColors.lightPrimary,
      ),
      unselectedIconTheme: const IconThemeData(
        size: 24,
        color: AppColors.lightHint,
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedIconTheme: const IconThemeData(
        color: AppColors.lightPrimary,
        size: 24,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.lightHint,
        size: 24,
      ),
      selectedLabelTextStyle: AppTextTheme.lightTextTheme.labelMedium?.copyWith(
        color: AppColors.lightPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: AppTextTheme.lightTextTheme.labelMedium
          ?.copyWith(color: AppColors.lightHint),
      elevation: 0,
      groupAlignment: -1.0,
      indicatorColor: AppColors.lightPrimary.withValues(alpha: 0.12),
      useIndicator: true,
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 16,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightChipBackground,
      disabledColor: AppColors.lightDisabled,
      selectedColor: AppColors.lightPrimary.withValues(alpha: 0.12),
      secondarySelectedColor: AppColors.lightSecondary.withValues(alpha: 0.12),
      deleteIconColor: AppColors.lightHint,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      brightness: Brightness.light,
      elevation: 0,
      pressElevation: 2,
      shape: const StadiumBorder(),
      side: const BorderSide(color: AppColors.lightBorder),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 24,
      alignment: Alignment.center,
      titleTextStyle: AppTextTheme.lightTextTheme.titleLarge?.copyWith(
        color: AppColors.lightOnSurface,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightOnSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      elevation: 16,
      modalElevation: 24,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      modalBackgroundColor: AppColors.lightSurface,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.lightSnackBarBackground,
      contentTextStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightSnackBarContent,
      ),
      actionTextColor: AppColors.lightPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.lightTooltipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: AppTextTheme.lightTextTheme.labelSmall?.copyWith(
        color: AppColors.lightTooltipContent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 500),
    ),

    elevatedButtonTheme: AppButtonTheme.lightElevatedButton,

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lightPrimary,
        textStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 44),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightPrimary,
        side: const BorderSide(color: AppColors.lightPrimary, width: 1.5),
        textStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 44),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.lightPrimary,
      foregroundColor: AppColors.lightOnPrimary,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: AppTextTheme.lightTextTheme.labelLarge?.copyWith(
        color: AppColors.lightOnPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: AppInputTheme.lightInputTheme,

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary;
        }
        if (states.contains(WidgetState.disabled)) {
          return AppColors.lightDisabled;
        }
        return AppColors.lightHint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary.withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.disabled)) {
          return AppColors.lightDisabled;
        }
        return AppColors.lightBorder;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary.withValues(alpha: 0.08);
        }
        return AppColors.lightHint.withValues(alpha: 0.08);
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary;
        }
        if (states.contains(WidgetState.disabled)) {
          return AppColors.lightDisabled;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.lightOnPrimary),
      overlayColor: WidgetStateProperty.all(
        AppColors.lightPrimary.withValues(alpha: 0.08),
      ),
      side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary;
        }
        if (states.contains(WidgetState.disabled)) {
          return AppColors.lightDisabled;
        }
        return AppColors.lightBorder;
      }),
      overlayColor: WidgetStateProperty.all(
        AppColors.lightPrimary.withValues(alpha: 0.08),
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.lightPrimary,
      inactiveTrackColor: AppColors.lightBorder,
      thumbColor: AppColors.lightPrimary,
      overlayColor: AppColors.lightPrimary.withValues(alpha: 0.12),
      valueIndicatorColor: AppColors.lightPrimary,
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      valueIndicatorTextStyle: AppTextTheme.lightTextTheme.labelSmall?.copyWith(
        color: AppColors.lightOnPrimary,
      ),
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
      activeTickMarkColor: AppColors.lightPrimary.withValues(alpha: 0.5),
      inactiveTickMarkColor: AppColors.lightBorder,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lightPrimary,
      linearTrackColor: AppColors.lightBorder,
      circularTrackColor: AppColors.lightBorder,
      linearMinHeight: 4,
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: AppColors.lightPrimary.withValues(alpha: 0.08),
      iconColor: AppColors.lightIcon,
      textColor: AppColors.lightOnSurface,
      selectedColor: AppColors.lightPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 24,
      minVerticalPadding: 8,
      style: ListTileStyle.list,
      dense: false,
      enableFeedback: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: AppColors.lightSurface,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: AppColors.lightPrimary,
      collapsedIconColor: AppColors.lightHint,
      textColor: AppColors.lightPrimary,
      collapsedTextColor: AppColors.lightOnSurface,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.lightSurface,
      elevation: 8,
      textStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightOnSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
      labelTextStyle: WidgetStateProperty.all(
        AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightOnSurface,
        ),
      ),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.lightSurface),
        elevation: WidgetStateProperty.all(8),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightOnSurface,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 1,
      indent: 0,
      endIndent: 0,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return AppColors.lightPrimary;
        return AppColors.lightHint.withValues(alpha: 0.5);
      }),
      trackColor: WidgetStateProperty.all(
        AppColors.lightBorder.withValues(alpha: 0.5),
      ),
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(6),
      interactive: true,
    ),

    bannerTheme: MaterialBannerThemeData(
      backgroundColor: AppColors.lightInfoBackground,
      contentTextStyle: AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
        color: AppColors.lightOnSurface,
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leadingPadding: const EdgeInsets.only(right: 12),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.lightSurface,
      headerBackgroundColor: AppColors.lightPrimary,
      headerForegroundColor: AppColors.lightOnPrimary,
      dayStyle: AppTextTheme.lightTextTheme.bodySmall,
      weekdayStyle: AppTextTheme.lightTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightOnPrimary;
        }
        return AppColors.lightOnSurface;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary;
        }
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightOnPrimary;
        }
        return AppColors.lightPrimary;
      }),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 8,
    ),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.lightSurface,
      dialHandColor: AppColors.lightPrimary,
      dialBackgroundColor: AppColors.lightPrimary.withValues(alpha: 0.08),

      hourMinuteColor: AppColors.lightBorder.withValues(alpha: 0.3),

      hourMinuteTextColor: AppColors.lightOnSurface,

      dayPeriodColor: Colors.transparent,

      dayPeriodTextColor: AppColors.lightHint,

      entryModeIconColor: AppColors.lightHint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.lightTableHeader),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.lightPrimary.withValues(alpha: 0.08);
        }
        return Colors.transparent;
      }),
      headingTextStyle: AppTextTheme.lightTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.lightOnSurface,
      ),
      dataTextStyle: AppTextTheme.lightTextTheme.bodySmall?.copyWith(
        color: AppColors.lightOnSurface,
      ),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 16,
      headingRowHeight: 48,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
    ),

    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(AppColors.lightSurface),
      elevation: WidgetStateProperty.all(0),
      textStyle: WidgetStateProperty.all(
        AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightOnSurface,
        ),
      ),
      hintStyle: WidgetStateProperty.all(
        AppTextTheme.lightTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightHint,
        ),
      ),
      side: WidgetStateProperty.all(
        const BorderSide(color: AppColors.lightBorder),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    scaffoldBackgroundColor: AppColors.darkBackground,
    canvasColor: AppColors.darkBackground,
    cardColor: AppColors.darkSurface,
    hintColor: AppColors.darkHint,
    disabledColor: AppColors.darkDisabled,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    splashColor: AppColors.darkPrimary.withValues(alpha: 0.12),
    highlightColor: AppColors.darkPrimary.withValues(alpha: 0.06),
    focusColor: AppColors.darkPrimary.withValues(alpha: 0.16),
    hoverColor: AppColors.darkPrimary.withValues(alpha: 0.06),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkSurface,
      error: AppColors.darkError,
      onPrimary: AppColors.darkOnPrimary,
      onSecondary: AppColors.darkOnSecondary,
      onSurface: AppColors.darkOnSurface,
      onError: AppColors.darkOnError,
    ),

    textTheme: AppTextTheme.darkTextTheme,
    primaryTextTheme: AppTextTheme.darkTextTheme,

    iconTheme: const IconThemeData(
      color: AppColors.darkIcon,
      size: 24,
      opacity: 1.0,
    ),
    primaryIconTheme: const IconThemeData(
      color: AppColors.darkOnPrimary,
      size: 24,
      opacity: 1.0,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkOnSurface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.darkOnSurface, size: 24),
      actionsIconTheme: const IconThemeData(
        color: AppColors.darkOnSurface,
        size: 24,
      ),
      titleTextStyle: AppTextTheme.darkTextTheme.titleLarge?.copyWith(
        color: AppColors.darkOnSurface,
        fontWeight: FontWeight.w600,
      ),
      toolbarTextStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkOnSurface,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      titleSpacing: 16,
      toolbarHeight: 56,
    ),

    bottomAppBarTheme: const BottomAppBarThemeData(
      color: AppColors.darkSurface,
      elevation: 8,
      shape: CircularNotchedRectangle(),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.darkPrimary,
      unselectedLabelColor: AppColors.darkHint,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.darkPrimary, width: 2),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: AppTextTheme.darkTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextTheme.darkTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      overlayColor: WidgetStateProperty.all(
        AppColors.darkPrimary.withValues(alpha: 0.12),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.darkPrimary,
      unselectedItemColor: AppColors.darkHint,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: AppTextTheme.darkTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppTextTheme.darkTextTheme.labelSmall,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedIconTheme: const IconThemeData(
        size: 24,
        color: AppColors.darkPrimary,
      ),
      unselectedIconTheme: const IconThemeData(
        size: 24,
        color: AppColors.darkHint,
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedIconTheme: const IconThemeData(
        color: AppColors.darkPrimary,
        size: 24,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.darkHint,
        size: 24,
      ),
      selectedLabelTextStyle: AppTextTheme.darkTextTheme.labelMedium?.copyWith(
        color: AppColors.darkPrimary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: AppTextTheme.darkTextTheme.labelMedium
          ?.copyWith(color: AppColors.darkHint),
      elevation: 0,
      groupAlignment: -1.0,
      indicatorColor: AppColors.darkPrimary.withValues(alpha: 0.16),
      useIndicator: true,
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 16,
      width: 280,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkChipBackground,
      disabledColor: AppColors.darkDisabled,
      selectedColor: AppColors.darkPrimary.withValues(alpha: 0.16),
      secondarySelectedColor: AppColors.darkSecondary.withValues(alpha: 0.16),
      deleteIconColor: AppColors.darkHint,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      brightness: Brightness.dark,
      elevation: 0,
      pressElevation: 2,
      shape: const StadiumBorder(),
      side: const BorderSide(color: AppColors.darkBorder),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 24,
      alignment: Alignment.center,
      titleTextStyle: AppTextTheme.darkTextTheme.titleLarge?.copyWith(
        color: AppColors.darkOnSurface,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkOnSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      elevation: 16,
      modalElevation: 24,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      modalBackgroundColor: AppColors.darkSurface,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSnackBarBackground,
      contentTextStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkSnackBarContent,
      ),
      actionTextColor: AppColors.darkPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.darkTooltipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: AppTextTheme.darkTextTheme.labelSmall?.copyWith(
        color: AppColors.darkTooltipContent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      preferBelow: true,
      waitDuration: const Duration(milliseconds: 500),
    ),

    elevatedButtonTheme: AppButtonTheme.darkElevatedButton,

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkPrimary,
        textStyle: AppTextTheme.darkTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 44),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkPrimary,
        side: const BorderSide(color: AppColors.darkPrimary, width: 1.5),
        textStyle: AppTextTheme.darkTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(64, 44),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: AppColors.darkOnPrimary,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: AppTextTheme.darkTextTheme.labelLarge?.copyWith(
        color: AppColors.darkOnPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: AppInputTheme.darkInputTheme,

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.darkPrimary;
        if (states.contains(WidgetState.disabled)) {
          return AppColors.darkDisabled;
        }
        return AppColors.darkHint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkPrimary.withValues(alpha: 0.5);
        }
        if (states.contains(WidgetState.disabled)) {
          return AppColors.darkDisabled;
        }
        return AppColors.darkBorder;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkPrimary.withValues(alpha: 0.12);
        }
        return AppColors.darkHint.withValues(alpha: 0.08);
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.darkPrimary;
        if (states.contains(WidgetState.disabled)) {
          return AppColors.darkDisabled;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.darkOnPrimary),
      overlayColor: WidgetStateProperty.all(
        AppColors.darkPrimary.withValues(alpha: 0.12),
      ),
      side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.darkPrimary;
        if (states.contains(WidgetState.disabled)) {
          return AppColors.darkDisabled;
        }
        return AppColors.darkBorder;
      }),
      overlayColor: WidgetStateProperty.all(
        AppColors.darkPrimary.withValues(alpha: 0.12),
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.darkPrimary,
      inactiveTrackColor: AppColors.darkBorder,
      thumbColor: AppColors.darkPrimary,
      overlayColor: AppColors.darkPrimary.withValues(alpha: 0.16),
      valueIndicatorColor: AppColors.darkPrimary,
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      valueIndicatorTextStyle: AppTextTheme.darkTextTheme.labelSmall?.copyWith(
        color: AppColors.darkOnPrimary,
      ),
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
      activeTickMarkColor: AppColors.darkPrimary.withValues(alpha: 0.5),
      inactiveTickMarkColor: AppColors.darkBorder,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.darkPrimary,
      linearTrackColor: AppColors.darkBorder,
      circularTrackColor: AppColors.darkBorder,
      linearMinHeight: 4,
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: AppColors.darkPrimary.withValues(alpha: 0.12),
      iconColor: AppColors.darkIcon,
      textColor: AppColors.darkOnSurface,
      selectedColor: AppColors.darkPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 24,
      minVerticalPadding: 8,
      style: ListTileStyle.list,
      dense: false,
      enableFeedback: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: AppColors.darkSurface,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: AppColors.darkPrimary,
      collapsedIconColor: AppColors.darkHint,
      textColor: AppColors.darkPrimary,
      collapsedTextColor: AppColors.darkOnSurface,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.darkSurface,
      elevation: 8,
      textStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkOnSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
      labelTextStyle: WidgetStateProperty.all(
        AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
          color: AppColors.darkOnSurface,
        ),
      ),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.darkSurface),
        elevation: WidgetStateProperty.all(8),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkOnSurface,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 1,
      indent: 0,
      endIndent: 0,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return AppColors.darkPrimary;
        return AppColors.darkHint.withValues(alpha: 0.4);
      }),
      trackColor: WidgetStateProperty.all(
        AppColors.darkBorder.withValues(alpha: 0.3),
      ),
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(6),
      interactive: true,
    ),

    bannerTheme: MaterialBannerThemeData(
      backgroundColor: AppColors.darkInfoBackground,
      contentTextStyle: AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
        color: AppColors.darkOnSurface,
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leadingPadding: const EdgeInsets.only(right: 12),
    ),

    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.darkSurface,
      headerBackgroundColor: AppColors.darkPrimary,
      headerForegroundColor: AppColors.darkOnPrimary,
      dayStyle: AppTextTheme.darkTextTheme.bodySmall,
      weekdayStyle: AppTextTheme.darkTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkOnPrimary;
        }
        return AppColors.darkOnSurface;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.darkPrimary;
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkOnPrimary;
        }
        return AppColors.darkPrimary;
      }),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 8,
    ),

    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.darkSurface,
      dialHandColor: AppColors.darkPrimary,
      dialBackgroundColor: AppColors.darkPrimary.withValues(alpha: 0.12),

      hourMinuteColor: AppColors.darkBorder.withValues(alpha: 0.2),
      hourMinuteTextColor: AppColors.darkOnSurface,

      dayPeriodColor: Colors.transparent,
      dayPeriodTextColor: AppColors.darkHint,

      entryModeIconColor: AppColors.darkHint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.darkTableHeader),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkPrimary.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
      headingTextStyle: AppTextTheme.darkTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.darkOnSurface,
      ),
      dataTextStyle: AppTextTheme.darkTextTheme.bodySmall?.copyWith(
        color: AppColors.darkOnSurface,
      ),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 16,
      headingRowHeight: 48,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
    ),

    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(AppColors.darkSurface),
      elevation: WidgetStateProperty.all(0),
      textStyle: WidgetStateProperty.all(
        AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
          color: AppColors.darkOnSurface,
        ),
      ),
      hintStyle: WidgetStateProperty.all(
        AppTextTheme.darkTextTheme.bodyMedium?.copyWith(
          color: AppColors.darkHint,
        ),
      ),
      side: WidgetStateProperty.all(
        const BorderSide(color: AppColors.darkBorder),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),
  );
}
