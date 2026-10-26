import 'package:flutter/material.dart';

class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.title,
    required this.message,
    this.children = const [],
  });

  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(message)
          else
            SizedBox(
              height: 210,
              child: ListView(scrollDirection: Axis.horizontal, children: children),
            ),
        ],
      ),
    );
  }
}
