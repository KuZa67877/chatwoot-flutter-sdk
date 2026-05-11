import 'package:flutter/widgets.dart';

import 'local_file_image_stub.dart' if (dart.library.io) 'local_file_image_io.dart' as impl;

Widget localFileImage(String path, {BoxFit fit = BoxFit.cover}) => impl.localFileImage(path, fit: fit);
