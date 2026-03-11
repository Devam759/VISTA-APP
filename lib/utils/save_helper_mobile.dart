import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShare(List<List<dynamic>> rows, String fileName) async {
  String csvData = const CsvEncoder().convert(rows);
  final directory = await getApplicationDocumentsDirectory();
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
