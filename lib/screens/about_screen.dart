import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import '../version.dart';

/// About screen with game information and licenses
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
      applicationLegalese: '\u00a9 2024 Stones Contributors',
    );
  }

  Future<void> _openPrivacyPolicy() async {
    // On web, open the local privacy.html page
    // On other platforms, open the hosted URL
    final Uri url = kIsWeb
        ? Uri.parse('privacy.html')
        : Uri.parse('https://douglastkaiser.github.io/stones/privacy.html');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
                  'An abstract strategy game',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: GameColors.subtitleColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // About Stones Section
          const _AboutCard(
            title: 'About Stones',
            children: [
              Text(
                'Stones is an original abstract strategy game inspired by '
                'classic connection and stacking games.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Build roads across the board to connect opposite edges, '
                'or control the most territory with your flat stones. '
                'Use standing stones to block your opponent and capstones '
                'to flatten walls in your path.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Licenses Section
          _AboutCard(
            title: 'Legal',
            children: [
              _LinkTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: _openPrivacyPolicy,
              ),
              const SizedBox(height: 12),
              _LinkTile(
                icon: Icons.description,
                title: 'Open Source Licenses',
                subtitle: 'View third-party licenses',
                onTap: () => _showLicenses(context),
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
