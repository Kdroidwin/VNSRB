import 'package:flutter/material.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/features/sort_filter/data/languages_data.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn/domain/p2.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/util/app_text.dart';

class VnDetailReleasesLang extends StatelessWidget {
  const VnDetailReleasesLang({super.key, required this.p1, required this.p2});

  final VnDataPhase01 p1;
  final VnDataPhase02 p2;

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  List<Widget> _flagWidgets(BuildContext context) {
    final List<Widget> languageData = [];

    for (String language in (p2.languages ?? [])) {
      // Original language will be processed later on.
      if (language != p1.olang) {
        languageData.add(_flagLangCode(language));
      }
    }

    for (String language in (p2.mtl ?? [])) {
      languageData.add(
        _flagLangCode(
          language,
          txt: appText(context, '(Machine Translation)', '(機械翻訳)'),
        ),
      );
    }

    return languageData;
  }

  //
  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  //

  Widget _flagLangCode(String langCode, {String txt = ''}) {
    //
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          LangData.getFlagPath(langCode),
          height: responsiveUI.own(0.038),
          width: responsiveUI.own(0.055),
          fit: BoxFit.fill,
        ),
        ShadowText('  ${LangData.getFullLanguage(langCode)} $txt'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadowText(
          appText(context, 'Languages', '言語'),
          fontSize: responsiveUI.own(0.045),
          fontWeight: FontWeight.bold,
        ),
        SizedBox(height: responsiveUI.own(0.01)),
        Row(
          children: [
            _flagLangCode(p1.olang!),
            ShadowText(
              ' ${appText(context, '(Origin)', '(原語)')}',
              fontWeight: FontWeight.bold,
              fontSize: responsiveUI.normalSize,
              color: kColor(context).secondary,
              shadows: [
                Shadow(
                  color: Color.alphaBlend(
                    Colors.black.withOpacity(0.5),
                    kColor(context).primary,
                  ),
                  blurRadius: 15,
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _flagWidgets(context),
        ),
      ],
    );
  }
}
