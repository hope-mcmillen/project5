import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/logo_image.dart';

typedef PickedLogo = ({String name, Uint8List bytes});

/// Opens the system picker for a logo image; null when cancelled.
/// Overridden in tests.
final logoPickerProvider = Provider<Future<PickedLogo?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: LogoImage.extensions,
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  },
);
