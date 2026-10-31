// apps/files/lib/src/file_icon.dart
//
// O ícone de um item: a miniatura nas imagens, o ícone do tema pelo tipo
// MIME (o PsitoIcon) e, sem tema (o laboratório, os testes), um do Material.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'env.dart';

class FileIcon extends StatelessWidget {
  final FsEntry entry;
  final FilesEnv env;
  final double size;

  /// Miniatura para as imagens (desligada nas listas de ícone pequeno).
  final bool thumbnail;

  const FileIcon({
    super.key,
    required this.entry,
    required this.env,
    required this.size,
    this.thumbnail = true,
  });

  /// As imagens maiores que isso ficam com o ícone: decodificar pesa.
  static const _maxThumbnailBytes = 30 * 1000 * 1000;

  @override
  Widget build(BuildContext context) {
    final themed = _themed();
    if (!thumbnail ||
        size < 32 ||
        !entry.mimeType.startsWith('image/') ||
        entry.size > _maxThumbnailBytes ||
        entry.mimeType == 'image/svg+xml') {
      return themed;
    }
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox.square(
      dimension: size,
      child: Image.file(
        File(entry.path),
        cacheWidth: pixels,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => themed,
        frameBuilder: (_, child, frame, sync) =>
            frame == null && !sync ? themed : child,
      ),
    );
  }

  Widget _themed() {
    final known = entry.isDirectory ? env.knownFolder(entry.path) : null;
    return PsitoIcon(
      [
        if (known != null) known.$1,
        if (entry.executable && !entry.mimeType.startsWith('text/'))
          'application-x-executable',
        ...env.mime.iconNames(entry.mimeType),
      ],
      size: size,
      fallback: Icon(
        materialIcon(entry),
        size: size * 0.9,
        color: entry.isDirectory ? const Color(0xFFFFC107) : Colors.white60,
      ),
    );
  }

  /// O ícone do Material de cada tipo, quando o tema não tem.
  static IconData materialIcon(FsEntry entry) {
    if (entry.isDirectory) return Icons.folder_rounded;
    if (entry.brokenLink) return Icons.link_off_rounded;
    final type = entry.mimeType;
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (type.startsWith('video/')) return Icons.movie_outlined;
    if (type.startsWith('text/')) return Icons.description_outlined;
    if (type.contains('zip') ||
        type.contains('tar') ||
        type.contains('compress')) {
      return Icons.inventory_2_outlined;
    }
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

/// Um ícone do tema pelo nome, com o do Material quando falta.
class ThemedIcon extends StatelessWidget {
  final List<String> names;
  final IconData fallback;
  final double size;
  final Color? color;

  const ThemedIcon(
    this.names, {
    super.key,
    required this.fallback,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) => PsitoIcon(
    names,
    size: size,
    fallback: Icon(fallback, size: size, color: color ?? Colors.white70),
  );
}
