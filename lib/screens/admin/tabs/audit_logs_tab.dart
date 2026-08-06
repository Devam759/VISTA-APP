import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/common/vista_loader.dart';

class AuditLogsTab extends StatefulWidget {
  const AuditLogsTab({super.key});

  @override
  State<AuditLogsTab> createState() => _AuditLogsTabState();
}

class _AuditLogsTabState extends State<AuditLogsTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'default');
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = [
    'All',
    'Security Violations',
    'Login Failures',
    'Status Changes',
    'Auth Events',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final event = (data['event'] ?? '').toString();

    switch (_selectedFilter) {
      case 'Security Violations':
        return event == 'securityViolation';
      case 'Login Failures':
        return event == 'loginFailed' || event == 'loginLocked';
      case 'Status Changes':
        return event == 'statusChange' || event == 'escalation' || event == 'roleRejected';
      case 'Auth Events':
        return event == 'loginSuccess' || event == 'logout';
      default:
        return true;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final uid = (data['uid'] ?? '').toString().toLowerCase();
    final detail = (data['detail'] ?? '').toString().toLowerCase();
    final platform = (data['platform'] ?? '').toString().toLowerCase();
    final event = (data['event'] ?? '').toString().toLowerCase();

    return uid.contains(query) || detail.contains(query) || platform.contains(query) || event.contains(query);
  }

  Color _getBadgeColor(String event) {
    switch (event) {
      case 'securityViolation':
      case 'loginFailed':
      case 'loginLocked':
        return const Color(0xFFEF4444); // Red
      case 'escalation':
      case 'roleRejected':
      case 'statusChange':
        return const Color(0xFFF59E0B); // Amber / Orange
      case 'loginSuccess':
        return const Color(0xFF10B981); // Green
      case 'logout':
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  IconData _getBadgeIcon(String event) {
    switch (event) {
      case 'securityViolation':
        return Icons.gpp_bad_rounded;
      case 'loginFailed':
      case 'loginLocked':
        return Icons.lock_clock_rounded;
      case 'escalation':
        return Icons.trending_up_rounded;
      case 'statusChange':
      case 'roleRejected':
        return Icons.swap_horiz_rounded;
      case 'loginSuccess':
        return Icons.login_rounded;
      case 'logout':
      default:
        return Icons.logout_rounded;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy • hh:mm:ss a').format(timestamp.toDate());
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4FF),
      child: Column(
        children: [
          // Filter & Search Controls Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by User ID, details, or platform...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1E3A8A)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                          selectedColor: const Color(0xFF1E3A8A),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Real-time Audit Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('audit_logs').orderBy('timestamp', descending: true).limit(50).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            'Error Loading Audit Logs: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: VISTALoader(size: 80));
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _matchesFilter(data) && _matchesSearch(data);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_outlined, size: 64, color: Colors.black26),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedFilter != 'All'
                              ? 'No audit events match your search/filter.'
                              : 'No system audit logs recorded yet.',
                          style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final event = (data['event'] ?? 'unknown').toString();
                    final uid = (data['uid'] ?? 'N/A').toString();
                    final detail = data['detail']?.toString();
                    final platform = data['platform']?.toString() ?? 'N/A';
                    final badgeColor = _getBadgeColor(event);
                    final badgeIcon = _getBadgeIcon(event);
                    final timestampStr = _formatTimestamp(data['timestamp']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event Badge & Timestamp
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(badgeIcon, size: 16, color: badgeColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        event,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    platform.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // User ID & Time
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SelectableText(
                                    'UID: $uid',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF1E3A8A),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  timestampStr,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),

                            // Details Section
                            if (detail != null && detail.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: SelectableText(
                                  detail,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    fontFamily: 'monospace',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
