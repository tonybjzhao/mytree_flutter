import 'package:flutter/material.dart';

import 'tree_model.dart';
import 'tree_service.dart';

/// Single main screen: tree illustration, status, streak, and water / restart actions.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.treeService});

  final TreeService treeService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TreeState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _state = widget.treeService.loadState();
    });
  }

  Future<void> _onWaterToday() async {
    if (_busy || _state == null || _state!.isDead) return;
    setState(() => _busy = true);
    await widget.treeService.waterToday();
    if (mounted) {
      setState(() {
        _state = widget.treeService.loadState();
        _busy = false;
      });
    }
  }

  Future<void> _onRestart() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.treeService.restartFromSeed();
    if (mounted) {
      setState(() {
        _state = widget.treeService.loadState();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF5F0),
      body: SafeArea(
        child: state == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'MyTree',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF2D4A3E),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Water once a day to help it grow.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5C7268),
                          ),
                    ),
                    const Spacer(),
                    _TreeIllustration(state: state),
                    const Spacer(),
                    Text(
                      'Status: ${state.statusLabel}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF2D4A3E),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Streak: ${state.streak} day${state.streak == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF5C7268),
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (state.isDead) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _onRestart,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF4A7C6E),
                          ),
                          child: const Text('Plant a new seed'),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (state.wateredToday || _busy)
                              ? null
                              : _onWaterToday,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF4A7C6E),
                            disabledBackgroundColor: const Color(0xFFB8CEC4),
                          ),
                          child: Text(
                            state.wateredToday ? 'Watered today' : 'Water today',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Large centered tree built from simple shapes (no external assets).
class _TreeIllustration extends StatelessWidget {
  const _TreeIllustration({required this.state});

  final TreeState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      width: 280,
      child: CustomPaint(
        painter: _TreePainter(state: state),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({required this.state});

  final TreeState state;

  Color get _soil => const Color(0xFF8D6E63);

  /// Foliage / accent driven by health (green → yellow → grey).
  Color get _leaf {
    switch (state.health) {
      case TreeHealth.healthy:
        return const Color(0xFF66BB6A);
      case TreeHealth.thirsty:
        return const Color(0xFF9CCC65);
      case TreeHealth.wilting:
        return const Color(0xFFC0CA33);
      case TreeHealth.dead:
        return const Color(0xFF9E9E9E);
    }
  }

  Color get _trunk => state.health == TreeHealth.dead
      ? const Color(0xFF6D4C41)
      : const Color(0xFF5D4037);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.82;

    // Ground
    final ground = Paint()
      ..color = const Color(0xFFC8E6C9).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + 8),
        width: size.width * 0.9,
        height: 36,
      ),
      ground,
    );

    switch (state.growthStage) {
      case GrowthStage.seed:
        _drawSeed(canvas, cx, baseY);
        break;
      case GrowthStage.sprout:
        _drawSprout(canvas, cx, baseY);
        break;
      case GrowthStage.smallTree:
        _drawSmallTree(canvas, cx, baseY);
        break;
      case GrowthStage.youngTree:
        _drawYoungTree(canvas, cx, baseY);
        break;
      case GrowthStage.matureTree:
        _drawMatureTree(canvas, cx, baseY);
        break;
    }
  }

  void _drawSeed(Canvas canvas, double cx, double baseY) {
    final soil = Paint()..color = _soil;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY), width: 56, height: 22),
      soil,
    );
    final seed = Paint()..color = _trunk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, baseY - 18), width: 28, height: 36),
        const Radius.circular(12),
      ),
      seed,
    );
    final sprout = Paint()..color = _leaf;
    canvas.drawCircle(Offset(cx, baseY - 42), 10, sprout);
  }

  void _drawSprout(Canvas canvas, double cx, double baseY) {
    final soil = Paint()..color = _soil;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY), width: 72, height: 24),
      soil,
    );
    final trunk = Paint()
      ..color = _trunk
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, baseY - 4), Offset(cx, baseY - 70), trunk);
    final leaf = Paint()..color = _leaf;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 22, baseY - 78), width: 36, height: 22),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 22, baseY - 74), width: 36, height: 22),
      leaf,
    );
  }

  void _drawSmallTree(Canvas canvas, double cx, double baseY) {
    final soil = Paint()..color = _soil;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY), width: 88, height: 28),
      soil,
    );
    final trunk = Paint()..color = _trunk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, baseY - 36), width: 22, height: 72),
        const Radius.circular(6),
      ),
      trunk,
    );
    final crown = Paint()..color = _leaf;
    canvas.drawCircle(Offset(cx, baseY - 100), 52, crown);
  }

  void _drawYoungTree(Canvas canvas, double cx, double baseY) {
    final soil = Paint()..color = _soil;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY), width: 100, height: 30),
      soil,
    );
    final trunk = Paint()..color = _trunk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, baseY - 50), width: 28, height: 100),
        const Radius.circular(8),
      ),
      trunk,
    );
    final crown = Paint()..color = _leaf;
    canvas.drawCircle(Offset(cx - 18, baseY - 118), 48, crown);
    canvas.drawCircle(Offset(cx + 22, baseY - 108), 52, crown);
  }

  void _drawMatureTree(Canvas canvas, double cx, double baseY) {
    final soil = Paint()..color = _soil;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY), width: 120, height: 34),
      soil,
    );
    final trunk = Paint()..color = _trunk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, baseY - 58), width: 34, height: 116),
        const Radius.circular(10),
      ),
      trunk,
    );
    final crown = Paint()..color = _leaf;
    canvas.drawCircle(Offset(cx, baseY - 132), 58, crown);
    canvas.drawCircle(Offset(cx - 44, baseY - 112), 50, crown);
    canvas.drawCircle(Offset(cx + 44, baseY - 112), 50, crown);
    canvas.drawCircle(Offset(cx - 24, baseY - 96), 44, crown);
    canvas.drawCircle(Offset(cx + 28, baseY - 92), 44, crown);
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) {
    return oldDelegate.state != state;
  }
}
