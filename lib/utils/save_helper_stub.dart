Future<void> saveAndShare(List<List<dynamic>> rows, String fileName) async {
  throw UnsupportedError(
    'Cannot save and share without platform-specific implementation',
  );
}

Future<void> saveAndShareMultiSheet(
  List<String> sheetNames,
  List<List<dynamic>> Function(String) getRowsForSheet,
  String fileName,
) async {
  throw UnsupportedError(
    'Cannot save and share multi-sheet without platform-specific implementation',
  );
}
