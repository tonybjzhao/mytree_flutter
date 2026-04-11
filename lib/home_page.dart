import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_clock.dart';
import 'create_tree_sheet.dart';
import 'iap_service.dart';
import 'life_category.dart';
import 'premium_service.dart';

import 'tree_collection_model.dart';
import 'tree_slot_icon.dart';
import 'tree_model.dart';
import 'tree_service.dart';

enum TreePageVisualState { growing, completed, soothed, thirsty, wilting, dead }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const String _onboardingSeenKey = 'mytree_onboarding_seen_v1';
  static const String _holdStateDateKey = 'mytree_hold_state_date_v1';
  static const String _holdStateTreeIdsKey = 'mytree_hold_state_tree_ids_v1';
  static const String _talkStateDateKey = 'mytree_talk_state_date_v1';
  static const String _talkStateTreeIdsKey = 'mytree_talk_state_tree_ids_v1';

  final TreeService _treeService = TreeService();
  final PremiumService _premiumService = PremiumService();
  final IapService _iapService = IapService();

  TreeCollectionModel? _collection;
  bool _premiumUnlocked = false;
  bool _purchaseBusy = false;
  bool _paywallOpen = false;
  bool _shouldAddAfterUnlock = false;
  bool _showOnboardingCard = false;
  bool _loading = true;
  bool _watering = false;

  late final AnimationController _breatheController;
  late final AnimationController _swayController;
  late final Animation<double> _breatheScaleAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowScaleAnimation;
  late final Animation<double> _glowOpacityAnimation;
  late final AnimationController _dropController;
  late final Animation<double> _dropAnimation;

  Timer? _feedbackTimer;
  Timer? _careToastTimer;
  Timer? _milestoneBadgeTimer;
  String? _waterButtonOverride;
  OverlayEntry? _careToastEntry;
  bool _showMilestoneBadgeGlow = false;
  bool _showDebugPanel = false;
  String? _debugStateLine;
  bool _heldToday = false;
  String? _heldTreeId;
  Set<String> _heldTreeIdsForDate = <String>{};
  bool _talkedToday = false;
  String? _talkedTreeId;
  Set<String> _talkedTreeIdsForDate = <String>{};

  Set<LifeCategory> get _usedCategories =>
      _collection?.trees.map((tree) => tree.category).toSet() ?? {};

  bool get _allCategoriesUsed =>
      _usedCategories.length >= LifeCategory.values.length;

  bool get _canAddMoreTrees {
    if (_collection == null) return false;
    if (!_premiumUnlocked) return _collection!.trees.isEmpty;
    return !_allCategoriesUsed;
  }

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Small continuous left-right sway.
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _breatheScaleAnimation = Tween<double>(
      begin: 0.985,
      end: 1.015,
    ).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

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
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool(_onboardingSeenKey) ?? false;
    _restoreInteractionState(prefs, collection);
    if (!mounted) return;
    setState(() {
      _collection = collection;
      _premiumUnlocked = premium;
      _showOnboardingCard = !onboardingSeen;
      _loading = false;
    });
    _initIap();
  }

  Future<void> _initIap() async {
    await _iapService.init(
      onPremiumUnlocked: () async {
        await _premiumService.setPremium(true);
        if (!mounted) return;
        setState(() {
          _premiumUnlocked = true;
          _purchaseBusy = false;
        });
        if (_paywallOpen) {
          _paywallOpen = false;
          Navigator.of(context).pop();
        }
        if (_shouldAddAfterUnlock) {
          _shouldAddAfterUnlock = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openCreateTreeSheet();
          });
        }
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _purchaseBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      onInfo: (message) => debugPrint('[IAP] $message'),
    );
  }

  Future<void> _dismissOnboardingCard() async {
    if (!_showOnboardingCard) return;
    setState(() => _showOnboardingCard = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  Future<void> _waterToday() async {
    final tree = _collection?.currentTree;
    if (tree == null || _watering) return;
    if (tree.hasWateredToday) return;
    if (tree.healthState == TreeHealthState.dead) return;
    final previousStreak = tree.streakDays;

    setState(() => _watering = true);

    HapticFeedback.lightImpact();
    _playTreeFeedback(
      showDrop: true,
      buttonLabel: 'It feels better now',
      duration: const Duration(seconds: 1),
    );

    final updatedCollection = await _treeService.waterCurrentTree();
    if (!mounted) return;
    setState(() {
      _collection = updatedCollection;
      _watering = false;
      _heldToday = false;
      _heldTreeId = null;
      _talkedToday = false;
      _talkedTreeId = null;
    });
    _heldTreeIdsForDate.remove(updatedCollection.currentTree.id);
    _talkedTreeIdsForDate.remove(updatedCollection.currentTree.id);
    await _persistInteractionState();

    final newStreak = updatedCollection.currentTree.streakDays;
    final milestone = _streakMilestoneCopy(newStreak);
    final reachedMilestone =
        milestone != null && newStreak > previousStreak;

    if (reachedMilestone) {
      HapticFeedback.mediumImpact();
      _playTreeFeedback(
        buttonLabel: 'Milestone reached',
        duration: const Duration(milliseconds: 1200),
      );
      _triggerMilestoneBadgeGlow();
      _showMilestoneToast(updatedCollection.currentTree);
      return;
    }

    _showCareToast(updatedCollection.currentTree.category);
  }

  Future<void> _holdGently() async {
    final tree = _collection?.currentTree;
    if (tree == null || _watering) return;
    if (tree.healthState == TreeHealthState.dead) return;
    if (!tree.hasWateredToday) return;
    if (_isHeldForCurrentTree(tree)) return;

    HapticFeedback.selectionClick();
    _playTreeFeedback();
    setState(() {
      _heldToday = true;
      _heldTreeId = tree.id;
    });
    _heldTreeIdsForDate.add(tree.id);
    await _persistInteractionState();
    _showHoldToast();
  }

  Future<void> _saySomething() async {
    final tree = _collection?.currentTree;
    if (tree == null || _watering) return;
    if (tree.healthState == TreeHealthState.dead) return;
    if (!tree.hasWateredToday) return;
    if (_isTalkedForCurrentTree(tree)) return;

    HapticFeedback.selectionClick();
    _playTreeFeedback();
    setState(() {
      _talkedToday = true;
      _talkedTreeId = tree.id;
    });
    _talkedTreeIdsForDate.add(tree.id);
    await _persistInteractionState();
    _showTalkToast();
  }

  Future<void> _restart() async {
    final updated = await _treeService.restartCurrentTree();
    if (!mounted) return;
    _heldTreeIdsForDate.remove(updated.currentTree.id);
    _talkedTreeIdsForDate.remove(updated.currentTree.id);
    await _persistInteractionState();
    setState(() {
      _collection = updated;
      _syncInteractionStateForCurrentTree(updated);
    });
  }

  Future<void> _selectTree(int index) async {
    final updated = await _treeService.selectTree(index);
    if (!mounted) return;
    setState(() {
      _collection = updated;
      _syncInteractionStateForCurrentTree(updated);
    });
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
    _openCreateTreeSheet();
  }

  void _openCreateTreeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CreateTreeSheet(
          usedCategories: _usedCategories,
          onCreate: _createTree,
        );
      },
    );
  }

  Future<void> _createTree(LifeCategory category) async {
    final updated = await _treeService.addTree(category);
    if (!mounted) return;
    setState(() {
      _collection = updated;
      _syncInteractionStateForCurrentTree(updated);
    });
  }

  bool get _isNightTime {
    final hour = AppClock.now().hour;
    return hour >= 19 || hour < 6;
  }

  void _playTreeFeedback({
    bool showDrop = false,
    String? buttonLabel,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    if (showDrop) {
      _dropController.forward(from: 0);
    }
    _pulseController.forward(from: 0);
    if (buttonLabel == null) return;
    _feedbackTimer?.cancel();
    setState(() => _waterButtonOverride = buttonLabel);
    _feedbackTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _waterButtonOverride = null);
    });
  }

  void _replayCompletedMoment() {
    final tree = _collection?.currentTree;
    if (tree == null || !tree.hasWateredToday || _watering) return;

    HapticFeedback.selectionClick();
    _playTreeFeedback(
      buttonLabel: _isNightTime ? 'Sleeping peacefully' : 'It smiles today',
    );
    _showToastMessage(
      _isNightTime
          ? 'It settles in for the night.'
          : 'It brightens when you come back.',
    );
  }

  String _headerSubtitle(TreeModel tree) {
    final base = '${tree.category.title} tree ${tree.category.emoji}';
    if (!_isNightTime) return base;
    if (tree.hasWateredToday) return '$base · Resting tonight';
    return '$base · Waiting quietly';
  }

  String _growthStageLabel(TreeModel tree) {
    return switch (tree.growthStage) {
      TreeGrowthStage.seed => 'Seed stage',
      TreeGrowthStage.sprout => 'Sprouting',
      TreeGrowthStage.small => 'Growing leaves',
      TreeGrowthStage.young => 'Young tree',
      TreeGrowthStage.mature => 'Rooted canopy',
    };
  }

  Color _leafBurstColor(LifeCategory category) {
    return switch (category) {
      LifeCategory.health => const Color(0xFF6AB56C),
      LifeCategory.family => const Color(0xFF78BB72),
      LifeCategory.work => const Color(0xFF5EA78E),
      LifeCategory.rest => const Color(0xFF7A98B3),
    };
  }

  String _stageBadgeText(TreeModel tree) {
    final day = math.max(tree.streakDays, 1);
    return 'Day $day · ${_growthStageLabel(tree)}';
  }

  String _todayDateKey() {
    final now = AppClock.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  TreeModel _debugAdjustedTree(TreeModel tree) {
    if (!kDebugMode) return tree;
    if (!TreeDebugOverrides.hasOverrides) return tree;

    var adjusted = tree;

    if (TreeDebugOverrides.fakeTreeAgeDays != null) {
      final age = TreeDebugOverrides.fakeTreeAgeDays!.clamp(0, 3650);
      final createdAt = AppClock.now().subtract(Duration(days: age));
      adjusted = adjusted.copyWith(createdAtIso: createdAt.toIso8601String());
    }

    if (TreeDebugOverrides.fakeDaysSinceLastWater != null) {
      final days = TreeDebugOverrides.fakeDaysSinceLastWater!.clamp(0, 3650);
      final wateredDate = AppClock.now().subtract(Duration(days: days));
      adjusted = adjusted.copyWith(
        lastWateredDateIso: _formatDateOnly(wateredDate),
        isDead: days >= 7,
      );
    }

    if (TreeDebugOverrides.fakeStreak != null) {
      adjusted = adjusted.copyWith(
        streakDays: TreeDebugOverrides.fakeStreak!.clamp(0, 5000),
      );
    }

    return adjusted;
  }

  Future<void> _refreshAndLogDebugState(String action) async {
    await _load();
    if (!mounted) return;

    final sourceTree = _collection?.currentTree;
    if (sourceTree == null) {
      debugPrint('[DEBUG_PANEL] action=$action offset=${AppClock.debugDayOffset} tree=null');
      setState(() {
        _debugStateLine =
            'action=$action | offset=${AppClock.debugDayOffset} | tree=null';
      });
      return;
    }

    final tree = _debugAdjustedTree(sourceTree);
    debugPrint(
      '[DEBUG_PANEL] action=$action offset=${AppClock.debugDayOffset} '
      'missedDays=${tree.missedDays} health=${tree.healthState.name} '
      'streak=${tree.streakDays} wateredToday=${tree.hasWateredToday}',
    );

    setState(() {
      _debugStateLine =
          'action=$action | offset=${AppClock.debugDayOffset} | '
          'missed=${tree.missedDays} | health=${tree.healthState.name} | '
          'streak=${tree.streakDays} | watered=${tree.hasWateredToday}';
    });
  }

  String _formatDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _restoreInteractionState(
    SharedPreferences prefs,
    TreeCollectionModel collection,
  ) {
    final today = _todayDateKey();
    final holdStoredDate = prefs.getString(_holdStateDateKey);
    final holdStoredIds =
        prefs.getStringList(_holdStateTreeIdsKey) ?? <String>[];
    final talkStoredDate = prefs.getString(_talkStateDateKey);
    final talkStoredIds =
        prefs.getStringList(_talkStateTreeIdsKey) ?? <String>[];

    if (holdStoredDate == today) {
      _heldTreeIdsForDate = holdStoredIds.toSet();
    } else {
      _heldTreeIdsForDate = <String>{};
      prefs.setString(_holdStateDateKey, today);
      prefs.setStringList(_holdStateTreeIdsKey, <String>[]);
    }

    if (talkStoredDate == today) {
      _talkedTreeIdsForDate = talkStoredIds.toSet();
    } else {
      _talkedTreeIdsForDate = <String>{};
      prefs.setString(_talkStateDateKey, today);
      prefs.setStringList(_talkStateTreeIdsKey, <String>[]);
    }

    _syncInteractionStateForCurrentTree(collection);
  }

  Future<void> _persistInteractionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_holdStateDateKey, _todayDateKey());
    await prefs.setStringList(
      _holdStateTreeIdsKey,
      _heldTreeIdsForDate.toList(growable: false),
    );
    await prefs.setString(_talkStateDateKey, _todayDateKey());
    await prefs.setStringList(
      _talkStateTreeIdsKey,
      _talkedTreeIdsForDate.toList(growable: false),
    );
  }

  void _syncInteractionStateForCurrentTree(TreeCollectionModel collection) {
    final tree = collection.currentTree;
    final held = tree.hasWateredToday && _heldTreeIdsForDate.contains(tree.id);
    final talked =
        tree.hasWateredToday && _talkedTreeIdsForDate.contains(tree.id);
    _heldToday = held;
    _heldTreeId = held ? tree.id : null;
    _talkedToday = talked;
    _talkedTreeId = talked ? tree.id : null;
  }

  void _showPaywall() {
    _paywallOpen = true;
    showModalBottomSheet<void>(
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
                    onPressed: _purchaseBusy
                        ? null
                        : () async {
                            try {
                              setState(() => _purchaseBusy = true);
                              await _iapService.buyPremium();
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _purchaseBusy = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Purchase failed: $e')),
                              );
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
                    child: _purchaseBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Grow more lives 🌱',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_iapService.premiumProduct?.price ?? r'$2.99'} one-time',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF7B8A83)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _purchaseBusy
                      ? null
                      : () async {
                          try {
                            setState(() => _purchaseBusy = true);
                            await _iapService.restorePurchases();
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _purchaseBusy = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Restore failed: $e')),
                            );
                          }
                        },
                  child: const Text(
                    'Restore Purchase',
                    style: TextStyle(fontSize: 14, color: Color(0xFF5C8D7C)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _paywallOpen = false);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _careToastTimer?.cancel();
    _milestoneBadgeTimer?.cancel();
    _removeCareToast();
    _breatheController.dispose();
    _swayController.dispose();
    _pulseController.dispose();
    _dropController.dispose();
    _iapService.dispose();
    super.dispose();
  }

  void _showCareToast(LifeCategory category) {
    _showToastMessage(_careMessageFor(category), category: category);
  }

  void _showHoldToast() {
    _showToastMessage('It remembers your kindness.', category: _activeCategory);
  }

  void _showTalkToast() {
    _showToastMessage(
      'It feels seen when you speak to it.',
      category: _activeCategory,
    );
  }

  void _showMilestoneToast(TreeModel tree) {
    final milestone = _streakMilestoneCopy(tree.streakDays);
    if (milestone == null) return;
    _showToastMessage(
      'Day ${tree.streakDays} · $milestone',
      category: tree.category,
    );
  }

  void _triggerMilestoneBadgeGlow() {
    _milestoneBadgeTimer?.cancel();
    setState(() => _showMilestoneBadgeGlow = true);
    _milestoneBadgeTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() => _showMilestoneBadgeGlow = false);
    });
  }

  void _showToastMessage(String message, {LifeCategory? category}) {
    _removeCareToast();

    final overlay = Overlay.of(context);
    if (overlay.mounted == false) return;
    final toastCategory = category ?? _activeCategory;

    _careToastEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 24,
          right: 24,
          bottom: 108,
          child: IgnorePointer(
            child: _CareToast(
              message: message,
              accentColor: _accentColor(toastCategory),
            ),
          ),
        );
      },
    );

    overlay.insert(_careToastEntry!);
    _careToastTimer?.cancel();
    _careToastTimer = Timer(const Duration(seconds: 2), _removeCareToast);
  }

  LifeCategory get _activeCategory =>
      _collection?.currentTree.category ?? LifeCategory.health;

  Color _accentColor(LifeCategory category) {
    return _CategoryTreeStyle.forCategory(category).leaf;
  }

  Color _actionFillColor(LifeCategory category, {required bool isNight}) {
    final accent = _accentColor(category);
    return Color.lerp(accent, const Color(0xFF40645A), isNight ? 0.22 : 0.08) ??
        accent;
  }

  Color _softActionColor(LifeCategory category, {required bool isNight}) {
    final accent = _accentColor(category);
    return Color.lerp(accent, Colors.white, isNight ? 0.82 : 0.74) ?? accent;
  }

  Color _softActionBorderColor(LifeCategory category, {required bool isNight}) {
    final accent = _accentColor(category);
    return Color.lerp(accent, const Color(0xFFC7D6CE), isNight ? 0.48 : 0.36) ??
        accent;
  }

  Color _accentTextColor(LifeCategory category, {required bool isNight}) {
    final accent = _accentColor(category);
    return Color.lerp(accent, const Color(0xFF405A51), isNight ? 0.36 : 0.22) ??
        accent;
  }

  void _removeCareToast() {
    _careToastEntry?.remove();
    _careToastEntry = null;
  }

  String _careMessageFor(LifeCategory category) {
    switch (category) {
      case LifeCategory.health:
        return 'Take care of your health.';
      case LifeCategory.family:
        return 'Stay close to your family.';
      case LifeCategory.work:
        return 'Keep building your work.';
      case LifeCategory.rest:
        return 'Give yourself some rest.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceTree = _collection?.currentTree;
    final tree = sourceTree == null ? null : _debugAdjustedTree(sourceTree);
    final visualState = tree == null
        ? TreePageVisualState.growing
        : _visualStateFor(tree);
    final isNight = _isNightTime;
    final accentFill = tree == null
      ? const Color(0xFF5C8D7C)
      : _actionFillColor(tree.category, isNight: isNight);
    final softAccent = tree == null
      ? const Color(0xFFF6F7F4)
      : _softActionColor(tree.category, isNight: isNight);
    final softBorder = tree == null
      ? const Color(0xFFB8CBC3)
      : _softActionBorderColor(tree.category, isNight: isNight);
    final accentText = tree == null
      ? const Color(0xFF5D706A)
      : _accentTextColor(tree.category, isNight: isNight);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = viewportHeight < 760;
    final heroHeight = (viewportHeight * 0.35).clamp(210.0, 290.0);
    final showDebugPanel = kDebugMode && (!isSmallScreen || _showDebugPanel);

    return Scaffold(
      backgroundColor: isNight ? const Color(0xFFF3F6F1) : const Color(0xFFF7FAF6),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _AmbientGardenBackdrop(
                category: tree?.category ?? LifeCategory.health,
                isNight: isNight,
                visualState: visualState,
              ),
            ),
          ),
          SafeArea(
            child: _loading || tree == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
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
                    TreeSlotsRow(
                      slots: _buildTreeSlots(
                        trees: _collection!.trees,
                        currentIndex: _collection!.currentIndex,
                      ),
                    ),
                    if (kDebugMode && isSmallScreen)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _showDebugPanel = !_showDebugPanel);
                          },
                          icon: Icon(
                            _showDebugPanel
                                ? Icons.expand_less_rounded
                                : Icons.tune_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _showDebugPanel ? 'Hide debug' : 'Debug tools',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF5B7469),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ),
                    if (showDebugPanel)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _DebugTimeTravelPanel(
                          onChanged: _refreshAndLogDebugState,
                        ),
                      ),
                    if (kDebugMode && _debugStateLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF5EE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD5E2D3)),
                          ),
                          child: Text(
                            _debugStateLine!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F665B),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      'MyTree',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _headerSubtitle(tree),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _showMilestoneBadgeGlow
                            ? const Color(0xFFF7F1CF)
                            : (isNight
                                ? const Color(0xFFF0F4EE)
                                : const Color(0xFFF3F8F2)),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _showMilestoneBadgeGlow
                              ? const Color(0xFFE7CE7F)
                              : (isNight
                                  ? const Color(0xFFD7E1D6)
                                  : const Color(0xFFD8E5D9)),
                        ),
                        boxShadow: _showMilestoneBadgeGlow
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE7CE7F)
                                      .withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showMilestoneBadgeGlow) ...[
                            const Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: Color(0xFF9E7A2B),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _stageBadgeText(tree),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _showMilestoneBadgeGlow
                                  ? const Color(0xFF8A6D2A)
                                  : const Color(0xFF607267),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showOnboardingCard)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F8F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD7E4DD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome to MyTree',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E5449),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'This is your first life tree. Water it daily to grow from seed to canopy.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF66756D),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _dismissOnboardingCard,
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: Color(0xFF6C7D75),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: _dismissOnboardingCard,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFF5C8D7C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Start growing'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (!_premiumUnlocked && (_collection?.trees.length ?? 0) == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Your first tree is fully free. Water it daily and watch it grow.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF7B8A83),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: heroHeight,
                      child: Align(
                        alignment: const Alignment(0, -0.2),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _breatheController,
                            _swayController,
                            _pulseController,
                            _dropController,
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
                                          color: isNight
                                              ? const Color(0xFFE7EAC7)
                                              : const Color(0xFFF0E7A6),
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
                                  if (_pulseController.value > 0)
                                    _LeafBurst(
                                      progress: _pulseController.value,
                                      color: _leafBurstColor(tree.category),
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
                                      scale: _heroScaleForStage(tree.growthStage) *
                                          _breatheScaleAnimation.value *
                                          _pulseAnimation.value,
                                      child: Transform.rotate(
                                        angle: _treeSwayAngle(tree),
                                        child: TreeView(
                                          tree: tree,
                                          visualState: visualState,
                                          isNight: isNight,
                                          swayT: _swayController.value,
                                        ),
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
                    const SizedBox(height: 8),
                    Text(
                      _statusTitle(tree),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _statusTitleColor(visualState),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tree.healthState == TreeHealthState.dead
                            ? _deadStreakLabel(tree.streakDays)
                            : _streakLabel(tree.streakDays),
                      style: TextStyle(
                        fontSize: 17,
                        color: _streakColor(visualState),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _supportLine(tree),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _supportColor(visualState),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (tree.healthState == TreeHealthState.dead) ...[
                      _DeadMemoryPill(streakDays: tree.streakDays),
                      // Start again button
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: ElevatedButton(
                          onPressed: _watering ? null : _restart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentFill,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                          ),
                          child: const Text(
                            'Start again',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ] else
                      if (tree.hasWateredToday) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: ElevatedButton(
                            onPressed: _watering ? null : _replayCompletedMoment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: softAccent,
                              foregroundColor: accentText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              child: Text(
                                _waterButtonOverride ?? 'Done today',
                                key: ValueKey(_waterButtonOverride ?? 'Done today'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed:
                                _isHeldForCurrentTree(tree) ? null : _holdGently,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isHeldForCurrentTree(tree)
                                    ? softBorder
                                    : softBorder,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: softAccent,
                            ),
                            child: Text(
                              _isHeldForCurrentTree(tree)
                                  ? 'Held gently today'
                                  : 'Hold gently',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _isHeldForCurrentTree(tree)
                                    ? accentText.withValues(alpha: 0.6)
                                    : accentText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _isTalkedForCurrentTree(tree)
                                ? null
                                : _saySomething,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isTalkedForCurrentTree(tree)
                                    ? softBorder
                                    : softBorder,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: softAccent,
                            ),
                            child: Text(
                              _isTalkedForCurrentTree(tree)
                                  ? 'You spoke to it today'
                                  : 'Say something',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _isTalkedForCurrentTree(tree)
                                    ? accentText.withValues(alpha: 0.6)
                                    : accentText,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: ElevatedButton(
                            onPressed: _watering ? null : _waterToday,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentFill,
                              disabledBackgroundColor: accentFill.withValues(alpha: 0.48),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF6F7F78),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: Text(
                              _waterButtonOverride ?? 'Water today',
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _treeSwayAngle(TreeModel tree) {
    final visualState = _visualStateFor(tree);
    if (visualState == TreePageVisualState.dead) return 0;
    final t = _swayController.value;
    final amplitude = switch (tree.growthStage) {
      TreeGrowthStage.seed => 0.015,
      TreeGrowthStage.sprout => 0.02,
      TreeGrowthStage.small => 0.025,
      TreeGrowthStage.young => 0.02,
      TreeGrowthStage.mature => 0.015,
    } * (_isNightTime ? 0.42 : 1.0);
    final stateFactor = switch (visualState) {
      TreePageVisualState.wilting => 0.5,
      TreePageVisualState.thirsty => 0.75,
      _ => 1.0,
    };
    return _categoryMotionWave(tree.category, t) * amplitude * stateFactor;
  }

  double _categoryMotionWave(LifeCategory category, double t) {
    final base = math.sin(t * math.pi * 2);
    return switch (category) {
      LifeCategory.health => base,
      LifeCategory.family =>
        (base * 0.70) + (math.sin((t + 0.08) * math.pi * 2) * 0.14),
      LifeCategory.work => math.sin(t * math.pi * 2.35) * 0.72,
      LifeCategory.rest => math.sin(t * math.pi * 1.35) * 0.64,
    };
  }

  double _heroScaleForStage(TreeGrowthStage stage) {
    return switch (stage) {
      TreeGrowthStage.seed => 1.14,
      TreeGrowthStage.sprout => 1.25,
      TreeGrowthStage.small => 1.38,
      TreeGrowthStage.young => 1.53,
      TreeGrowthStage.mature => 1.63,
    };
  }

  TreePageVisualState _visualStateFor(TreeModel tree) {
    if (tree.healthState == TreeHealthState.dead) {
      return TreePageVisualState.dead;
    }
    if (tree.healthState == TreeHealthState.wilting) {
      return TreePageVisualState.wilting;
    }
    if (tree.healthState == TreeHealthState.thirsty) {
      return TreePageVisualState.thirsty;
    }
    if (_isHeldForCurrentTree(tree) || _isTalkedForCurrentTree(tree)) {
      return TreePageVisualState.soothed;
    }
    if (tree.hasWateredToday) {
      return TreePageVisualState.completed;
    }
    return TreePageVisualState.growing;
  }

  Color _statusTitleColor(TreePageVisualState state) {
    return switch (state) {
      TreePageVisualState.dead => const Color(0xFF4A5B52),
      TreePageVisualState.wilting => const Color(0xFF606D56),
      TreePageVisualState.thirsty => const Color(0xFF3D5E52),
      TreePageVisualState.soothed => const Color(0xFF355D4F),
      _ => const Color(0xFF2E5449),
    };
  }

  Color _streakColor(TreePageVisualState state) {
    return switch (state) {
      TreePageVisualState.dead => const Color(0xFF6D756F),
      TreePageVisualState.wilting => const Color(0xFF7A7A62),
      TreePageVisualState.thirsty => const Color(0xFF6E776B),
      TreePageVisualState.soothed => const Color(0xFF5D7468),
      _ => const Color(0xFF66756D),
    };
  }

  Color _supportColor(TreePageVisualState state) {
    return switch (state) {
      TreePageVisualState.dead => const Color(0xFF7F8B84),
      TreePageVisualState.wilting => const Color(0xFF89866E),
      TreePageVisualState.thirsty => const Color(0xFF7D8A83),
      TreePageVisualState.soothed => const Color(0xFF72857C),
      _ => const Color(0xFF7B8A83),
    };
  }

  String _statusTitle(TreeModel tree) {
    if (_isNightTime && tree.hasWateredToday) {
      return 'It is resting peacefully';
    }
    if (_isNightTime && !tree.hasWateredToday) {
      return 'Waiting quietly tonight';
    }

    return switch (_visualStateFor(tree)) {
      TreePageVisualState.growing => 'Quietly growing',
      TreePageVisualState.completed => 'Cared for today',
      TreePageVisualState.soothed => _isHeldForCurrentTree(tree)
          ? (_isTalkedForCurrentTree(tree)
              ? 'It feels deeply cared for'
              : 'It feels calm and cared for')
          : 'It feels seen and encouraged',
      TreePageVisualState.thirsty => 'A little thirsty',
      TreePageVisualState.wilting => 'Still waiting for you',
      TreePageVisualState.dead => 'This tree has withered',
    };
  }

  String _supportLine(TreeModel tree) {
    final categoryLine = switch (tree.category) {
      LifeCategory.health => 'Care for your body and wellbeing.',
      LifeCategory.family => 'Care for the people closest to you.',
      LifeCategory.work => 'Care for what you are building.',
      LifeCategory.rest => 'Care for stillness and recovery.',
    };

    if (_isNightTime && tree.hasWateredToday) {
      return 'Come back tomorrow. Something small may change.';
    }
    if (_isNightTime) {
      return 'Even a gentle return tonight still counts.';
    }

    return switch (_visualStateFor(tree)) {
      TreePageVisualState.growing => categoryLine,
      TreePageVisualState.completed => 'Two gentle actions are available today.',
      TreePageVisualState.soothed =>
        (_isHeldForCurrentTree(tree) && _isTalkedForCurrentTree(tree))
            ? 'Come back tomorrow. Something small may change.'
            : 'One more gentle action is available today.',
      TreePageVisualState.thirsty => '${tree.category.title} needs a gentle return today.',
      TreePageVisualState.wilting => 'Come back soon. ${tree.category.title} can still recover.',
      TreePageVisualState.dead => 'A new start can help it grow again.',
    };
  }

  String _streakLabel(int streak) {
    final milestone = _streakMilestoneCopy(streak);
    if (milestone != null) return 'Day $streak · $milestone';
    if (streak == 1) return 'Cared for 1 day in a row';
    return 'Cared for $streak days in a row';
  }

  String? _streakMilestoneCopy(int streak) {
    return switch (streak) {
      1 => 'A new start',
      3 => 'It remembers you',
      7 => 'Growing stronger',
      30 => 'Deeply rooted',
      _ => null,
    };
  }

  String _deadStreakLabel(int streak) {
    if (streak == 1) return 'Cared for 1 day before resting';
    return 'Cared for $streak days before resting';
  }

  bool _isHeldForCurrentTree(TreeModel tree) {
    return _heldToday && _heldTreeId == tree.id && tree.hasWateredToday;
  }

  bool _isTalkedForCurrentTree(TreeModel tree) {
    return _talkedToday && _talkedTreeId == tree.id && tree.hasWateredToday;
  }

  List<TreeSlotData> _buildTreeSlots({
    required List<TreeModel> trees,
    required int currentIndex,
  }) {
    final slots = <TreeSlotData>[
      for (var index = 0; index < trees.length; index++)
        TreeSlotData(
          type: _slotTypeFor(trees[index]),
          selected: index == currentIndex,
          tone: _slotToneFor(trees[index]),
          leafTiltRadians: _slotLeafTiltFor(trees[index]),
          stemHeightFactor: _slotStemHeightFor(trees[index]),
          semanticLabel:
              '${trees[index].category.title} tree, ${_slotStageLabelFor(trees[index])}',
          onTap: () => _selectTree(index),
        ),
    ];

    if (_canAddMoreTrees) {
      slots.add(
        TreeSlotData(
          type: TreeSlotType.add,
          semanticLabel: 'Add a new tree',
          onTap: _handleAddTree,
        ),
      );
    }

    return slots;
  }

  TreeSlotType _slotTypeFor(TreeModel tree) {
    if (tree.healthState == TreeHealthState.dead) {
      return TreeSlotType.youngTree;
    }

    final streak = tree.streakDays;
    if (streak <= 2) return TreeSlotType.seed;
    if (streak <= 6) return TreeSlotType.sprout;
    if (streak <= 13) return TreeSlotType.twinLeaf;
    if (streak <= 29) return TreeSlotType.youngTree;
    return TreeSlotType.matureTree;
  }

  TreeSlotTone _slotToneFor(TreeModel tree) {
    return switch (tree.healthState) {
      TreeHealthState.healthy => TreeSlotTone.healthy,
      TreeHealthState.thirsty => TreeSlotTone.thirsty,
      TreeHealthState.wilting => TreeSlotTone.wilting,
      TreeHealthState.dead => TreeSlotTone.resting,
    };
  }

  String _slotStageLabelFor(TreeModel tree) {
    if (tree.healthState == TreeHealthState.dead) {
      return 'resting tree';
    }

    final streak = tree.streakDays;
    if (streak <= 2) return 'single leaf';
    if (streak <= 6) return 'two leaves';
    if (streak <= 13) return 'growing plant';
    return 'small canopy tree';
  }

  double _slotLeafTiltFor(TreeModel tree) {
    final hash = _slotHash(tree.createdAtIso);
    final normalized = ((hash >> 3) & 0xff) / 255;
    final degrees = -8 + (normalized * 16);
    return degrees * math.pi / 180;
  }

  double _slotStemHeightFor(TreeModel tree) {
    final hash = _slotHash(tree.createdAtIso);
    final normalized = ((hash >> 11) & 0xff) / 255;
    return 0.84 + (normalized * 0.32);
  }

  int _slotHash(String seed) {
    var hash = 2166136261;
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}

class _DebugTimeTravelPanel extends StatelessWidget {
  const _DebugTimeTravelPanel({required this.onChanged});

  final Future<void> Function(String action) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E4D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug: day offset ${AppClock.debugDayOffset}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF557263),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(context, 'D0', () async {
                AppClock.setDebugDayOffset(0);
                await onChanged('D0');
              }),
              _chip(context, 'D1', () async {
                AppClock.setDebugDayOffset(1);
                await onChanged('D1');
              }),
              _chip(context, 'D2', () async {
                AppClock.setDebugDayOffset(2);
                await onChanged('D2');
              }),
              _chip(context, 'D3', () async {
                AppClock.setDebugDayOffset(3);
                await onChanged('D3');
              }),
              _chip(context, 'D4', () async {
                AppClock.setDebugDayOffset(4);
                await onChanged('D4');
              }),
              _chip(context, 'D7', () async {
                AppClock.setDebugDayOffset(7);
                await onChanged('D7');
              }),
              _chip(context, 'Reset', () async {
                AppClock.resetDayOffset();
                TreeDebugOverrides.reset();
                await onChanged('Reset');
              }),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(context, 'Water-0', () async {
                TreeDebugOverrides.fakeDaysSinceLastWater = 0;
                await onChanged('Water-0');
              }),
              _chip(context, 'Water-2', () async {
                TreeDebugOverrides.fakeDaysSinceLastWater = 2;
                await onChanged('Water-2');
              }),
              _chip(context, 'Wilt', () async {
                TreeDebugOverrides.fakeDaysSinceLastWater = 4;
                await onChanged('Wilt');
              }),
              _chip(context, 'Dead', () async {
                TreeDebugOverrides.fakeDaysSinceLastWater = 8;
                await onChanged('Dead');
              }),
              _chip(context, 'Streak-3', () async {
                TreeDebugOverrides.fakeStreak = 3;
                await onChanged('Streak-3');
              }),
              _chip(context, 'Streak-7', () async {
                TreeDebugOverrides.fakeStreak = 7;
                await onChanged('Streak-7');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    Future<void> Function() onTap,
  ) {
    return InkWell(
      onTap: () {
        onTap();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD4E0D3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4F695D),
          ),
        ),
      ),
    );
  }
}

class TreeView extends StatelessWidget {
  final TreeModel tree;
  final TreePageVisualState visualState;
  final bool isNight;
  final double swayT;

  const TreeView({
    super.key,
    required this.tree,
    required this.visualState,
    required this.isNight,
    required this.swayT,
  });

  @override
  Widget build(BuildContext context) {
    final style = _CategoryTreeStyle.forCategory(tree.category);
    final palette = _paletteFor(visualState, style, isNight);
    final variation = _TreeVariation.fromSeed(tree.createdAtIso);
    final stageLift = switch (tree.growthStage) {
      TreeGrowthStage.seed => -12.0,
      TreeGrowthStage.sprout => -5.0,
      TreeGrowthStage.small => 2.0,
      TreeGrowthStage.young => 10.0,
      TreeGrowthStage.mature => 18.0,
    };
    final groundWidth = switch (tree.growthStage) {
      TreeGrowthStage.seed => 202.0,
      TreeGrowthStage.sprout => 214.0,
      TreeGrowthStage.small => 228.0,
      TreeGrowthStage.young => 243.0,
      TreeGrowthStage.mature => 256.0,
    };
    final soilWidth = switch (tree.growthStage) {
      TreeGrowthStage.seed => 76.0,
      TreeGrowthStage.sprout => 83.0,
      TreeGrowthStage.small => 92.0,
      TreeGrowthStage.young => 102.0,
      TreeGrowthStage.mature => 110.0,
    };
    final sleepOffset =
        isNight && visualState != TreePageVisualState.dead ? 11.0 : 0.0;
    final sleepTilt =
        isNight && visualState != TreePageVisualState.dead ? -0.056 : 0.0;
    final moonDriftX = math.sin(swayT * math.pi * 2) * 1.4;
    final moonDriftY = math.cos(swayT * math.pi * 2) * 1.0;
    final moonOpacity =
      (0.26 + (math.sin(swayT * math.pi * 2) * 0.08)).clamp(0.18, 0.36);

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 36,
            child: Container(
              width: groundWidth,
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
              width: soilWidth,
              height: 30,
              decoration: BoxDecoration(
                color: palette.soil,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 72 + stageLift - sleepOffset,
            child: Transform.rotate(
              angle: sleepTilt,
              child: Transform.scale(
                scale: variation.scale,
                child: _buildTreeShape(palette, variation, style),
              ),
            ),
          ),
          if (isNight && visualState != TreePageVisualState.dead)
            Positioned(
              top: 20,
              right: 30,
              child: Opacity(
                opacity: moonOpacity,
                child: Transform.translate(
                  offset: Offset(moonDriftX, moonDriftY),
                  child: Icon(
                    Icons.nightlight_round,
                    size: 18,
                    color: palette.leaf.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeShape(
    _TreePalette palette,
    _TreeVariation variation,
    _CategoryTreeStyle style,
  ) {
    final leafTilt = variation.leafTiltRadians;
    final stemHeightFactor = variation.stemHeightFactor;
    final canopyWidthFactor = style.canopyWidthFactor;
    final topLift = style.topLift;
    final sideOffset = style.sideOffset;

    if (visualState == TreePageVisualState.dead) {
      return Transform.rotate(
        angle: -0.12,
        child: _DeadTreeShape(
          trunkColor: palette.trunk,
          leafColor: palette.leaf,
          stemHeightFactor: stemHeightFactor,
          leafTilt: leafTilt,
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
                height: 62 * stemHeightFactor,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 8 + topLift,
                child: Transform.rotate(
                  angle: -0.38 + leafTilt,
                  child: Container(
                    width: 34 * canopyWidthFactor,
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
                height: 74 * stemHeightFactor,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 16 + topLift,
                left: 10 + sideOffset,
                child: Transform.rotate(
                  angle: -0.5 + leafTilt,
                  child: Container(
                    width: 34 * canopyWidthFactor,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10 + topLift,
                right: 10 - sideOffset,
                child: Transform.rotate(
                  angle: 0.55 + leafTilt,
                  child: Container(
                    width: 36 * canopyWidthFactor,
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
                height: 88 * stemHeightFactor,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Positioned(
                top: 18 + topLift,
                child: Transform.rotate(
                  angle: leafTilt * 0.55,
                  child: Container(
                    width: 92 * canopyWidthFactor,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4 + topLift,
                left: 20 + sideOffset,
                child: Transform.rotate(
                  angle: leafTilt,
                  child: Container(
                    width: 52 * canopyWidthFactor,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8 + topLift,
                right: 16 - sideOffset,
                child: Transform.rotate(
                  angle: leafTilt * 0.8,
                  child: Container(
                    width: 46 * canopyWidthFactor,
                    height: 34,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                    ),
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
                height: 102 * stemHeightFactor,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                top: 42 + topLift,
                child: Transform.rotate(
                  angle: leafTilt * 0.45,
                  child: Container(
                    width: 116 * canopyWidthFactor,
                    height: 70,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10 + topLift,
                left: 26 + sideOffset,
                child: Transform.rotate(
                  angle: leafTilt,
                  child: Container(
                    width: 54 * canopyWidthFactor,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8 + topLift,
                right: 22 - sideOffset,
                child: Transform.rotate(
                  angle: leafTilt * 0.8,
                  child: Container(
                    width: 56 * canopyWidthFactor,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topLift,
                child: Transform.rotate(
                  angle: leafTilt * 0.35,
                  child: Container(
                    width: 68 * canopyWidthFactor,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                    ),
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
                height: 120 * stemHeightFactor,
                decoration: BoxDecoration(
                  color: palette.trunk,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Positioned(
                top: 54 + topLift,
                child: Transform.rotate(
                  angle: leafTilt * 0.4,
                  child: Container(
                    width: 130 * canopyWidthFactor,
                    height: 88,
                    decoration: BoxDecoration(
                      color: palette.leaf,
                      borderRadius: BorderRadius.circular(60),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12 + topLift,
                left: 32 + sideOffset,
                child: Transform.rotate(
                  angle: leafTilt,
                  child: Container(
                    width: 58 * canopyWidthFactor,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10 + topLift,
                right: 30 - sideOffset,
                child: Transform.rotate(
                  angle: leafTilt * 0.8,
                  child: Container(
                    width: 60 * canopyWidthFactor,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 34 + topLift,
                left: 10 + sideOffset,
                child: Transform.rotate(
                  angle: leafTilt * 0.55,
                  child: Container(
                    width: 46 * canopyWidthFactor,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 38 + topLift,
                right: 8 - sideOffset,
                child: Transform.rotate(
                  angle: leafTilt * 0.45,
                  child: Container(
                    width: 44 * canopyWidthFactor,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topLift,
                child: Transform.rotate(
                  angle: leafTilt * 0.3,
                  child: Container(
                    width: 74 * canopyWidthFactor,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.leaf.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  _TreePalette _paletteFor(
    TreePageVisualState state,
    _CategoryTreeStyle style,
    bool isNight,
  ) {
    final nightTint = isNight ? const Color(0xFF7A8A93) : null;

    return switch (state) {
      TreePageVisualState.growing ||
      TreePageVisualState.completed ||
      TreePageVisualState.soothed => _TreePalette(
        leaf: _tint(style.leaf, nightTint, isNight ? 0.26 : 0),
        trunk: _tint(style.trunk, nightTint, isNight ? 0.12 : 0),
        soil: _tint(style.soil, nightTint, isNight ? 0.08 : 0),
        ground: _tint(style.ground, nightTint, isNight ? 0.12 : 0),
      ),
      TreePageVisualState.thirsty => _TreePalette(
        leaf: _tint(style.leaf, const Color(0xFFC4B36D), 0.38),
        trunk: _tint(style.trunk, const Color(0xFF847168), 0.16),
        soil: _tint(style.soil, const Color(0xFFB59E86), 0.22),
        ground: _tint(style.ground, const Color(0xFFF0ECD8), 0.4),
      ),
      TreePageVisualState.wilting => _TreePalette(
        leaf: _tint(style.leaf, const Color(0xFFCC9F61), 0.58),
        trunk: _tint(style.trunk, const Color(0xFF8A6A59), 0.22),
        soil: _tint(style.soil, const Color(0xFFAF8E7C), 0.28),
        ground: _tint(style.ground, const Color(0xFFF2E2CE), 0.48),
      ),
      TreePageVisualState.dead => const _TreePalette(
        leaf: Color(0xFF9D9488),
        trunk: Color(0xFF6E615A),
        soil: Color(0xFF88746A),
        ground: Color(0xFFE3DDD8),
      ),
    };
  }

  Color _tint(Color base, Color? overlay, double amount) {
    if (overlay == null || amount <= 0) return base;
    final t = amount.clamp(0.0, 1.0);
    return Color.lerp(base, overlay, t) ?? base;
  }
}

class _AmbientGardenBackdrop extends StatelessWidget {
  const _AmbientGardenBackdrop({
    required this.isNight,
    required this.visualState,
    this.category = LifeCategory.health,
  });

  final bool isNight;
  final TreePageVisualState visualState;
  final LifeCategory category;

  @override
  Widget build(BuildContext context) {
    final topColor = isNight
        ? const Color(0xFFEDF2EC)
        : const Color(0xFFFBFCF8);
    final bottomColor = switch (visualState) {
      TreePageVisualState.dead => const Color(0xFFF0ECE7),
      TreePageVisualState.wilting => const Color(0xFFF7F0E3),
      TreePageVisualState.thirsty => const Color(0xFFF3F5E6),
      _ => isNight ? const Color(0xFFEAF1E7) : const Color(0xFFEAF5E8),
    };
    final accentColor = switch (category) {
      LifeCategory.health => const Color(0x14A8D5AF),
      LifeCategory.family => const Color(0x14B8D7B1),
      LifeCategory.work => const Color(0x149FC9D6),
      LifeCategory.rest => const Color(0x149EB8D7),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: Stack(
        children: [
          _BackdropOrb(
            alignment: Alignment(-0.92, -0.72),
            size: 180,
            color: accentColor,
          ),
          const _BackdropOrb(
            alignment: Alignment(0.9, -0.4),
            size: 150,
            color: Color(0x1298C9DA),
          ),
          _BackdropOrb(
            alignment: Alignment(0.0, 0.78),
            size: 240,
            color: isNight ? const Color(0x12D8E4EF) : const Color(0x12F0DDA3),
          ),
          if (isNight) ...const [
            _MoonHalo(),
            _BackdropStar(alignment: Alignment(0.74, -0.84), size: 6, phase: 0.1),
            _BackdropStar(alignment: Alignment(0.90, -0.72), size: 4, phase: 0.45),
            _BackdropStar(alignment: Alignment(0.58, -0.68), size: 5, phase: 0.78),
          ],
        ],
      ),
    );
  }
}

class _MoonHalo extends StatefulWidget {
  const _MoonHalo();

  @override
  State<_MoonHalo> createState() => _MoonHaloState();
}

class _MoonHaloState extends State<_MoonHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _driftController,
      builder: (context, child) {
        final t = _driftController.value;
        final driftX = math.sin(t * math.pi * 2) * 1.2;
        final driftY = math.cos(t * math.pi * 2) * 1.6;
        final opacity = (0.34 + (math.sin(t * math.pi * 2) * 0.08))
            .clamp(0.24, 0.42);

        return Align(
          alignment: const Alignment(0.9, -0.9),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(driftX, driftY),
              child: child,
            ),
          ),
        );
      },
      child: const Icon(
        Icons.brightness_2_rounded,
        size: 32,
        color: Color(0xFFA9B5C1),
      ),
    );
  }
}

class _BackdropStar extends StatefulWidget {
  const _BackdropStar({
    required this.alignment,
    required this.size,
    required this.phase,
  });

  final Alignment alignment;
  final double size;

  // phase is a normalized [0..1] offset so stars twinkle out-of-sync.
  final double phase;

  @override
  State<_BackdropStar> createState() => _BackdropStarState();
}

class _BackdropStarState extends State<_BackdropStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _twinkleController,
      builder: (context, child) {
        final t = (_twinkleController.value + widget.phase) % 1.0;
        final opacity = (0.34 + (math.sin(t * math.pi * 2) * 0.14))
            .clamp(0.2, 0.52);

        return Align(
          alignment: widget.alignment,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: Color(0x55EDF6FF),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _CategoryTreeStyle {
  const _CategoryTreeStyle({
    required this.leaf,
    required this.trunk,
    required this.soil,
    required this.ground,
    required this.canopyWidthFactor,
    required this.topLift,
    required this.sideOffset,
  });

  final Color leaf;
  final Color trunk;
  final Color soil;
  final Color ground;
  final double canopyWidthFactor;
  final double topLift;
  final double sideOffset;

  factory _CategoryTreeStyle.forCategory(LifeCategory category) {
    return switch (category) {
      LifeCategory.health => const _CategoryTreeStyle(
        leaf: Color(0xFF63B66A),
        trunk: Color(0xFF6B4B3E),
        soil: Color(0xFF846258),
        ground: Color(0xFFDDE9DD),
        canopyWidthFactor: 1.0,
        topLift: 0,
        sideOffset: 0,
      ),
      LifeCategory.family => const _CategoryTreeStyle(
        leaf: Color(0xFF74B67B),
        trunk: Color(0xFF735448),
        soil: Color(0xFF8A675F),
        ground: Color(0xFFE2EBE0),
        canopyWidthFactor: 1.08,
        topLift: -2,
        sideOffset: 4,
      ),
      LifeCategory.work => const _CategoryTreeStyle(
        leaf: Color(0xFF5AA38A),
        trunk: Color(0xFF624840),
        soil: Color(0xFF7D635B),
        ground: Color(0xFFD8E7E1),
        canopyWidthFactor: 0.92,
        topLift: 2,
        sideOffset: -3,
      ),
      LifeCategory.rest => const _CategoryTreeStyle(
        leaf: Color(0xFF7B9FB8),
        trunk: Color(0xFF675E68),
        soil: Color(0xFF7A6E79),
        ground: Color(0xFFDDE3EA),
        canopyWidthFactor: 1.02,
        topLift: -4,
        sideOffset: 1,
      ),
    };
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _LeafBurst extends StatelessWidget {
  const _LeafBurst({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    const configs = <({double dx, double dy, double size, double angle})>[
      (dx: -62, dy: -12, size: 11, angle: -0.55),
      (dx: -28, dy: -72, size: 12, angle: 0.12),
      (dx: 22, dy: -80, size: 10, angle: -0.15),
      (dx: 60, dy: -24, size: 11, angle: 0.5),
    ];

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final config in configs)
              Positioned(
                bottom: 132 + config.dy - (18 * progress),
                child: Transform.translate(
                  offset: Offset(config.dx, 0),
                  child: Transform.rotate(
                    angle: config.angle,
                    child: Opacity(
                      opacity: ((1 - progress) * 0.9).clamp(0.0, 1.0),
                      child: Container(
                        width: config.size,
                        height: config.size * 1.35,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(config.size),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

class _DeadTreeShape extends StatelessWidget {
  const _DeadTreeShape({
    required this.trunkColor,
    required this.leafColor,
    required this.stemHeightFactor,
    required this.leafTilt,
  });

  final Color trunkColor;
  final Color leafColor;
  final double stemHeightFactor;
  final double leafTilt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 152,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 16,
            height: 100 * stemHeightFactor,
            decoration: BoxDecoration(
              color: trunkColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Positioned(
            bottom: 72,
            left: 28,
            child: Transform.rotate(
              angle: -0.9 + leafTilt * 0.6,
              child: Container(
                width: 30,
                height: 8,
                decoration: BoxDecoration(
                  color: trunkColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 84,
            right: 24,
            child: Transform.rotate(
              angle: 0.8 + leafTilt * 0.6,
              child: Container(
                width: 24,
                height: 7,
                decoration: BoxDecoration(
                  color: trunkColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 24,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                width: 11,
                height: 6,
                decoration: BoxDecoration(
                  color: leafColor.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 30,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 10,
                height: 5,
                decoration: BoxDecoration(
                  color: leafColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadMemoryPill extends StatelessWidget {
  const _DeadMemoryPill({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD9E4DA), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          'It stayed with you for $streakDays day${streakDays == 1 ? '' : 's'}.',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF607365),
          ),
        ),
      ),
    );
  }
}

class _TreeVariation {
  const _TreeVariation({
    required this.leafTiltRadians,
    required this.scale,
    required this.stemHeightFactor,
  });

  final double leafTiltRadians;
  final double scale;
  final double stemHeightFactor;

  factory _TreeVariation.fromSeed(String seed) {
    final hash = _stableHash(seed);
    final leafTiltDegrees = _mapHash(hash, 0, -5, 5);
    final scale = _mapHash(hash, 1, 0.9, 1.1);
    final stemHeightFactor = _mapHash(hash, 2, 0.92, 1.08);
    return _TreeVariation(
      leafTiltRadians: leafTiltDegrees * math.pi / 180,
      scale: scale,
      stemHeightFactor: stemHeightFactor,
    );
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static double _mapHash(int hash, int channel, double min, double max) {
    final mixed = ((hash >> (channel * 7)) ^ (hash * (channel + 3))) & 0xffff;
    final normalized = mixed / 0xffff;
    return min + (max - min) * normalized;
  }
}

class _CareToast extends StatelessWidget {
  const _CareToast({required this.message, required this.accentColor});

  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(accentColor, Colors.white, 0.9)?.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Color.lerp(accentColor, const Color(0xFFD9E4DD), 0.68) ??
                  const Color(0xFFD9E4DD),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF45665A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
