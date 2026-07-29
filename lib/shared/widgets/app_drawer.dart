import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/legal_links.dart';
import 'receipt_decorations.dart';
import '../../features/scan/screens/scan_screen.dart';
import '../../features/mealplan/screens/meal_plan_screen.dart';
import '../../features/goals/screens/goals_screen.dart';

/// The app's side navigation drawer, opened via the hamburger icon on
/// Dashboard's Home tab (see dashboard_screen.dart). Deliberately
/// separate from the existing profile bottom sheet (_showProfileMenu)
/// rather than replacing it — some destinations (Privacy Policy, Sign
/// Out) exist in both by explicit choice, not an oversight.
///
/// "Settings" points at the existing Goals & Targets screen for now —
/// there's no dedicated Settings screen in the app yet, and that's the
/// closest real destination today.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: colors.labelCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BarcodeStrip(color: colors.accent),
                  const SizedBox(height: 16),
                  Text(
                    'EATSY',
                    style: AppFonts.mono(
                      fontSize: 15,
                      color: colors.accent,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your nutrition companion',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Dashboard',
                    // Already there if the drawer's open at all — this
                    // is the entry point it's opened from — so this
                    // just closes the drawer rather than navigating
                    // anywhere.
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.camera_alt_outlined,
                    label: 'Scan',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScanScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Meal Plan',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MealPlanScreen()));
                    },
                  ),
                  Divider(color: colors.divider, height: 24, indent: 20, endIndent: 20),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const GoalsScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.smart_toy_outlined,
                    label: 'Chatbot',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/chatbot');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: 'Help',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/help');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () {
                      Navigator.pop(context);
                      LegalLinks.openPrivacyPolicy(context);
                    },
                  ),
                  Divider(color: colors.divider, height: 24, indent: 20, endIndent: 20),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    color: Colors.red,
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await Supabase.instance.client.auth.signOut();
                      } catch (_) {}
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      leading: Icon(icon, color: color ?? colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? colors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}