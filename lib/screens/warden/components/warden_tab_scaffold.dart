import 'package:flutter/material.dart';
import '../../../widgets/vista_loader.dart';
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
  final Widget Function(List<T>)? extraHeaderBuilder;

  // Empty state customization
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;

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
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  State<WardenTabScaffold<T>> createState() => _WardenTabScaffoldState<T>();
}

class _WardenTabScaffoldState<T> extends State<WardenTabScaffold<T>> with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = widget.tabController ?? TabController(length: widget.tabs.length, vsync: this);
    _searchCtrl = widget.searchCtrl ?? TextEditingController();
    
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text);
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
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -0.5, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, widget.title == null ? 22 : 8, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? widget.searchQueryPlaceholder,
                        hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search_rounded, color: kPrimary),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 44,
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
                tabs: widget.tabs.map((t) => Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(t)))).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: widget.children ?? widget.tabs.map((tab) => _GenericFilteredList<T>(
                  tab: tab,
                  query: _query,
                  sectionTitle: widget.sectionTitle,
                  streamFactory: widget.streamFactory!,
                  itemBuilder: widget.itemBuilder!,
                  filterLogic: widget.filterLogic!,
                  extraHeaderBuilder: widget.extraHeaderBuilder,
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
  final Widget Function(List<T>)? extraHeaderBuilder;
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;

  const _GenericFilteredList({
    required this.tab,
    required this.query,
    this.sectionTitle,
    required this.streamFactory,
    required this.itemBuilder,
    required this.filterLogic,
    this.extraHeaderBuilder,
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  State<_GenericFilteredList<T>> createState() => _GenericFilteredListState<T>();
}

class _GenericFilteredListState<T> extends State<_GenericFilteredList<T>> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<T>>(
      stream: widget.streamFactory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: VISTALoader(color: kPrimary));
        }

        final allItems = snapshot.data ?? [];
        final filtered = allItems.where((item) => widget.filterLogic(item, widget.tab, widget.query)).toList();

        if (filtered.isEmpty) {
          return WardenEmptyState(
            icon: widget.emptyIcon ?? (widget.query.isEmpty ? Icons.inbox_rounded : Icons.search_off_rounded),
            title: widget.emptyTitle ?? (widget.query.isEmpty ? 'No results in ${widget.tab}' : 'No matches found'),
            subtitle: widget.emptySubtitle ?? (widget.query.isEmpty ? 'There are no items to show here at the moment.' : 'Try adjusting your search query.'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.extraHeaderBuilder != null) widget.extraHeaderBuilder!(allItems),
            if (widget.sectionTitle != null)
              WardenSectionLabel(widget.sectionTitle!, count: filtered.length),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) => widget.itemBuilder(context, filtered[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}
