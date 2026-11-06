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

class VnItemDetailLabel extends ConsumerWidget {
  const VnItemDetailLabel({
    super.key,
    required this.p1,
    required this.labelCode,
  });

  final VnDataPhase01 p1;
  final String labelCode;

  String _getLabelData(String label, {VnRecord? record}) {
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
      'orig' => 'Original',
      'seq' => 'Sequel',
      'preq' => 'Prequel',
      'ser' => 'Same Series',
      'set' => 'Same Setting',
      'char' => 'Characters',
      'fan' => 'Fandisc',
      'side' => 'Side Story',
      'alt' => 'Alternative',
      _ => toBeginningOfSentenceCase<String>('Unknown'),
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
      labelText: _getLabelData(labelCode, record: record),
    );
  }
}
