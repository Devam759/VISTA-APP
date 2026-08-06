import 'package:flutter/material.dart';
import '../../../widgets/common/skeleton_loader.dart';
import 'warden_components.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WARDEN TAB SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────
class WardenTabScaffold<T> extends StatefulWidget {
  final String? title;
  final String? sectionTitle;
  final List<String> tabs;
  final Widget? actionWidget;
  final String? searchHint;
  final String searchQueryPlaceholder;
  
  // Generic list mode
  final Stream<List<T>> Function()? streamFactory;
  final Widget Function(BuildContext, T)? itemBuilder;
  final Widget Function(BuildContext, T, int)? indexedItemBuilder;
  final Widget Function(BuildContext, List<T>)? listBuilder;
  final bool Function(T, String, String)? filterLogic;
  
  final List<Widget>? children;
  final TabController? tabController;
  final TextEditingController? searchCtrl;
  final Widget? extraHeader;
  final Widget Function(BuildContext, List<T>)? extraHeaderBuilder;
  final Widget? loadingWidget;

  // Empty state customization
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;
  final bool showCount;

  const WardenTabScaffold({
    super.key,
    this.title,
    this.sectionTitle,
    required this.tabs,
    this.actionWidget,
    this.searchHint,
    this.searchQueryPlaceholder = 'Search...',
    this.streamFactory,
    this.itemBuilder,
    this.indexedItemBuilder,
    this.listBuilder,
    this.filterLogic,
    this.children,
    this.tabController,
    this.searchCtrl,
    this.extraHeader,
    this.extraHeaderBuilder,
    this.loadingWidget,
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
    this.showCount = false,
  });

  @override
  State<WardenTabScaffold<T>> createState() => _WardenTabScaffoldState<T>();
}

class _WardenTabScaffoldState<T> extends State<WardenTabScaffold<T>> with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = widget.tabController ?? TabController(length: widget.tabs.length, vsync: this);
    _searchCtrl = widget.searchCtrl ?? TextEditingController();
    
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (widget.tabController == null) _tabController.dispose();
    if (widget.searchCtrl == null) _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: widget.searchHint ?? widget.searchQueryPlaceholder,
                          hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.search_rounded, color: kPrimary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.extraHeader != null) widget.extraHeader!,
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              height: 48,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicator: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(25)),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black45,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                dividerColor: Colors.transparent,
                onTap: (index) {
                  _tabController.animateTo(index);
                  setState(() {});
                },
                tabs: widget.tabs.map((t) => Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(t)))).toList(),
              ),
            ),
            if (widget.sectionTitle != null || widget.title != null)
              WardenSectionLabel(
                widget.sectionTitle ?? widget.title ?? '',
                animate: false,
                actionWidget: widget.actionWidget,
              ), // Keep header static on rebuilds
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: widget.children ?? widget.tabs.map((tab) => _GenericFilteredList<T>(
                  key: ValueKey('tab_$tab'),
                  tab: tab,
                  query: _searchCtrl.text,
                  sectionTitle: widget.sectionTitle,
                  showCount: widget.showCount,
                  streamFactory: widget.streamFactory!,
                  itemBuilder: widget.itemBuilder,
                  indexedItemBuilder: widget.indexedItemBuilder,
                  listBuilder: widget.listBuilder,
                  filterLogic: widget.filterLogic!,
                  extraHeaderBuilder: widget.extraHeaderBuilder,
                  loadingWidget: widget.loadingWidget,
                  emptyIcon: widget.emptyIcon,
                  emptyTitle: widget.emptyTitle,
                  emptySubtitle: widget.emptySubtitle,
                )).toList(),
              ),
            ),
          ],
        ),
    );
  }
}

class _GenericFilteredList<T> extends StatefulWidget {
  final String tab;
  final String query;
  final String? sectionTitle;
  final Stream<List<T>> Function() streamFactory;
  final Widget Function(BuildContext, T)? itemBuilder;
  final Widget Function(BuildContext, T, int)? indexedItemBuilder;
  final Widget Function(BuildContext, List<T>)? listBuilder;
  final bool Function(T, String, String) filterLogic;
  final Widget Function(BuildContext, List<T>)? extraHeaderBuilder;
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;
  final bool showCount;
  final Widget? loadingWidget;

  const _GenericFilteredList({
    super.key,
    required this.tab,
    required this.query,
    this.sectionTitle,
    required this.streamFactory,
    this.itemBuilder,
    this.indexedItemBuilder,
    this.listBuilder,
    required this.filterLogic,
    this.extraHeaderBuilder,
    this.loadingWidget,
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
    required this.showCount,
  });

  @override
  State<_GenericFilteredList<T>> createState() => _GenericFilteredListState<T>();
}

class _GenericFilteredListState<T> extends State<_GenericFilteredList<T>> with AutomaticKeepAliveClientMixin {
  late Stream<List<T>> _stream;
  int _currentPage = 1;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _stream = widget.streamFactory();
  }

  @override
  void didUpdateWidget(covariant _GenericFilteredList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Query and tab changes filter the stream in-memory in build().
    // Only recreate the Firestore stream if streamFactory changed.
    if (widget.streamFactory != oldWidget.streamFactory) {
      _stream = widget.streamFactory();
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildPaginationBar(int totalItems, int totalPages, int startIndex, int endIndex) {
    if (totalItems <= _pageSize) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev button
              InkWell(
                onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _currentPage > 1 ? kPrimary.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: _currentPage > 1 ? kPrimary : Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Page Pills
              ...List.generate(totalPages, (i) {
                final pageNum = i + 1;
                final isActive = pageNum == _currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _currentPage = pageNum),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isActive ? null : Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isActive ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 8),
              // Next button
              InkWell(
                onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _currentPage < totalPages ? kPrimary.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _currentPage < totalPages ? kPrimary : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<T>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? const StudentListSkeleton();
        }

        final allItems = snapshot.data ?? [];
        final filtered = allItems.where((item) => widget.filterLogic(item, widget.tab, widget.query)).toList();

        if (filtered.isEmpty) {
          final emptyWidget = WardenEmptyState(
            icon: widget.emptyIcon ?? (widget.query.isEmpty ? Icons.inbox_rounded : Icons.search_off_rounded),
            title: widget.emptyTitle ?? (widget.query.isEmpty ? 'No results in ${widget.tab}' : 'No matches found'),
            subtitle: widget.emptySubtitle ?? (widget.query.isEmpty ? 'There are no items to show here at the moment.' : 'Try adjusting your search query.'),
          );
          if (widget.extraHeaderBuilder != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.extraHeaderBuilder!(context, filtered),
                Expanded(child: emptyWidget),
              ],
            );
          }
          return emptyWidget;
        }

        final totalItems = filtered.length;
        final totalPages = (totalItems / _pageSize).ceil() == 0 ? 1 : (totalItems / _pageSize).ceil();
        if (_currentPage > totalPages) _currentPage = totalPages;
        if (_currentPage < 1) _currentPage = 1;

        final startIndex = (_currentPage - 1) * _pageSize;
        final endIndex = (startIndex + _pageSize > totalItems) ? totalItems : startIndex + _pageSize;
        final pageItems = (startIndex < totalItems) ? filtered.sublist(startIndex, endIndex) : <T>[];

        Widget content;
        if (widget.listBuilder != null) {
          content = ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              widget.listBuilder!(context, pageItems),
              _buildPaginationBar(totalItems, totalPages, startIndex, endIndex),
            ],
          );
        } else {
          content = ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == pageItems.length) {
                return _buildPaginationBar(totalItems, totalPages, startIndex, endIndex);
              }

              final itemGlobalIndex = startIndex + index + 1;
              if (widget.indexedItemBuilder != null) {
                return widget.indexedItemBuilder!(context, pageItems[index], itemGlobalIndex);
              }
              return widget.itemBuilder!(context, pageItems[index]);
            },
          );
        }

        if (widget.extraHeaderBuilder != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.extraHeaderBuilder!(context, filtered),
              Expanded(child: content),
            ],
          );
        }

        return content;
      },
    );
  }
}
