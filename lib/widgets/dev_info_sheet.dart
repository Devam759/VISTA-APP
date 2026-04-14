import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'hover_effect.dart';

// ─── LinkedIn profile URLs ─────────────────────────────────────────────────
const _devamLinkedIn = 'https://www.linkedin.com/in/devam-gupta/';
const _yashLinkedIn  = 'https://www.linkedin.com/in/yash-mishra-022b66330/';
// ──────────────────────────────────────────────────────────────────────────

/// Shows the "Minds Behind VISTA" developer info bottom sheet.
/// Call from any screen by passing the current [BuildContext].
void showDeveloperInfoSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 24, spreadRadius: 4),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Heading
          Text(
            'The Minds Behind VISTA',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Designed & Developed with Passion',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),

          const SizedBox(height: 28),

          // ── Two cards side by side ─────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _developerCard(
                    context: context,
                    name: 'Devam Gupta',
                    imageAsset: 'assets/images/devam.png',
                    github: 'https://github.com/Devam759',
                    linkedin: _devamLinkedIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _developerCard(
                    context: context,
                    name: 'Yash Mishra',
                    imageAsset: 'assets/images/yash.jpeg',
                    github: 'https://github.com/yashmish18',
                    linkedin: _yashLinkedIn,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // ── Contact email ──────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'vista@jklu.edu.in',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded,
                    size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'vista@jklu.edu.in',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} VISTA Team',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

Widget _developerCard({
  required BuildContext context,
  required String name,
  required String imageAsset,
  required String github,
  required String linkedin,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8EEF9)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.grey[200],
            backgroundImage: AssetImage(imageAsset),
          ),
        ),
        const SizedBox(height: 12),

        // Name
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 14),

        // Social icons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // GitHub
            HoverEffect(
              child: InkWell(
                onTap: () async {
                  final url = Uri.parse(github);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _GithubIcon(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // LinkedIn
            HoverEffect(
              child: InkWell(
                onTap: () async {
                  final url = Uri.parse(linkedin);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _LinkedInIcon(),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Real brand SVG icons ─────────────────────────────────────────────────

// Official GitHub mark SVG path
const _githubSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#ffffff" d="M12 0C5.374 0 0 5.373 0 12c0 5.302 3.438 9.8 8.207 11.387
    .599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416
    -.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729
    1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997
    .107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931
    0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0
    1.008-.322 3.301 1.23A11.509 11.509 0 0112 5.803c1.02.005 2.047.138
    3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118
    3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921
    .43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576
    C20.566 21.797 24 17.3 24 12c0-6.627-5.373-12-12-12z"/>
</svg>
''';

// Official LinkedIn mark SVG path
const _linkedinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#ffffff" d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037
    -1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046
    c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286z
    M5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065z
    m1.782 13.019H3.555V9h3.564v11.452z
    M22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451
    C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
</svg>
''';

class _GithubIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(6),
      child: SvgPicture.string(_githubSvg),
    );
  }
}

class _LinkedInIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(6),
      child: SvgPicture.string(_linkedinSvg),
    );
  }
}
