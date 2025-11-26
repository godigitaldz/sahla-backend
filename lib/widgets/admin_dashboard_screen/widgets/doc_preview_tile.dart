import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocPreviewTile extends StatelessWidget {
  final String url;
  final String label;

  const DocPreviewTile({required this.url, required this.label, super.key});

  bool get _isImage {
    final u = url.toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: _isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.insert_drive_file,
                          color: Colors.black),
                    ),
                  )
                : const Icon(Icons.insert_drive_file, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.6),
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _openPreview(context),
            child: const Text('Open'),
          ),
          IconButton(
            tooltip: 'Copy URL',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('URL copied'),
                    backgroundColor: Colors.black));
              }
            },
            icon: const Icon(Icons.copy, size: 18, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: _isImage
                ? CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)
                : Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(url,
                            style: const TextStyle(color: Colors.white)))),
          ),
        ),
      ),
    );
  }
}
