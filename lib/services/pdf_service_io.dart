import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> savePdfToNative(List<int> bytes, String fileName) async {
  final dir = Directory.current.path;
  final filePath = p.join(dir, fileName);
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  return filePath;
}
