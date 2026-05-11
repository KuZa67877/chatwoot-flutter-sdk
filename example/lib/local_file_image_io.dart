import 'dart:io';

import 'package:flutter/material.dart';

Widget localFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
  );
}
