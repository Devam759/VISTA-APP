import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';
import '../../utils/export_helper.dart';

class MessScanLogsTab extends StatefulWidget {
  const MessScanLogsTab({super.key});

  @override
  State<MessScanLogsTab> createState() => _MessScanLogsTabState();
}

class _MessScanLogsTabState extends State<MessScanLogsTab> {
  final MessService _messService = MessService();
  int _currentPage = 1;
  static const int _pageSize = 50;
  late String _dateStr;
  late Stream<List<MessScanLog>> _scanLogsStream;

  @override
  void initState() {
    super.initState();
    _dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _scanLogsStream = _messService.getScanLogsStream(_dateStr);
  }

  Widget _buildPaginationBar(int totalItems, int totalPages, int startIndex, int endIndex) {
    if (totalItems <= _pageSize) return const SizedBox.shrink();

    const kPrimary = Color(0xFF1E3A8A);

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
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
    return StreamBuilder<List<MessScanLog>>(
      stream: _scanLogsStream,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        final totalItems = logs.length;
        final totalPages = (totalItems / _pageSize).ceil() == 0 ? 1 : (totalItems / _pageSize).ceil();
        if (_currentPage > totalPages) _currentPage = totalPages;
        if (_currentPage < 1) _currentPage = 1;

        final startIndex = (_currentPage - 1) * _pageSize;
        final endIndex = (startIndex + _pageSize > totalItems) ? totalItems : startIndex + _pageSize;
        final pageLogs = (startIndex < totalItems) ? logs.sublist(startIndex, endIndex) : <MessScanLog>[];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Scan Logs (${logs.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF1E3A8A),
                    ),
                    tooltip: 'Export CSV',
                    onPressed: () {
                      final csv = _messService.exportScanLogsToCsv(logs);
                      ExportHelper.saveRawCsv(
                          csv, "Mess_Scan_Logs_$_dateStr.csv");
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No scan logs recorded today yet.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: pageLogs.length + (totalPages > 1 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == pageLogs.length) {
                            return _buildPaginationBar(totalItems, totalPages, startIndex, endIndex);
                          }

                          final log = pageLogs[index];
                          final isPass = log.status == 'PASS';
                          final sNo = startIndex + index + 1;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: SizedBox(
                                width: 70,
                                child: Row(
                                  children: [
                                    Text(
                                      '$sNo.',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isPass
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      child: Icon(
                                        isPass
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        size: 16,
                                        color: isPass
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                "${log.studentName} (${log.rollNo})",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                "${log.mealType.displayName} • ${DateFormat('HH:mm:ss').format(log.timestamp)}${log.failureReason != null ? '\nReason: ${log.failureReason}' : ''}",
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPass
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isPass
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
