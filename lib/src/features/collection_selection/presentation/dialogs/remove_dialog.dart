import 'package:flutter/material.dart';
import 'package:vndb_lite/src/common_widgets/custom_dialog.dart';
import 'package:vndb_lite/src/common_widgets/custom_dialog_button.dart';
import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/core/app/navigation.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/util/app_text.dart';

Future<void> confirmVnRemovalDialog(VoidCallback removeVn) {
  return showDialog(
    context: NavigationService.currentContext,
    builder: (BuildContext context) {
      return CustomDialog(
        useContentPadding: true,
        content: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              child: ShadowText(
                appText(
                  context,
                  'Remove Visual Novel from collection?',
                  'この作品をコレクションから削除しますか？',
                ),
                fontSize: responsiveUI.catgTitle,
              ),
            ),
            SizedBox(height: responsiveUI.own(0.03)),
            Container(
              alignment: Alignment.centerRight,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  //
                  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  // Confirm button
                  CustomDialogButton(
                    text: appText(context, 'Yep', '削除する'),
                    color: const Color.fromARGB(180, 255, 20, 0),
                    onPressed: removeVn,
                  ),

                  //
                  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  // Cancel button
                  CustomDialogButton(
                    text: appText(context, 'Cancel', 'キャンセル'),
                    color: Colors.transparent,
                    onPressed: Navigator.of(context).pop,
                  ),
                  //
                  // %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                  //
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
