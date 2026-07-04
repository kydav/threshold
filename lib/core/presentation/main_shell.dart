import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.location, required this.child, super.key});

  final Widget child;
  final String location;

  bool get _homeActive => location.startsWith('/home');
  bool get _agreementsActive => location.startsWith('/agreements');
  bool get _profileActive => location.startsWith('/profile');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              isDark
                  ? 'assets/images/background_dark.png'
                  : 'assets/images/background.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          child,
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _FloatingNav(
            homeActive: _homeActive,
            agreementsActive: _agreementsActive,
            profileActive: _profileActive,
            onHomeTap: () => context.go('/home'),
            onAgreementsTap: () => context.go('/agreements'),
            onAddTap: () => context.push('/agreements/new'),
            onProfileTap: () => context.go('/profile'),
          ),
        ),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.homeActive,
    required this.agreementsActive,
    required this.profileActive,
    required this.onHomeTap,
    required this.onAgreementsTap,
    required this.onAddTap,
    required this.onProfileTap,
  });

  final bool homeActive;
  final bool agreementsActive;
  final bool profileActive;
  final VoidCallback onHomeTap;
  final VoidCallback onAgreementsTap;
  final VoidCallback onAddTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A44) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              isActive: homeActive,
              onTap: () {
                HapticFeedback.lightImpact();
                onHomeTap();
              },
            ),
          ),
          // Expanded(
          //   child: _NavItem(
          //     icon: Icons.description_outlined,
          //     activeIcon: Icons.description_rounded,
          //     label: 'Agreements',
          //     isActive: agreementsActive,
          //     onTap: onAgreementsTap,
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAddTap();
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: cs.onPrimary, size: 35),
              ),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              isActive: profileActive,
              onTap: () {
                HapticFeedback.lightImpact();
                onProfileTap();
              },
            ),
          ),
          //const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? cs.primary : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
