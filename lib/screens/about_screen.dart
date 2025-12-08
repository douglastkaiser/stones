import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import '../version.dart';

/// About screen with game credits, links, and licenses
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Stones',
      applicationVersion: AppVersion.displayVersion,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 64,
          width: 64,
          child: CustomPaint(
            painter: _StonesIconPainter(),
          ),
        ),
      ),
      applicationLegalese: '\u00a9 2024 Stones Contributors\n\n'
          'Tak is a game designed by James Ernest and Patrick Rothfuss, '
          'published by Cheapass Games.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: GameColors.boardFrameInner,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // App Logo and Name
          Center(
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  width: 80,
                  child: CustomPaint(
                    painter: _StonesIconPainter(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'STONES',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: GameColors.titleColor,
                        letterSpacing: 4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppVersion.displayVersion,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A game of roads and flats',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: GameColors.subtitleColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // About Tak Section
          const _AboutCard(
            title: 'About Tak',
            children: [
              Text(
                'Stones is an implementation of Tak, the beautiful game from '
                'Patrick Rothfuss\'s "The Wise Man\'s Fear."',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Tak was designed and developed into a playable game by:',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 12),
              _CreditItem(
                name: 'James Ernest',
                role: 'Game Designer',
              ),
              SizedBox(height: 8),
              _CreditItem(
                name: 'Patrick Rothfuss',
                role: 'Creator & Author',
              ),
              SizedBox(height: 16),
              Text(
                'Published by Cheapass Games under license from '
                'Crab Fragment Labs.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Links Section
          _AboutCard(
            title: 'Links',
            children: [
              _LinkTile(
                icon: Icons.public,
                title: 'Crab Fragment Labs',
                subtitle: 'Official Tak website',
                onTap: () => _launchUrl('https://crabfragmentlabs.com'),
              ),
              const SizedBox(height: 8),
              _LinkTile(
                icon: Icons.shopping_bag,
                title: 'Buy Tak',
                subtitle: 'Get the physical board game',
                onTap: () => _launchUrl('https://cheapass.com/tak/'),
              ),
              const SizedBox(height: 8),
              _LinkTile(
                icon: Icons.book,
                title: 'The Wise Man\'s Fear',
                subtitle: 'Patrick Rothfuss\'s novel',
                onTap: () => _launchUrl('https://www.patrickrothfuss.com/content/books.html'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Licenses Section
          _AboutCard(
            title: 'Legal',
            children: [
              _LinkTile(
                icon: Icons.description,
                title: 'Open Source Licenses',
                subtitle: 'View third-party licenses',
                onTap: () => _showLicenses(context),
              ),
              const SizedBox(height: 16),
              Text(
                'Tak\u2122 is a trademark of Crab Fragment Labs. '
                'This app is an unofficial fan project and is not '
                'affiliated with or endorsed by Crab Fragment Labs, '
                'Cheapass Games, or Patrick Rothfuss.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Card container for about sections
class _AboutCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AboutCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GameColors.titleColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Credit item widget
class _CreditItem extends StatelessWidget {
  final String name;
  final String role;

  const _CreditItem({
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: GameColors.boardFrameInner,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              role,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Link tile widget
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: GameColors.boardFrameInner, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for stones icon
class _StonesIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height * 0.75;

    // Draw stacked flat stones
    _drawFlatStone(canvas, centerX, baseY, size.width * 0.6, GameColors.darkPiece, GameColors.darkPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - size.height * 0.12, size.width * 0.6, GameColors.lightPiece, GameColors.lightPieceBorder);
    _drawFlatStone(canvas, centerX, baseY - size.height * 0.24, size.width * 0.6, GameColors.darkPiece, GameColors.darkPieceBorder);

    // Draw capstone on top
    _drawCapstone(canvas, centerX, baseY - size.height * 0.48, size.width * 0.18, GameColors.lightPiece, GameColors.lightPieceBorder);
  }

  void _drawFlatStone(Canvas canvas, double x, double y, double width, Color fill, Color border) {
    final height = width * 0.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: width, height: height),
      Radius.circular(height * 0.2),
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rect.shift(const Offset(2, 2)), shadowPaint);

    // Fill
    final fillPaint = Paint()..color = fill;
    canvas.drawRRect(rect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rect, borderPaint);
  }

  void _drawCapstone(Canvas canvas, double x, double y, double radius, Color fill, Color border) {
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(x + 2, y + 2), radius, shadowPaint);

    // Fill
    final fillPaint = Paint()..color = fill;
    canvas.drawCircle(Offset(x, y), radius, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
