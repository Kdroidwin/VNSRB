import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vndb_lite/src/app.dart';
import 'package:vndb_lite/src/common_widgets/status_label.dart';
import 'package:vndb_lite/src/features/collection/domain/record.dart';
import 'package:vndb_lite/src/features/sort_filter/data/sortable_data.dart';
import 'package:vndb_lite/src/features/vn/data/local_vn_repo.dart';
import 'package:vndb_lite/src/features/vn/domain/p1.dart';
import 'package:vndb_lite/src/features/vn_item/presentation/detail_non_summary/vn_record_state.dart';
import 'package:vndb_lite/src/util/format_minutes.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/util/app_text.dart';

class VnItemDetailLabel extends ConsumerWidget {
  const VnItemDetailLabel({
    super.key,
    required this.p1,
    required this.labelCode,
  });

  final VnDataPhase01 p1;
  final String labelCode;

  String _getLabelData(
    BuildContext context,
    String label, {
    VnRecord? record,
  }) {
    final code = label.toLowerCase();
    if (code == SortableCode.title.name || code.isEmpty) return '';
    if (code == SortableCode.rating.name) {
      return (p1.rating! / 10).toStringAsFixed(2);
    }
    if (code == SortableCode.votecount.name) return p1.votecount.toString();
    if (code == SortableCode.released.name) return p1.released!;
    if (code == SortableCode.collection.name && record != null) {
      return record.status;
    }
    if (code == SortableCode.vote.name && record != null) {
      return record.vote.toString();
    }

    final formatter = DateFormat.yMd();
    if (code == SortableCode.added.name &&
        record?.added != null &&
        record!.added != 'null') {
      return formatter.format(DateTime.parse(record.added!));
    }
    if (code == SortableCode.started.name &&
        record?.started != null &&
        record!.started != 'null') {
      return formatter.format(DateTime.parse(record.started!));
    }

    return switch (code) {
      'orig' => appText(context, 'Original', '原作'),
      'seq' => appText(context, 'Sequel', '続編'),
      'preq' => appText(context, 'Prequel', '前編'),
      'ser' => appText(context, 'Same Series', '同シリーズ'),
      'set' => appText(context, 'Same Setting', '同じ世界観'),
      'char' => appText(context, 'Characters', '登場人物'),
      'fan' => appText(context, 'Fandisc', 'ファンディスク'),
      'side' => appText(context, 'Side Story', '外伝'),
      'alt' => appText(context, 'Alternative', '別バージョン'),
      _ => appText(context, 'Unknown', '不明'),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (labelCode == SortableCode.title.name || labelCode.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDateLabel =
        labelCode == SortableCode.released.name ||
        labelCode == SortableCode.added.name ||
        labelCode == SortableCode.started.name;
    if (App.isInCollectionScreen &&
        isDateLabel &&
        !ref.watch(settingsGeneralStateProvider).showCollectionCoverDates) {
      return const SizedBox.shrink();
    }

    // These labels come from P1 or a fixed label. Avoid querying and decoding
    // each VN's local collection record while creating grid cards.
    final needsRecord =
        labelCode == SortableCode.collection.name ||
        labelCode == SortableCode.vote.name ||
        labelCode == SortableCode.added.name ||
        labelCode == SortableCode.started.name;
    final VnRecord? record =
        needsRecord ? ref.watch(vnRecordStateProvider(p1.id)) : null;

    if (labelCode == SortableCode.length_minutes.name) {
      return FutureBuilder(
        future: ref.read(localVnRepoProvider).getP2(p1.id),
        initialData: null,
        builder: (context, snapshot) {
          return StatusLabel(
            labelCode: labelCode,
            labelText: getVnLength(snapshot.data?.length_minutes),
          );
        },
      );
    }

    return StatusLabel(
      labelCode:
          (labelCode == SortableCode.collection.name && record != null)
              ? record.status
              : labelCode,
      labelText: _getLabelData(context, labelCode, record: record),
    );
  }
}
