import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:vndb_lite/src/features/_base/presentation/upper_parts/tabs_sliver_appbar.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_appbar_tabs.dart';
import 'package:vndb_lite/src/features/sort_filter/presentation/local/local_sort_filter_controller.dart';
import 'package:vndb_lite/src/routing/app_router.dart';
import 'package:vndb_lite/src/features/_base/presentation/lower_parts/bottom_progress_indicator_state.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_content.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_content_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  static bool tabInitialized = false;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  bool _collectionLoaded = false;
  bool _collectionLoading = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(bottomProgressIndicatorProvider)) _loadCollection();
    });
  }

  void _loadCollection() {
    if (_collectionLoaded || _collectionLoading) return;
    _collectionLoading = true;
    final filterData = ref.read(localFilterControllerProvider);
    final sortData = ref.read(localSortControllerProvider);
    unawaited(
      ref
          .read(collectionContentControllerProvider.notifier)
          .separateVNsByStatus(filterData, sortData)
          .whenComplete(() {
            _collectionLoading = false;
            _collectionLoaded = true;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bottomProgressIndicatorProvider, (previous, next) {
      if (previous == true && !next) _loadCollection();
    });
    final settings = ref.watch(settingsGeneralStateProvider);
    final statusArrangement = settings.collectionStatusTabArrangement;

    return NestedScrollView(
      floatHeaderSlivers: false,
      headerSliverBuilder:
          (_, __) => const [TabAppBar(route: AppRoute.collection)],
      body: TabBarView(
        controller: CollectionAppBarTabs.controller,
        children: [
          for (String statusName in statusArrangement)
            CollectionContent(key: Key(statusName), statusName: statusName),
        ],
      ),
    );
  }
}
