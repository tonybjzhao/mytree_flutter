import 'package:flutter/material.dart';

import 'life_category.dart';

class CreateTreeSheet extends StatefulWidget {
  const CreateTreeSheet({
    super.key,
    required this.usedCategories,
    required this.onCreate,
  });

  final Set<LifeCategory> usedCategories;
  final ValueChanged<LifeCategory> onCreate;

  @override
  State<CreateTreeSheet> createState() => _CreateTreeSheetState();
}

class _CreateTreeSheetState extends State<CreateTreeSheet> {
  LifeCategory? _selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DDD7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Grow a new life',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E5A4F),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose what this tree will hold.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Color(0xFF6A7A72)),
            ),
            const SizedBox(height: 22),
            for (final category in LifeCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryTile(
                  category: category,
                  isUsed: widget.usedCategories.contains(category),
                  isSelected: _selected == category,
                  onTap: widget.usedCategories.contains(category)
                      ? null
                      : () {
                          setState(() => _selected = category);
                        },
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () {
                        widget.onCreate(_selected!);
                        Navigator.of(context).pop();
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF6C9A87),
                  disabledBackgroundColor: const Color(0xFFD2DDD7),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF819089),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Create tree',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isUsed,
    required this.isSelected,
    required this.onTap,
  });

  final LifeCategory category;
  final bool isUsed;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isUsed
        ? const Color(0xFFE1E6E2)
        : isSelected
        ? const Color(0xFF6C9A87)
        : const Color(0xFFDCE5DF);

    final bgColor = isUsed
        ? const Color(0xFFF3F5F3)
        : isSelected
        ? const Color(0xFFEAF3EE)
        : Colors.white;

    final titleColor = isUsed
        ? const Color(0xFFA7B1AB)
        : const Color(0xFF2F5A4F);

    final subtitleColor = isUsed
        ? const Color(0xFFB3BBB6)
        : const Color(0xFF74827B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUsed
                    ? const Color(0xFFECEFED)
                    : const Color(0xFFF3F8F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(category.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (isUsed) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Used',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFA1AAA4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.subtitle,
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isUsed)
              const Icon(Icons.lock_rounded, color: Color(0xFFA9B2AC))
            else if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF6C9A87))
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB7C0BA)),
          ],
        ),
      ),
    );
  }
}
