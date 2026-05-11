import 'package:flutter/material.dart';

Widget localFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Padding(
    padding: const EdgeInsets.all(12),
    child: Text('Local images are not available on web: $path'),
  );
}
