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
  static const int _freeLockedSlots = 2;

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
  late final Animation<double> _glowScaleAnimation;
  late final Animation<double> _glowOpacityAnimation;
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
        tween: Tween(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
    _glowScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.7,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
    ]).animate(_pulseController);
    _glowOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
    ]).animate(_pulseController);

    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dropAnimation = Tween<double>(
      begin: -90,
      end: 20,
    ).animate(CurvedAnimation(parent: _dropController, curve: Curves.easeIn));

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
    final freeLimitReached = !_premiumUnlocked && collection.trees.isNotEmpty;
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
                const Text('🌱   🌿   🌳', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 18),
                const Text(
                  'Grow more lives',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E5449),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Each tree holds a part of your life.',
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
                      await _premiumService.unlockPremium();
                      if (!mounted) return;
                      if (!sheetContext.mounted) return;

                      Navigator.of(sheetContext).pop();
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
                      'Grow more lives 🌱',
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
                  style: TextStyle(fontSize: 14, color: Color(0xFF7B8A83)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text(
                    'Restore',
                    style: TextStyle(fontSize: 14, color: Color(0xFF5C8D7C)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your lives',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B8A83),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TreeSwitcher(
                      trees: _collection!.trees,
                      currentIndex: _collection!.currentIndex,
                      premiumUnlocked: _premiumUnlocked,
                      lockedSlotCount: _freeLockedSlots,
                      onSelect: _selectTree,
                      onLockedTap: () {
                        _shouldAddAfterUnlock = true;
                        _showPaywall();
                      },
                      onAdd: _handleAddTree,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'MyTree',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A little care each day helps life unfold.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(fontSize: 17),
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
                                  FadeTransition(
                                    opacity: _glowOpacityAnimation,
                                    child: ScaleTransition(
                                      scale: _glowScaleAnimation,
                                      child: Container(
                                        width: 190,
                                        height: 190,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFF0E7A6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFF6E9A5,
                                              ).withValues(alpha: 0.34),
                                              blurRadius: 36,
                                              spreadRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
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
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      final fade = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                      );
                                      final scale = Tween<double>(
                                        begin: 0.96,
                                        end: 1.0,
                                      ).animate(fade);
                                      return FadeTransition(
                                        opacity: fade,
                                        child: ScaleTransition(
                                          scale: scale,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Transform.scale(
                                      key: ValueKey(
                                        '${_collection!.currentIndex}-${tree.streakDays}-${tree.healthState.name}',
                                      ),
                                      scale: 1.4 * _pulseAnimation.value,
                                      child: Transform.rotate(
                                        angle: _treeSwayAngle(tree),
                                        child: TreeView(tree: tree),
                                      ),
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
                          onPressed: (tree.hasWateredToday || _watering)
                              ? null
                              : _waterToday,
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
        return tree.hasWateredToday ? 'Held gently today' : 'Quietly growing';
      case TreeHealthState.thirsty:
        return 'A little thirsty';
      case TreeHealthState.wilting:
        return 'Still waiting for you';
      case TreeHealthState.dead:
        return 'This life faded in silence';
    }
  }

  String _supportLine(TreeModel tree) {
    switch (tree.healthState) {
      case TreeHealthState.healthy:
        return tree.hasWateredToday
            ? 'Your care reached it today.'
            : 'A small return each day keeps it alive.';
      case TreeHealthState.thirsty:
        return 'A gentle sip today would help.';
      case TreeHealthState.wilting:
        return 'Come back soon. It can still recover.';
      case TreeHealthState.dead:
        return 'You can always begin another life.';
    }
  }

  String _streakLabel(int streak) {
    if (streak == 1) return 'Cared for 1 day in a row';
    return 'Cared for $streak days in a row';
  }
}

class _TreeSwitcher extends StatelessWidget {
  const _TreeSwitcher({
    required this.trees,
    required this.currentIndex,
    required this.premiumUnlocked,
    required this.lockedSlotCount,
    required this.onSelect,
    required this.onLockedTap,
    required this.onAdd,
  });

  final List<TreeModel> trees;
  final int currentIndex;
  final bool premiumUnlocked;
  final int lockedSlotCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onLockedTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final itemCount = premiumUnlocked
        ? trees.length + 1
        : trees.length + lockedSlotCount + 1;

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == itemCount - 1) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EFEA),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.add, color: Color(0xFF5C8D7C)),
              ),
            );
          }

          if (index >= trees.length) {
            if (!premiumUnlocked) {
              return GestureDetector(
                onTap: onLockedTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3EF),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFDCE3DC)),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF8E9B94),
                    size: 20,
                  ),
                ),
              );
            }

            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F4),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFDCE7DF)),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: Color(0xFF9AB39D),
                  size: 22,
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
                          color: const Color(
                            0xFF5C8D7C,
                          ).withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  _slotEmoji(tree),
                  style: TextStyle(fontSize: selected ? 24 : 20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _slotEmoji(TreeModel tree) {
    if (tree.healthState == TreeHealthState.dead) return '☠️';
    return switch (tree.growthStage) {
      TreeGrowthStage.seed => '🌱',
      TreeGrowthStage.sprout || TreeGrowthStage.small => '🌿',
      TreeGrowthStage.young || TreeGrowthStage.mature => '🌳',
    };
  }
}

class TreeView extends StatelessWidget {
  final TreeModel tree;

  const TreeView({super.key, required this.tree});

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
          Positioned(bottom: 72, child: _buildTreeShape(palette)),
        ],
      ),
    );
  }

  Widget _buildTreeShape(_TreePalette palette) {
    if (tree.healthState == TreeHealthState.dead) {
      return Transform.rotate(
        angle: -0.12,
        child: SizedBox(
          width: 94,
          height: 142,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 16,
                height: 98,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Positioned(
                bottom: 70,
                left: 28,
                child: Transform.rotate(
                  angle: -0.9,
                  child: Container(
                    width: 30,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.trunk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 82,
                right: 24,
                child: Transform.rotate(
                  angle: 0.8,
                  child: Container(
                    width: 24,
                    height: 7,
                    decoration: BoxDecoration(
                      color: palette.trunk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    switch (tree.growthStage) {
      case TreeGrowthStage.seed:
        return SizedBox(
          width: 76,
          height: 104,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 14,
                height: 62,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 8,
                child: Transform.rotate(
                  angle: -0.38,
                  child: Container(
                    width: 34,
                    height: 20,
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

      case TreeGrowthStage.sprout:
        return SizedBox(
          width: 96,
          height: 126,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 16,
                height: 74,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 16,
                left: 10,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: 34,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Transform.rotate(
                  angle: 0.55,
                  child: Container(
                    width: 36,
                    height: 20,
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
          width: 138,
          height: 162,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 20,
                height: 88,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 18,
                child: Container(
                  width: 92,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 20,
                child: Container(
                  width: 52,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: Container(
                  width: 46,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.young:
        return SizedBox(
          width: 162,
          height: 190,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 28,
                height: 102,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                top: 42,
                child: Container(
                  width: 116,
                  height: 70,
                  decoration: BoxDecoration(
                    color: palette.leaf,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 26,
                child: Container(
                  width: 54,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 22,
                child: Container(
                  width: 56,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 68,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        );

      case TreeGrowthStage.mature:
        return SizedBox(
          width: 192,
          height: 220,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 34,
                height: 120,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Positioned(
                top: 54,
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
                top: 12,
                left: 32,
                child: Container(
                  width: 58,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 30,
                child: Container(
                  width: 60,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
              Positioned(
                top: 34,
                left: 10,
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
                top: 38,
                right: 8,
                child: Container(
                  width: 44,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 74,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.leaf.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(32),
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
