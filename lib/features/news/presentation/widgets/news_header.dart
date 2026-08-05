import 'package:flutter/material.dart';

class NewsHeader extends StatelessWidget {
  const NewsHeader({
    super.key,
    required this.canPublish,
    required this.onCreate,
  });

  final bool canPublish;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Neuigkeiten',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canPublish)
                Tooltip(
                  message: 'Vereinsbeitrag erstellen',
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onCreate,
                      customBorder: const CircleBorder(),
                      child: const SizedBox.square(
                        dimension: 42,
                        child: Icon(
                          Icons.post_add_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktuelles aus dem Verein und von Instagram',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class NewsSectionTitle extends StatelessWidget {
  const NewsSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
