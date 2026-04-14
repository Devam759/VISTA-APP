import 'package:flutter/material.dart';
import '../../../widgets/skeleton_loader.dart';
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
                  if (widget.actionWidget != null) ...[
                    const SizedBox(width: 12),
                    widget.actionWidget!,
                  ],
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
                dividerHeight: 0,
                tabs: widget.tabs.map((t) => Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(t)))).toList(),
              ),
            ),
            if (widget.sectionTitle != null || widget.title != null)
              WardenSectionLabel(widget.sectionTitle ?? widget.title ?? '', animate: false), // Keep header static on rebuilds
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
                  itemBuilder: widget.itemBuilder!,
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
  final Widget Function(BuildContext, T) itemBuilder;
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
    required this.itemBuilder,
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

  @override
  void initState() {
    super.initState();
    _stream = widget.streamFactory();
  }

  @override
  void didUpdateWidget(covariant _GenericFilteredList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab || widget.query != oldWidget.query) {
      _stream = widget.streamFactory();
    }
  }

  @override
  bool get wantKeepAlive => true;

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

        Widget content;
        if (filtered.isEmpty) {
          content = WardenEmptyState(
            icon: widget.emptyIcon ?? (widget.query.isEmpty ? Icons.inbox_rounded : Icons.search_off_rounded),
            title: widget.emptyTitle ?? (widget.query.isEmpty ? 'No results in ${widget.tab}' : 'No matches found'),
            subtitle: widget.emptySubtitle ?? (widget.query.isEmpty ? 'There are no items to show here at the moment.' : 'Try adjusting your search query.'),
          );
        } else {
          content = ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) => widget.itemBuilder(context, filtered[index]),
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
