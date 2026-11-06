import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vndb_lite/src/common_widgets/custom_label.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/constants/defaults.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/_base/presentation/upper_parts/buttons/refresh_button.dart';
import 'package:vndb_lite/src/features/settings/presentation/components/settings_list_theme_selection.dart';
import 'package:vndb_lite/src/features/settings/presentation/dialog/settings_dialog.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_theme_state.dart';
import 'package:vndb_lite/src/features/theme/theme_data_provider.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/util/app_text.dart';
import 'package:vndb_lite/src/constants/local_db_constants.dart';
import 'package:vndb_lite/src/core/local_db/shared_prefs.dart';

class SettingsTheme extends ConsumerStatefulWidget {
  const SettingsTheme({super.key});

  @override
  ConsumerState<SettingsTheme> createState() => _SettingsDataState();
}

class _SettingsDataState extends ConsumerState<SettingsTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _offsetAnimation = _animationController
        .drive(CurveTween(curve: Curves.easeInOut))
        .drive(
          Tween<Offset>(begin: const Offset(0, -0.5), end: const Offset(0, 0)),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _refreshApp() async {
    await AppBarRefreshButton.tap();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _changeTheme() async {
    await showSettingsDialog(
      title: appText(context, 'Change App Theme', 'アプリテーマの変更'),
      content: ListThemeSelection(refresh: _refreshApp),
    );
  }

  Future<void> _selectCustomBackground() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final extension = image.path.split('.').last;
    final destination = File(
      '${directory.path}/vnpockets_background.$extension',
    );
    await File(image.path).copy(destination.path);
    final preferences = ref.read(sharedPrefProvider);
    await preferences.setString(
      DBKeys.CUSTOM_BACKGROUND_PATH,
      destination.path,
    );
    ref.read(customBackgroundPathProvider.notifier).update(destination.path);
  }

  Future<void> _clearCustomBackground() async {
    final preferences = ref.read(sharedPrefProvider);
    await preferences.remove(DBKeys.CUSTOM_BACKGROUND_PATH);
    ref.read(customBackgroundPathProvider.notifier).update(null);
  }

  Future<void> _setJapaneseTitles(bool enabled) async {
    await ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.JAPANESE_TITLES_CONF, enabled);
    ref.read(japaneseTitlesProvider.notifier).update(enabled);
  }

  Future<void> _setJapaneseUi(bool enabled) async {
    await ref
        .read(sharedPrefProvider)
        .setBool(DBKeys.JAPANESE_UI_CONF, enabled);
    ref.read(japaneseUiProvider.notifier).update(enabled);
  }

  Future<void> _changeAmoledAccent() async {
    final controller = TextEditingController(
      text: ref.read(amoledAccentHexProvider),
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    appText(context, 'AMOLED accent color', 'AMOLEDアクセントカラー'),
                  ),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Hex color', 'カラーコード'),
                      hintText: '#BB86FC',
                      errorText:
                          error == null
                              ? null
                              : appText(
                                context,
                                'Use a 6-digit color, e.g. #BB86FC',
                                '6桁のカラーコードを入力してください（例: #BB86FC）',
                              ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(appText(context, 'Cancel', 'キャンセル')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final hex = controller.text.trim();
                        final normalized = hex.replaceFirst('#', '');
                        if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
                          setDialogState(
                            () => error = 'Use a 6-digit color, e.g. #BB86FC',
                          );
                          return;
                        }
                        final value = '#${normalized.toUpperCase()}';
                        await ref
                            .read(sharedPrefProvider)
                            .setString(DBKeys.AMOLED_ACCENT_COLOR, value);
                        ref
                            .read(amoledAccentHexProvider.notifier)
                            .update(value);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Text(appText(context, 'Apply', '適用')),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Future<void> _changeFontSize() async {
    double tempFontSize = ref.read(settingsThemeStateProvider).fontSize;

    await showSettingsDialog(
      title: appText(context, 'Change Font Size', '文字サイズの変更'),
      yesOrNo: true,
      yesFunction: () async {
        ref.read(settingsThemeStateProvider.notifier).fontSize = tempFontSize;
        await _refreshApp();
      },
      content: StatefulBuilder(
        builder: (ctx, setState) {
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  right: responsiveUI.own(0.05),
                  left: responsiveUI.own(0.05),
                  bottom: responsiveUI.own(0.03),
                ),
                child: ShadowText(
                  appText(
                    ctx,
                    'You would have to restart the app for the configured change to take effect.',
                    '設定を反映するにはアプリの再起動が必要です。',
                  ),
                ),
              ),
              SizedBox(height: responsiveUI.own(0.03)),
              // Text as a countermeasure.
              ShadowText(
                '"VN stands for Visual Novel."',
                fontSize: responsiveUI.own(
                  Default.FONT_SIZE_CONF + tempFontSize,
                  withCustom: false,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  value: tempFontSize,
                  divisions: 5,
                  min: -0.006,
                  max: 0.004,
                  onChanged: (val) {
                    setState(() => tempFontSize = val);
                  },
                  thumbColor: kColor(context).secondary,
                  activeColor: Color.alphaBlend(
                    kColor(context).tertiary.withOpacity(0.4),
                    kColor(context).primary,
                  ),
                  label: _getUserFriendlyFontSize(tempFontSize),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  String _getUserFriendlyFontSize(double fontSize) {
    if (fontSize <= -0.006) return appText(context, 'Tiny', '極小');
    if (fontSize <= -0.004) return appText(context, 'Smaller', '小さめ');
    if (fontSize <= -0.002) return appText(context, 'Small', '小');
    if (fontSize <= 0) return appText(context, 'Medium', '標準');
    if (fontSize <= 0.002) return appText(context, 'Big', '大');
    return appText(context, 'Bigger', '大きめ');
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsThemeStateProvider);
    final customBackgroundPath = ref.watch(customBackgroundPathProvider);
    final japaneseTitles = ref.watch(japaneseTitlesProvider);
    final japaneseUi = ref.watch(japaneseUiProvider);
    final amoledAccent = ref.watch(amoledAccentHexProvider);
    final isAmoled = ref.watch(appThemeStateProvider).isAmoled;

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _animationController.drive(
          CurveTween(curve: Curves.easeInToLinear),
        ),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.all(responsiveUI.own(0.04)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Font Size
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _changeFontSize(),
                children: [
                  ShadowText(japaneseUi ? '文字サイズ: ' : 'Font size: '),
                  ShadowText(
                    _getUserFriendlyFontSize(settings.fontSize),
                    fontSize: responsiveUI.normalSize,
                    color: kColor(context).tertiary.withAlpha(180),
                  ),
                ],
              ),

              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: _selectCustomBackground,
                children: [
                  ShadowText(japaneseUi ? 'カスタム背景: ' : 'Custom background: '),
                  ShadowText(
                    customBackgroundPath == null
                        ? (japaneseUi ? '画像を選択' : 'Choose image')
                        : (japaneseUi ? '有効' : 'Enabled'),
                    fontWeight: FontWeight.bold,
                    fontSize: responsiveUI.normalSize,
                    color: kColor(context).secondary,
                  ),
                ],
              ),
              if (customBackgroundPath != null)
                TextButton.icon(
                  onPressed: _clearCustomBackground,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    japaneseUi ? 'カスタム背景を削除' : 'Remove custom background',
                  ),
                ),

              SizedBox(height: responsiveUI.own(0.03)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  japaneseUi ? '日本語のタイトルを表示' : 'Show Japanese titles',
                ),
                subtitle: Text(
                  japaneseUi
                      ? 'VNDB に登録されている場合、日本語タイトルを使用します'
                      : 'Use Japanese VN titles when VNDB provides them',
                ),
                value: japaneseTitles,
                onChanged: _setJapaneseTitles,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(japaneseUi ? '日本語UI' : 'Japanese UI'),
                subtitle: Text(
                  japaneseUi
                      ? '対応している画面の日本語表示を有効にします'
                      : 'Enable Japanese labels where available',
                ),
                value: japaneseUi,
                onChanged: _setJapaneseUi,
              ),

              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              // Change theme
              SizedBox(height: responsiveUI.own(0.03)),
              CustomLabel(
                useBorder: true,
                borderRadius: 12,
                isSelected: false,
                borderColor: kColor(context).secondary,
                padding: EdgeInsets.all(responsiveUI.own(0.02)),
                onTap: () async => await _changeTheme(),
                children: [
                  ShadowText(japaneseUi ? 'テーマ: ' : 'Theme: '),
                  ShadowText(
                    ref.watch(appThemeStateProvider).themeName,
                    fontWeight: FontWeight.bold,
                    fontSize: responsiveUI.normalSize,
                    color: kColor(context).secondary,
                  ),
                ],
              ),
              if (isAmoled) ...[
                SizedBox(height: responsiveUI.own(0.03)),
                CustomLabel(
                  useBorder: true,
                  borderRadius: 12,
                  isSelected: false,
                  borderColor: kColor(context).secondary,
                  padding: EdgeInsets.all(responsiveUI.own(0.02)),
                  onTap: _changeAmoledAccent,
                  children: [
                    ShadowText(japaneseUi ? 'アクセントカラー: ' : 'Accent color: '),
                    ShadowText(
                      amoledAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: responsiveUI.normalSize,
                      color: kColor(context).secondary,
                    ),
                  ],
                ),
              ],
              //
              // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
              //
            ],
          ),
        ),
      ),
    );
  }
}
