import 'package:flutter/material.dart';

/// A readable, keyboard-focusable entry point with the player arrangement visible.
class PlayModeCard extends StatelessWidget {
  const PlayModeCard(
      {super.key,
      required this.title,
      required this.description,
      required this.icon,
      required this.onTap,
      this.featured = false});
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: featured ? colors.primaryContainer : colors.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
