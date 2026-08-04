import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/hover_effect.dart';

// ─── LinkedIn profile URLs ─────────────────────────────────────────────────
const _devamLinkedIn = 'https://www.linkedin.com/in/devam-gupta/';
const _yashLinkedIn  = 'https://www.linkedin.com/in/yash-mishra-022b66330/';
// ──────────────────────────────────────────────────────────────────────────

/// Shows the "Minds Behind VISTA" developer info bottom sheet.
/// Integrates [PackageInfo] and [DeviceInfoPlugin] to display dynamic app & device metadata.
void showDeveloperInfoSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _DeveloperInfoContent(),
  );
}

class _DeveloperInfoContent extends StatefulWidget {
  const _DeveloperInfoContent();

  @override
  State<_DeveloperInfoContent> createState() => _DeveloperInfoContentState();
}

class _DeveloperInfoContentState extends State<_DeveloperInfoContent> {
  String _appVersion = 'v1.3.0 (Build 16)';
  String _deviceInfo = 'VISTA Client';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final pkgInfo = await PackageInfo.fromPlatform();
      final versionStr = 'v${pkgInfo.version} (Build ${pkgInfo.buildNumber})';

      String deviceStr = 'Web Platform';
      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final android = await deviceInfo.androidInfo;
          deviceStr = '${android.manufacturer} ${android.model} (Android ${android.version.release})';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final ios = await deviceInfo.iosInfo;
          deviceStr = '${ios.name} (${ios.systemName} ${ios.systemVersion})';
        }
      }

      if (mounted) {
        setState(() {
          _appVersion = versionStr;
          _deviceInfo = deviceStr;
        });
      }
    } catch (_) {
      // Fallback defaults
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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

          const SizedBox(height: 24),

          // ── Dynamic App Version & Device Info Badge ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 6),
                Text(
                  '$_appVersion • $_deviceInfo',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Two developer cards ─────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _developerCard(
                    context: context,
                    name: 'Devam Gupta',
                    initials: 'DG',
                    github: 'https://github.com/Devam759',
                    linkedin: _devamLinkedIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _developerCard(
                    context: context,
                    name: 'Yash Mishra',
                    initials: 'YM',
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
              final uri = Uri(scheme: 'mailto', path: 'vista@jklu.edu.in');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded, size: 16, color: Colors.grey[500]),
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
    );
  }
}

Widget _developerCard({
  required BuildContext context,
  required String name,
  required String initials,
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
        // Avatar with initials
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.0,
              ),
            ),
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
                  child: SvgPicture.string(
                    '''<svg height="20" width="20" viewBox="0 0 16 16" fill="#1E293B"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>''',
                    width: 18,
                    height: 18,
                  ),
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
                  child: SvgPicture.string(
                    '''<svg height="20" width="20" viewBox="0 0 24 24" fill="#0A66C2"><path d="M19 3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h14m-.5 15.5v-5.3a3.26 3.26 0 0 0-3.26-3.26c-.85 0-1.84.52-2.28 1.3v-1.11h-2.79v8.37h2.79v-4.93c0-.77.62-1.4 1.39-1.4a1.4 1.4 0 0 1 1.4 1.4v4.93h2.75M6.46 10.9v8.37H9.25V10.9H6.46M7.86 6.7a1.63 1.63 0 1 0 0 3.26 1.63 1.63 0 0 0 0-3.26z"/></svg>''',
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
