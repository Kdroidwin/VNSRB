import 'package:vndb_lite/src/common_widgets/generic_shadowy_text.dart';
import 'package:vndb_lite/src/util/app_text.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:flutter/material.dart';

class GenericFailureConnection extends StatelessWidget {
  const GenericFailureConnection({super.key, this.customMessage});

  final String? customMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShadowText(
        customMessage ??
            appText(
              context,
              "There seems to be a connection error. Please try again later! :D",
              "通信エラーが発生しました。時間をおいてもう一度お試しください。",
            ),
        color: Colors.red,
        fontSize: responsiveUI.normalSize,
        align: TextAlign.center,
      ),
    );
  }
}
