import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';
import '../../utils/export_helper.dart';

class MessScanLogsTab extends StatelessWidget {
  const MessScanLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final MessService messService = MessService();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<List<MessScanLog>>(
      stream: messService.getScanLogsStream(dateStr),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

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
                      final csv = messService.exportScanLogsToCsv(logs);
                      ExportHelper.saveRawCsv(
                          csv, "Mess_Scan_Logs_$dateStr.csv");
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
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final isPass = log.status == 'PASS';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPass
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                child: Icon(
                                  isPass
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: isPass
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
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
