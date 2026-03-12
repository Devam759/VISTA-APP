import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';

Future<void> saveAndShare(List<List<dynamic>> rows, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();

  // Check if Excel format is requested
  if (fileName.endsWith('.xlsx')) {
    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()]!;

    // Add data to sheet
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      for (int j = 0; j < row.length; j++) {
        final value = row[j];
        if (value != null) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
            .value = TextCellValue(value.toString());
        }
      }
    }

    final path = "${directory.path}/$fileName";
    final file = File(path);
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Exported Report',
      subject: 'VISTA Report',
    );
  } else {
    // CSV format
    String csvData = const CsvEncoder().convert(rows);
    final path = "${directory.path}/$fileName";
    final file = File(path);
    await file.writeAsString(csvData);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Exported Report',
      subject: 'VISTA Report',
    );
  }
}

Future<void> saveAndShareMultiSheet(
  List<String> sheetNames,
  List<List<dynamic>> Function(String) getRowsForSheet,
  String fileName,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final excel = Excel.createExcel();

  // Remove default sheet
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) {
    excel.delete(defaultSheet);
  }

  // Create a sheet for each hostel
  for (final sheetName in sheetNames) {
    final rows = getRowsForSheet(sheetName);
    final sheet = excel[sheetName];

    // Add data to sheet
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      for (int j = 0; j < row.length; j++) {
        final value = row[j];
        if (value != null) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i))
            .value = TextCellValue(value.toString());
        }
      }
    }
  }

  final path = "${directory.path}/$fileName";
  final file = File(path);
  final bytes = excel.encode();
  if (bytes != null) {
    await file.writeAsBytes(bytes);
  }

  // ignore: deprecated_member_use
  await Share.shareXFiles(
    [XFile(path)],
    text: 'Exported Report',
    subject: 'VISTA Report',
  );
}
