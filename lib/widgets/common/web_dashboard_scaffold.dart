import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'hover_effect.dart';

class WebNavigationSubItem {
  final String label;
  final IconData icon;
  final int pageIndex;

  const WebNavigationSubItem({
    required this.label,
    required this.icon,
    required this.pageIndex,
  });
}

class WebNavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showBadge;
  final List<WebNavigationSubItem>? subItems;
  final VoidCallback? onTap;

  const WebNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showBadge = false,
    this.subItems,
    this.onTap,
  });
}

/// Web-optimized layout wrapper for Admin, Wardens, and Mess Manager roles.
/// On Web / desktop width (> 900px), presents a left sidebar navigation menu
/// using 100% full screen aspect ratio.
/// On mobile/tablet screens, seamlessly falls back to standard child layout.
class WebDashboardScaffold extends StatefulWidget {
  final String title;
  final String roleBadge;
  final String userName;
  final String? subtitle;
  final String? hostelFilter;
  final ValueChanged<String>? onHostelFilterChanged;
  final List<String>? hostelOptions;
  final List<WebNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback? onSignOut;
  final Widget? headerAction;
  final List<Widget> pages;
  final Widget? mobileChild;

  const WebDashboardScaffold({
    super.key,
    required this.title,
    required this.roleBadge,
    required this.userName,
    this.subtitle,
    this.hostelFilter,
    this.onHostelFilterChanged,
    this.hostelOptions,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onSignOut,
    this.headerAction,
    required this.pages,
    this.mobileChild,
  });

  @override
  State<WebDashboardScaffold> createState() => _WebDashboardScaffoldState();
}

class _WebDashboardScaffoldState extends State<WebDashboardScaffold> {
  final Set<int> _expandedItems = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebWide = kIsWeb && constraints.maxWidth >= 900;

        if (!isWebWide) {
          return widget.mobileChild ?? widget.pages[widget.selectedIndex];
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: Row(
            children: [
              // ── Left Sidebar Navigation Menu ──────────────────────────────
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F2460),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(4, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/jklu_logo_darkbg_bgremove.png',
                                height: 52,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                          if (widget.onHostelFilterChanged != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: widget.hostelFilter ?? 'All',
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E3A8A),
                                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: (widget.hostelOptions ?? const ['All', 'BH1', 'BH2', 'GH1', 'GH2'])
                                      .map((h) => DropdownMenuItem(
                                            value: h,
                                            child: Text(h == 'All' ? 'All Hostels' : h),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null && widget.onHostelFilterChanged != null) {
                                      widget.onHostelFilterChanged!(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ] else if (widget.subtitle != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    const SizedBox(height: 16),

                    // Navigation Items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: widget.items.length,
                        itemBuilder: (context, i) {
                          final item = widget.items[i];
                          final hasSubItems = item.subItems != null && item.subItems!.isNotEmpty;
                          final isExpanded = _expandedItems.contains(i);

                          // Calculate the effective page index for top-level item without sub-items
                          int computedPageIndex = 0;
                          for (int idx = 0; idx < i; idx++) {
                            final prev = widget.items[idx];
                            if (prev.subItems != null && prev.subItems!.isNotEmpty) {
                              computedPageIndex += prev.subItems!.length;
                            } else {
                              computedPageIndex += 1;
                            }
                          }

                          // Parent item is selected if selectedIndex matches it directly/computed, or matches any of its subItems' pageIndex
                          final isParentSelected = !hasSubItems
                              ? widget.selectedIndex == computedPageIndex
                              : item.subItems!.any((s) => s.pageIndex == widget.selectedIndex);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HoverEffect(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (item.onTap != null) {
                                          item.onTap!();
                                        } else if (hasSubItems) {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedItems.remove(i);
                                            } else {
                                              _expandedItems.add(i);
                                            }
                                          });
                                          // Also select first subItem page if none selected
                                          if (!item.subItems!.any((s) => s.pageIndex == widget.selectedIndex)) {
                                            widget.onItemSelected(item.subItems!.first.pageIndex);
                                          }
                                        } else {
                                          widget.onItemSelected(computedPageIndex);
                                        }
                                      },
                                       borderRadius: BorderRadius.circular(12),
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(
                                             horizontal: 16, vertical: 12),
                                         decoration: BoxDecoration(
                                           color: isParentSelected
                                               ? Colors.white.withValues(alpha: 0.16)
                                               : Colors.transparent,
                                           borderRadius: BorderRadius.circular(12),
                                           border: isParentSelected
                                               ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                                               : null,
                                         ),
                                         child: Row(
                                           children: [
                                             if (isParentSelected)
                                               Container(
                                                 width: 3,
                                                 height: 16,
                                                 margin: const EdgeInsets.only(right: 10),
                                                 decoration: BoxDecoration(
                                                   color: const Color(0xFF60A5FA),
                                                   borderRadius: BorderRadius.circular(2),
                                                 ),
                                               ),
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Icon(
                                                  isParentSelected
                                                      ? item.selectedIcon
                                                      : item.icon,
                                                  size: 20,
                                                  color: isParentSelected || isExpanded
                                                      ? Colors.white
                                                      : Colors.white60,
                                                ),
                                                if (item.showBadge)
                                                  Positioned(
                                                    top: -2,
                                                    right: -2,
                                                    child: Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.redAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                item.label,
                                                style: TextStyle(
                                                  color: isParentSelected || isExpanded
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontSize: 14,
                                                  fontWeight: isParentSelected || isExpanded
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (hasSubItems)
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                size: 18,
                                                color: Colors.white70,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasSubItems && isExpanded)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 4),
                                    child: Column(
                                      children: item.subItems!.map((sub) {
                                        final isSubSelected = widget.selectedIndex == sub.pageIndex;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: HoverEffect(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => widget.onItemSelected(sub.pageIndex),
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 16, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isSubSelected
                                                        ? Colors.white.withValues(alpha: 0.15)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: isSubSelected
                                                        ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                                                        : null,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        sub.icon,
                                                        size: 16,
                                                        color: isSubSelected
                                                            ? Colors.white
                                                            : Colors.white60,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          sub.label,
                                                          style: TextStyle(
                                                            color: isSubSelected
                                                                ? Colors.white
                                                                : Colors.white70,
                                                            fontSize: 13,
                                                            fontWeight: isSubSelected
                                                                ? FontWeight.bold
                                                                : FontWeight.normal,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // User Profile & Sign Out Footer
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                const Color(0xFF2563EB).withValues(alpha: 0.3),
                            child: Text(
                              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (widget.onSignOut != null)
                            IconButton(
                              onPressed: widget.onSignOut,
                              icon: const Icon(Icons.logout_rounded,
                                  color: Colors.white60, size: 18),
                              tooltip: 'Sign Out',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main Content Area (Full Aspect Ratio) ─────────────────────
              Expanded(
                child: Column(
                  children: [
                    if (widget.headerAction != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        color: Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [widget.headerAction!],
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: widget.selectedIndex,
                        children: widget.pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
