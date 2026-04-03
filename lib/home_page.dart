import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tree_model.dart';
import 'tree_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TreeService _treeService = TreeService();

  TreeModel? _tree;
  bool _loading = true;
  bool _watering = false;

  late final AnimationController _swayController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Small continuous left-right sway.
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Short pulse when the user waters.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tree = await _treeService.loadTree();
    if (!mounted) return;
    setState(() {
      _tree = tree;
      _loading = false;
    });
  }

  Future<void> _waterToday() async {
    if (_tree == null || _watering) return;
    if (_tree!.hasWateredToday) return;
    if (_tree!.healthState == TreeHealthState.dead) return;

    setState(() => _watering = true);

    final updated = await _treeService.waterToday();
    await _pulseController.forward(from: 0);

    if (!mounted) return;
    setState(() {
      _tree = updated;
      _watering = false;
    });
  }

  Future<void> _restart() async {
    final updated = await _treeService.restartTree();
    if (!mounted) return;
    setState(() => _tree = updated);
  }

  @override
  void dispose() {
    _swayController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _tree;

    return Scaffold(
      body: SafeArea(
        child: _loading || tree == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'MyTree',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Water once a day to help it grow.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 17,
                          ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _swayController,
                            _pulseAnimation,
                          ]),
                          builder: (context, _) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Transform.rotate(
                                angle: _treeSwayAngle(tree),
                                child: TreeView(tree: tree),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusTitle(tree),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E5449),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _streakLabel(tree.streakDays),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF66756D),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (tree.healthState == TreeHealthState.dead)
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: ElevatedButton(
                          onPressed: _watering ? null : _restart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C8D7C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: const Text(
                            'Plant again',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: ElevatedButton(
                          onPressed: tree.hasWateredToday ? null : _waterToday,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C8D7C),
                            disabledBackgroundColor: const Color(0xFFB8CAC1),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF6F7F78),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          child: Text(
                            tree.hasWateredToday ? 'Watered today' : 'Water today',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  double _treeSwayAngle(TreeModel tree) {
    if (tree.healthState == TreeHealthState.dead) return 0;
    final t = _swayController.value;
    final amplitude = switch (tree.growthStage) {
      TreeGrowthStage.seed => 0.015,
      TreeGrowthStage.sprout => 0.02,
      TreeGrowthStage.small => 0.025,
      TreeGrowthStage.young => 0.02,
      TreeGrowthStage.mature => 0.015,
    };
    return math.sin(t * math.pi * 2) * amplitude;
  }

  String _statusTitle(TreeModel tree) {
    // Exact copy requested by the product spec.
    switch (tree.healthState) {
      case TreeHealthState.healthy:
        return 'Healthy';
      case TreeHealthState.thirsty:
        return 'Needs water';
      case TreeHealthState.wilting:
        return 'Wilting';
      case TreeHealthState.dead:
        return 'Dead';
    }
  }

  String _streakLabel(int streak) {
    if (streak == 1) return 'Streak: 1 day';
    return 'Streak: $streak days';
  }
}

class TreeView extends StatelessWidget {
  final TreeModel tree;

  const TreeView({
    super.key,
    required this.tree,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tree.healthState);

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 36,
            child: Container(
              width: 230,
              height: 36,
              decoration: BoxDecoration(
                color: palette.ground,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 52,
            child: Container(
              width: 92,
              height: 30,
              decoration: BoxDecoration(
                color: palette.soil,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 72,
            child: _buildTreeShape(palette),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeShape(_TreePalette palette) {
    switch (tree.growthStage) {
      case TreeGrowthStage.seed:
        return SizedBox(
          width: 64,
          height: 90,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 36,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.sprout:
        return SizedBox(
          width: 84,
          height: 120,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 24,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 18,
                left: 14,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 26,
                    height: 18,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 14,
                child: Transform.rotate(
                  angle: 0.55,
                  child: Container(
                    width: 28,
                    height: 18,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.small:
        return SizedBox(
          width: 120,
          height: 150,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 26,
                height: 84,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 8,
                child: Container(
                  width: 84,
                  height: 58,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.young:
        return SizedBox(
          width: 150,
          height: 180,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 28,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                top: 24,
                child: Container(
                  width: 110,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 34,
                child: Container(
                  width: 46,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 30,
                child: Container(
                  width: 42,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.mature:
        return SizedBox(
          width: 180,
          height: 210,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 34,
                height: 115,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Positioned(
                top: 40,
                child: Container(
                  width: 130,
                  height: 88,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 28,
                child: Container(
                  width: 54,
                  height: 50,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 24,
                child: Container(
                  width: 56,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 12,
                child: Container(
                  width: 46,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              Positioned(
                top: 30,
                right: 10,
                child: Container(
                  width: 44,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  _TreePalette _paletteFor(TreeHealthState state) {
    switch (state) {
      case TreeHealthState.healthy:
        return const _TreePalette(
          leaf: Color(0xFF63B66A),
          trunk: Color(0xFF6B4B3E),
          soil: Color(0xFF846258),
          ground: Color(0xFFDDE9DD),
        );
      case TreeHealthState.thirsty:
        return const _TreePalette(
          leaf: Color(0xFF9CB86A),
          trunk: Color(0xFF6B4B3E),
          soil: Color(0xFF8B6A5F),
          ground: Color(0xFFE2E7D9),
        );
      case TreeHealthState.wilting:
        return const _TreePalette(
          leaf: Color(0xFFC0A85E),
          trunk: Color(0xFF705045),
          soil: Color(0xFF8E6E63),
          ground: Color(0xFFE9E0D1),
        );
      case TreeHealthState.dead:
        return const _TreePalette(
          leaf: Color(0xFF9D9488),
          trunk: Color(0xFF6E615A),
          soil: Color(0xFF88746A),
          ground: Color(0xFFE3DDD8),
        );
    }
  }
}

class _TreePalette {
  final Color leaf;
  final Color trunk;
  final Color soil;
  final Color ground;

  const _TreePalette({
    required this.leaf,
    required this.trunk,
    required this.soil,
    required this.ground,
  });
}
