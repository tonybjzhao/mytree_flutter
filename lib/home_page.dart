import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'premium_service.dart';

import 'tree_collection_model.dart';
import 'tree_model.dart';
import 'tree_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TreeService _treeService = TreeService();

  final PremiumService _premiumService = PremiumService();

  TreeCollectionModel? _collection;
  bool _premiumUnlocked = false;
  bool _shouldAddAfterUnlock = false;
  bool _loading = true;
  bool _watering = false;

  late final AnimationController _swayController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _dropController;
  late final Animation<double> _dropAnimation;

  Timer? _feedbackTimer;
  String? _waterButtonOverride;

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

    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dropAnimation = Tween<double>(begin: -90, end: 20).animate(
      CurvedAnimation(parent: _dropController, curve: Curves.easeIn),
    );

    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final collection = await _treeService.loadCollection();
    final premium = await _premiumService.isPremiumUnlocked();
    if (!mounted) return;
    setState(() {
      _collection = collection;
      _premiumUnlocked = premium;
      _loading = false;
    });
  }

  Future<void> _waterToday() async {
    final tree = _collection?.currentTree;
    if (tree == null || _watering) return;
    if (tree.hasWateredToday) return;
    if (tree.healthState == TreeHealthState.dead) return;

    setState(() => _watering = true);

    HapticFeedback.lightImpact();
    setState(() => _waterButtonOverride = 'It feels better now');

    // Overlap effects: drop starts, tree pulse reacts before drop finishes.
    _dropController.forward(from: 0);
    _pulseController.forward(from: 0);

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _waterButtonOverride = null);
    });

    final updatedCollection = await _treeService.waterCurrentTree();
    if (!mounted) return;
    setState(() {
      _collection = updatedCollection;
      _watering = false;
    });
  }

  Future<void> _restart() async {
    final updated = await _treeService.restartCurrentTree();
    if (!mounted) return;
    setState(() => _collection = updated);
  }

  Future<void> _selectTree(int index) async {
    final updated = await _treeService.selectTree(index);
    if (!mounted) return;
    setState(() => _collection = updated);
  }

  Future<void> _handleAddTree() async {
    final collection = _collection;
    if (collection == null) return;

    // Free users can only keep 1 tree.
    final freeLimitReached =
        !_premiumUnlocked && collection.trees.isNotEmpty;
    if (freeLimitReached) {
      _shouldAddAfterUnlock = true;
      _showPaywall();
      return;
    }

    _shouldAddAfterUnlock = false;
    final updated = await _treeService.addTree();
    if (!mounted) return;
    setState(() => _collection = updated);
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DED9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🌱   🌿   🌳',
                  style: TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Grow more than one life',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E5449),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Care for different parts of your life.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF66756D),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _premiumService.unlockPremium();
                      if (!mounted) return;

                      setState(() => _premiumUnlocked = true);

                      if (_shouldAddAfterUnlock) {
                        _shouldAddAfterUnlock = false;
                        final updated = await _treeService.addTree();
                        if (!mounted) return;
                        setState(() => _collection = updated);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C8D7C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Unlock more trees',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  r'$2.99 one-time',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7B8A83),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text(
                    'Restore',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5C8D7C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _swayController.dispose();
    _pulseController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _collection?.currentTree;

    return Scaffold(
      body: SafeArea(
        child: _loading || tree == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _TreeSwitcher(
                      trees: _collection!.trees,
                      currentIndex: _collection!.currentIndex,
                      onSelect: _selectTree,
                      onAdd: _handleAddTree,
                    ),
                    const SizedBox(height: 14),
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
                      child: Align(
                        alignment: const Alignment(0, -0.15),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _swayController,
                            _pulseAnimation,
                            _dropAnimation,
                          ]),
                          builder: (context, _) {
                            return SizedBox(
                              width: 320,
                              height: 320,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _dropAnimation,
                                    builder: (context, _) {
                                      if (_dropController.isDismissed) {
                                        return const SizedBox.shrink();
                                      }
                                      return Positioned(
                                        top: _dropAnimation.value,
                                        child: Opacity(
                                          opacity: (1 - _dropController.value)
                                              .clamp(0.0, 1.0),
                                          child: Transform.rotate(
                                            angle: 0.2,
                                            child: Container(
                                              width: 14,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7EC8E3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Transform.scale(
                                    scale: 1.4 * _pulseAnimation.value,
                                    child: Transform.rotate(
                                      angle: _treeSwayAngle(tree),
                                      child: TreeView(tree: tree),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusTitle(tree),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E5449),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _streakLabel(tree.streakDays),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFF66756D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _supportLine(tree),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B8A83),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          onPressed:
                              (tree.hasWateredToday || _watering) ? null : _waterToday,
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
                            _waterButtonOverride ??
                                (tree.hasWateredToday
                                    ? 'Watered today'
                                    : 'Water today'),
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
    switch (tree.healthState) {
      case TreeHealthState.healthy:
        return 'Doing well 🌿';
      case TreeHealthState.thirsty:
        return 'A bit thirsty';
      case TreeHealthState.wilting:
        return 'Struggling…';
      case TreeHealthState.dead:
        return 'Your tree waited for you';
    }
  }

  String _supportLine(TreeModel tree) {
    switch (tree.healthState) {
      case TreeHealthState.healthy:
        return tree.hasWateredToday
            ? 'You cared for it today.'
            : 'A little care each day.';
      case TreeHealthState.thirsty:
        return 'A small sip today would help.';
      case TreeHealthState.wilting:
        return 'It still has a chance if you return soon.';
      case TreeHealthState.dead:
        return 'You can always plant a new one.';
    }
  }

  String _streakLabel(int streak) {
    if (streak == 1) return 'Streak: 1 day';
    return 'Streak: $streak days';
  }
}

class _TreeSwitcher extends StatelessWidget {
  const _TreeSwitcher({
    required this.trees,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final List<TreeModel> trees;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trees.length + 1,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == trees.length) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EFEA),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF5C8D7C),
                ),
              ),
            );
          }

          final tree = trees[index];
          final selected = index == currentIndex;

          return GestureDetector(
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 56 : 48,
              height: selected ? 56 : 48,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFDDEADF)
                    : const Color(0xFFF0F4F1),
                borderRadius: BorderRadius.circular(28),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF5C8D7C).withValues(
                            alpha: 0.14,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Transform.scale(
                  // Reuse the same TreeView drawing system, scaled down.
                  scale: selected ? 0.22 : 0.18,
                  child: TreeView(tree: tree),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    if (tree.healthState == TreeHealthState.dead) {
      // Dead state: no leaves, thinner, slightly tilted trunk.
      return Transform.rotate(
        angle: -0.12,
        child: SizedBox(
          width: 80,
          height: 130,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 14,
              height: 90,
              decoration: BoxDecoration(
                color: palette.trunk,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      );
    }
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
