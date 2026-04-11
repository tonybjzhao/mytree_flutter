import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Full-screen dead-tree overlay for MyTree.
///
/// Features:
/// - Dark blurred background overlay with fade-in.
/// - Warm frosted-glass card with slide+scale entrance.
/// - Custom drawn dead-tree illustration (trunk, bare branches, dry leaves).
/// - One-time falling leaves animation (never loops).
/// - Bilingual EN / 中文 memory text: "It lived for X days."
/// - "Start Again" primary button + optional "Keep This Memory" secondary.
///
/// Integration (Stack overlay, preferred):
/// ```dart
/// Stack(
///   children: [
///     MyNormalHomePage(),
///     if (tree.healthState == TreeHealthState.dead)
///       Positioned.fill(
///         child: DeadTreeOverlay(
///           livedDays: tree.streakDays,
///           onRestart: _restart,
///         ),
///       ),
///   ],
/// );
/// ```
class DeadTreeOverlay extends StatefulWidget {
  const DeadTreeOverlay({
    super.key,
    required this.livedDays,
    required this.onRestart,
    this.showKeepMemory = false,
    this.onKeepMemory,
  });

  final int livedDays;
  final VoidCallback onRestart;
  final bool showKeepMemory;
  final VoidCallback? onKeepMemory;

  @override
  State<DeadTreeOverlay> createState() => _DeadTreeOverlayState();
}

class _DeadTreeOverlayState extends State<DeadTreeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _leafCtrl;

  late final Animation<double> _overlayOpacity;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _cardScale;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _treeOpacity;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _leafCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _overlayOpacity = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _cardOpacity = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.18, 0.78, curve: Curves.easeOut),
    );

    _treeOpacity = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.25, 0.72, curve: Curves.easeOut),
    );

    _cardScale = Tween<double>(begin: 0.965, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeCtrl,
        curve: const Interval(0.18, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeCtrl,
        curve: const Interval(0.20, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _leafCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _leafCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark fog overlay
          FadeTransition(
            opacity: _overlayOpacity,
            child: Container(color: const Color(0xCC1F221E)),
          ),

          // Soft blur (piggybacks on the overlay fade value)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _fadeCtrl,
                builder: (context, child) {
                  final sigma = 4.0 * _overlayOpacity.value;
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: Container(
                      color: Colors.white
                          .withValues(alpha: 0.03 * _overlayOpacity.value),
                    ),
                  );
                },
              ),
            ),
          ),

          // Card
          SafeArea(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SlideTransition(
                  position: _cardSlide,
                  child: ScaleTransition(
                    scale: _cardScale,
                    child: FadeTransition(
                      opacity: _cardOpacity,
                      child: _DeadTreeCard(
                        livedDays: widget.livedDays,
                        treeOpacity: _treeOpacity,
                        leafCtrl: _leafCtrl,
                        onRestart: widget.onRestart,
                        showKeepMemory: widget.showKeepMemory,
                        onKeepMemory: widget.onKeepMemory,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card body
// ---------------------------------------------------------------------------

class _DeadTreeCard extends StatelessWidget {
  const _DeadTreeCard({
    required this.livedDays,
    required this.treeOpacity,
    required this.leafCtrl,
    required this.onRestart,
    required this.showKeepMemory,
    required this.onKeepMemory,
  });

  final int livedDays;
  final Animation<double> treeOpacity;
  final AnimationController leafCtrl;
  final VoidCallback onRestart;
  final bool showKeepMemory;
  final VoidCallback? onKeepMemory;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EE).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 32,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tree illustration area
                  FadeTransition(
                    opacity: treeOpacity,
                    child: SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const _SceneGlow(),
                          _FallingLeaves(controller: leafCtrl),
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: _DeadTreeIllustration(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Primary title
                  const Text(
                    'This tree has withered.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D312B),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '这棵树已经枯萎。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF646A61),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Memory line — the emotional hook
                  Text(
                    'It lived for $livedDays day${livedDays == 1 ? '' : 's'}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF62675F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '它陪你长了 $livedDays 天。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7B8078),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'A new start can help it grow again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7068),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '重新开始，它还能再次长大。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7E837C),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRestart,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF647B5E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Start Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // Optional secondary CTA
                  if (showKeepMemory && onKeepMemory != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onKeepMemory,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF73786F),
                      ),
                      child: const Text(
                        'Keep This Memory',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radial background glow
// ---------------------------------------------------------------------------

class _SceneGlow extends StatelessWidget {
  const _SceneGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFF2EEE5).withValues(alpha: 0.95),
              const Color(0xFFE8E1D3).withValues(alpha: 0.30),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dead tree CustomPainter
// ---------------------------------------------------------------------------

class _DeadTreeIllustration extends StatelessWidget {
  const _DeadTreeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 190,
      child: CustomPaint(painter: _DeadTreePainter()),
    );
  }
}

class _DeadTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = size.height;

    // Ground ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, base - 12), width: 130, height: 16),
      Paint()..color = const Color(0xFFC8BEAA).withValues(alpha: 0.55),
    );

    // Pot shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, base - 22), width: 70, height: 9),
        const Radius.circular(999),
      ),
      Paint()..color = const Color(0x806A5647),
    );

    // Pot body
    final potPath = Path()
      ..moveTo(cx - 33, base - 32)
      ..lineTo(cx + 33, base - 32)
      ..lineTo(cx + 25, base - 2)
      ..lineTo(cx - 25, base - 2)
      ..close();
    canvas.drawPath(potPath, Paint()..color = const Color(0xFFB7987B));

    // Pot rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, base - 35), width: 78, height: 10),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFC7AA90),
    );

    // Soil
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, base - 35), width: 60, height: 5),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF8C7565),
    );

    final trunkP = Paint()
      ..color = const Color(0xFF736356)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final branchP = Paint()
      ..color = const Color(0xFF7B6A5D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    // Trunk (slightly bent)
    final trunk = Path()
      ..moveTo(cx, base - 38)
      ..cubicTo(cx - 2, base - 72, cx - 6, base - 108, cx - 10, base - 142)
      ..cubicTo(cx - 13, base - 158, cx - 10, base - 170, cx - 2, base - 180);
    canvas.drawPath(trunk, trunkP);

    // Left branches
    canvas.drawPath(
      Path()
        ..moveTo(cx - 7, base - 116)
        ..cubicTo(
            cx - 34, base - 126, cx - 54, base - 140, cx - 66, base - 158),
      branchP,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 2, base - 148)
        ..cubicTo(
            cx - 22, base - 160, cx - 28, base - 173, cx - 33, base - 185),
      branchP,
    );

    // Right branches
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, base - 128)
        ..cubicTo(
            cx + 18, base - 138, cx + 42, base - 150, cx + 56, base - 166),
      branchP,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 4, base - 158)
        ..cubicTo(
            cx + 12, base - 168, cx + 16, base - 181, cx + 18, base - 191),
      branchP,
    );

    final leafP = Paint()..color = const Color(0xFF9D8B64);
    final dryP =
        Paint()..color = const Color(0xFFA89264).withValues(alpha: 0.9);

    // Attached dry leaves
    _leaf(canvas, Offset(cx - 66, base - 158), 10, -0.2, leafP);
    _leaf(canvas, Offset(cx + 57, base - 167), 9, 0.30, leafP);
    _leaf(canvas, Offset(cx + 18, base - 191), 8, 0.15, leafP);

    // Fallen leaves on ground
    _leaf(canvas, Offset(cx - 44, base - 12), 11, 0.55, dryP);
    _leaf(canvas, Offset(cx + 38, base - 8), 10, -0.45, dryP);
  }

  void _leaf(Canvas canvas, Offset c, double r, double rot, Paint p) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 0.9, -r * 0.2, 0, r)
      ..quadraticBezierTo(-r * 0.9, -r * 0.2, 0, -r)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawLine(
      Offset(0, -r * 0.8),
      Offset(0, r * 0.75),
      Paint()
        ..color = const Color(0x806B583E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ---------------------------------------------------------------------------
// Falling leaves animation
// ---------------------------------------------------------------------------

class _FallingLeaves extends StatelessWidget {
  const _FallingLeaves({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => CustomPaint(
          size: const Size(220, 200),
          painter: _FallingLeavesPainter(progress: controller.value),
        ),
      ),
    );
  }
}

class _FallingLeavesPainter extends CustomPainter {
  const _FallingLeavesPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    _paintLeaf(
      canvas,
      start: Offset(size.width * 0.34, size.height * 0.18),
      end: Offset(size.width * 0.20, size.height * 0.92),
      rotBase: -0.5,
      phase: 0.0,
      scale: 1.0,
    );
    _paintLeaf(
      canvas,
      start: Offset(size.width * 0.66, size.height * 0.22),
      end: Offset(size.width * 0.80, size.height * 0.88),
      rotBase: 0.35,
      phase: 0.8,
      scale: 0.88,
    );
  }

  void _paintLeaf(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required double rotBase,
    required double phase,
    required double scale,
  }) {
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final sway = math.sin((t * 2.8 + phase) * math.pi) * 14.0;
    final dx = lerpDouble(start.dx, end.dx, t)! + sway;
    final dy = lerpDouble(start.dy, end.dy, t)!;
    final rotation = rotBase + t * 1.6;
    final opacity =
        (1.0 - ((t - 0.82) / 0.18).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(dx, dy);
    canvas.rotate(rotation);
    canvas.scale(scale, scale);

    final fill = Paint()
      ..color = const Color(0xFFA58F65).withValues(alpha: 0.9 * opacity);
    final path = Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(9, -2, 0, 10)
      ..quadraticBezierTo(-9, -2, 0, -10)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawLine(
      const Offset(0, -8),
      const Offset(0, 8),
      Paint()
        ..color =
            const Color(0x805B4B36).withValues(alpha: opacity.toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FallingLeavesPainter old) =>
      old.progress != progress;
}
