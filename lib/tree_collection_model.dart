import 'life_category.dart';
import 'tree_model.dart';

/// Stores multiple trees and the currently selected index.
/// Uses local JSON persistence via SharedPreferences.
class TreeCollectionModel {
  final List<TreeModel> trees;
  final int currentIndex;

  const TreeCollectionModel({required this.trees, required this.currentIndex});

  factory TreeCollectionModel.initial() {
    return TreeCollectionModel(
      trees: [TreeModel.initial(category: LifeCategory.health)],
      currentIndex: 0,
    );
  }

  TreeModel get currentTree => trees[currentIndex];

  TreeCollectionModel copyWith({List<TreeModel>? trees, int? currentIndex}) {
    return TreeCollectionModel(
      trees: trees ?? this.trees,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trees': trees.map((e) => e.toJson()).toList(),
      'currentIndex': currentIndex,
    };
  }

  factory TreeCollectionModel.fromJson(Map<String, dynamic> json) {
    final rawTrees = (json['trees'] as List<dynamic>? ?? []);
    final trees = rawTrees
        .map((e) => TreeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return TreeCollectionModel(
      trees: trees.isEmpty
          ? [TreeModel.initial(category: LifeCategory.health)]
          : trees,
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
