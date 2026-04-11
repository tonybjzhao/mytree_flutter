import 'package:flutter/material.dart';

enum ReviveSheetResult { revive, showPaywall, letItGo }

class RevivePaywallSheet extends StatelessWidget {
  const RevivePaywallSheet({
    super.key,
    required this.streakDays,
    required this.reviveCount,
    required this.isPremium,
  });

  final int streakDays;
  final int reviveCount;
  final bool isPremium;

  bool get _isFreeRevive => reviveCount == 0;

  static Future<ReviveSheetResult?> show(
    BuildContext context, {
    required int streakDays,
    required int reviveCount,
    required bool isPremium,
  }) {
    return showModalBottomSheet<ReviveSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RevivePaywallSheet(
        streakDays: streakDays,
        reviveCount: reviveCount,
        isPremium: isPremium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2A20),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              blurRadius: 30,
              color: Colors.black38,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Text('🥀', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Your tree is gone',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              streakDays > 0
                  ? 'You stopped caring — and your $streakDays-day streak is at risk.\nBut maybe it\'s not too late.'
                  : 'You stopped caring, and it couldn\'t survive.\nBut maybe it\'s not too late.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revive available for 24 hours',
              style: TextStyle(
                color: Color(0xFF9ED49A),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 14),
            _buildPrimaryButton(context),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(ReviveSheetResult.letItGo),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text('Let it go', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    if (_isFreeRevive) {
      return _InfoCard(
        title: 'First revive is free',
        subtitle: 'Give your tree one more chance.',
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFF9BE37A),
      );
    }
    if (isPremium) {
      return _InfoCard(
        title: 'Premium active',
        subtitle: 'Your tree can still be saved.',
        icon: Icons.eco_rounded,
        accent: const Color(0xFF7ED957),
      );
    }
    return _InfoCard(
      title: 'Save it with Premium',
      subtitle:
          'Revive dead trees · Grow more trees · Never lose progress again\n'
          '\$2.99 one-time. No subscription.',
      icon: Icons.workspace_premium_rounded,
      accent: const Color(0xFFFFD54F),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    if (_isFreeRevive || isPremium) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(ReviveSheetResult.revive),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF8BE05D),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            _isFreeRevive
                ? 'Give it one more chance 🌱'
                : 'Revive my tree 🌱',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    // Needs premium purchase.
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () =>
            Navigator.of(context).pop(ReviveSheetResult.showPaywall),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFFFD54F),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          'Unlock Premium · \$2.99 🌱',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accent.withValues(alpha: 0.18),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
