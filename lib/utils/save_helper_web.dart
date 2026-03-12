import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

Future<void> saveAndShare(List<List<dynamic>> rows, String fileName) async {
  late final List<int> bytes;

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

    final excelBytes = excel.encode();
    bytes = excelBytes ?? [];
  } else {
    // CSV format
    String csvData = const CsvEncoder().convert(rows);
    bytes = utf8.encode(csvData);
  }

  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = fileName;
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

Future<void> saveAndShareMultiSheet(
  List<String> sheetNames,
  List<List<dynamic>> Function(String) getRowsForSheet,
  String fileName,
) async {
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

  final bytes = excel.encode() ?? [];
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = fileName;
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
