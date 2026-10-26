import 'package:flutter/material.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.backgroundImage,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? backgroundImage;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 250,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF10192D),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backgroundImage != null && backgroundImage!.isNotEmpty)
              Image(
                image: NetworkImage(backgroundImage!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: const Color(0xFF10192D),
                ),
              )
            else
              const ColoredBox(
                color: Color(0xFF10192D),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'DESTAQUE',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                      label: Text(actionLabel!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
