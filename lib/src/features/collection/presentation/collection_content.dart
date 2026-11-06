import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vndb_lite/src/common_widgets/generic_local_empty_content.dart';
import 'package:vndb_lite/src/features/_base/presentation/main_outer_layout.dart';
import 'package:vndb_lite/src/features/_base/presentation/other_parts/main_inner_layout.dart';
import 'package:vndb_lite/src/features/collection/presentation/collection_content_controller.dart';
import 'package:vndb_lite/src/util/alt_provider_reader.dart';
import 'package:vndb_lite/src/util/context_shortcut.dart';
import 'package:vndb_lite/src/util/responsive.dart';
import 'package:vndb_lite/src/features/settings/presentation/settings_general_state.dart';
import 'package:vndb_lite/src/features/sort_filter/data/sortable_data.dart';
import 'package:vndb_lite/src/features/sort_filter/presentation/local/local_sort_filter_controller.dart';

class CollectionContent extends ConsumerStatefulWidget {
  const CollectionContent({super.key, required this.statusName});

  final String statusName;

  static final boundary = kScreenHeight();

  @override
  ConsumerState<CollectionContent> createState() => _CollectionContentState();
}

class _CollectionContentState extends ConsumerState<CollectionContent> {
  late final ScrollController _scrollController;

  String get statusName => widget.statusName;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(keepScrollOffset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _forceUpdateUI() {
    ref.read(collectionContentNotifierProvider.notifier).end();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsGeneralStateProvider);

    final content =
        ref.watch(collectionContentControllerProvider)[statusName] ?? [];
    final notifyCollection = ref.watch(collectionContentNotifierProvider);
    final customOrder =
        ref.watch(localSortControllerProvider).sort == SortableCode.custom.name;
    final groupByDeveloper =
        settings.groupCollectionByDeveloper && !customOrder;
    final rawById = {
      for (final raw in rawP1BasedOnStatus[statusName] ?? [])
        raw['id'] as String: raw,
    };
    final developerGroups = <String, List<Widget>>{};
    if (groupByDeveloper) {
      for (final item in content) {
        final developers = rawById[item.p1.id]?['devs'] as List<dynamic>?;
        final name =
            developers == null || developers.isEmpty
                ? 'Unknown developer'
                : developers.first as String;
        (developerGroups[name] ??= []).add(item);
      }
    }

    final crossAxisCount =
        MediaQuery.of(context).orientation == Orientation.portrait
            ? settings.maxItemPerRowPortrait
            : settings.maxItemPerRowLandscape;

    SliverPadding grid(
      List<Widget> items, {
      bool allowReorder = false,
    }) => SliverPadding(
      padding: EdgeInsets.only(
        left: responsiveUI.own(0.025),
        right: responsiveUI.own(0.025),
        top: responsiveUI.own(0.04),
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: responsiveUI.own(0.03),
          crossAxisSpacing: responsiveUI.own(0.03),
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate((_, index) {
          if (!allowReorder || !customOrder) return items[index];

          return DragTarget<int>(
            onAcceptWithDetails:
                (details) => ref
                    .read(collectionContentControllerProvider.notifier)
                    .reorderCustom(statusName, details.data, index),
            builder:
                (_, candidates, __) => AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: candidates.isEmpty ? 1 : 0.94,
                  child: Stack(
                    children: [
                      items[index],
                      Positioned(
                        top: 6,
                        right: 6,
                        child: LongPressDraggable<int>(
                          data: index,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Icon(
                              Icons.drag_indicator,
                              size: 48,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.drag_indicator, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          );
        }, childCount: items.length),
      ),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (notifyCollection) _forceUpdateUI();
    });

    return ScrollableWrapper(
      withScrollBar: false,
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        child: CustomScrollView(
          key: PageStorageKey<String>('collection-$statusName'),
          controller: _scrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          // controller: (App.isInCollectionScreen) ? controller : null,
          // shrinkWrap: false,
          // physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (content.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: GenericLocalEmptyWidget(),
                  ),
                ),
              )
            else if (groupByDeveloper) ...[
              for (final group in developerGroups.entries) ...[
                if (settings.showCollectionDeveloperHeaders)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: responsiveUI.own(0.04),
                        right: responsiveUI.own(0.04),
                        top: responsiveUI.own(0.05),
                      ),
                      child: Text(
                        group.key,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                grid(group.value),
              ],
            ] else
              grid(content, allowReorder: true),
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MainOuterLayout.bottomPadding +
                    MediaQuery.paddingOf(context).bottom +
                    64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
