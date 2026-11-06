import 'package:flutter/material.dart';
import 'package:vndb_lite/src/common_widgets/custom_dialog_button.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/util/app_text.dart';

import '../../../../util/context_shortcut.dart';

class VnSelectionInprogress extends StatelessWidget {
  const VnSelectionInprogress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: ShadowText(
            appText(context, 'Add to collection', 'コレクションに追加'),
            fontSize: responsiveUI.catgTitle,
            fontWeight: FontWeight.bold,
          ),
        ),
        Divider(
          color: kColor(context).tertiary,
          height: responsiveUI.own(0.05),
        ),
        ShadowText(
          appText(
            context,
            'Please wait until the current process is complete. Thank you :3',
            '処理が終わるまでお待ちください。',
          ),
        ),
        SizedBox(height: responsiveUI.own(0.025)),
        CustomDialogButton(
          text: appText(context, 'Okay', '閉じる'),
          textColor: kColor(context).primary,
          color: kColor(context).tertiary,
          onPressed: Navigator.of(context).pop,
          textShadow: const [
            Shadow(color: Color.fromARGB(120, 0, 0, 0), blurRadius: 1),
          ],
        ),
      ],
    );
  }
}
