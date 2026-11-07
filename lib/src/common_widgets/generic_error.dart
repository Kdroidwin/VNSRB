import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/util/app_text.dart';
import 'package:flutter/material.dart';

class GenericError extends StatelessWidget {
  const GenericError({super.key, this.customMessage});

  final String? customMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShadowText(
        customMessage ??
            appText(context, "There seems to be an error... :(", "エラーが発生しました。"),
        color: Colors.red,
        fontSize: responsiveUI.normalSize,
        align: TextAlign.center,
      ),
    );
  }
}
