import 'package:flutter/material.dart';

enum TreeSlotType { seed, sprout, twinLeaf, youngTree, matureTree, add }

enum TreeSlotTone { healthy, thirsty, wilting, resting }

class TreeSlotData {
  const TreeSlotData({
    required this.type,
    required this.onTap,
    this.selected = false,
    this.locked = false,
    this.tone = TreeSlotTone.healthy,
    this.semanticLabel,
  });

  final TreeSlotType type;
  final VoidCallback onTap;
  final bool selected;
  final bool locked;
  final TreeSlotTone tone;
  final String? semanticLabel;
}

class TreeSlotsRow extends StatelessWidget {
  const TreeSlotsRow({super.key, required this.slots});

  final List<TreeSlotData> slots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final slot = slots[index];
          return Semantics(
            button: true,
            label: slot.semanticLabel,
            child: TreeSlotIconButton(slot: slot),
          );
        },
      ),
    );
  }
}

class TreeSlotIconButton extends StatelessWidget {
  const TreeSlotIconButton({super.key, required this.slot});

  final TreeSlotData slot;

  @override
  Widget build(BuildContext context) {
    final size = slot.selected ? 56.0 : 48.0;
    final colors = _colorsFor(slot.tone);
    final backgroundColor = slot.locked
        ? const Color(0xFFF1F3EF)
        : slot.selected
        ? const Color(0xFFDDEADF)
        : const Color(0xFFF0F4F1);

    return GestureDetector(
      onTap: slot.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size / 2),
          border: slot.locked
              ? Border.all(color: const Color(0xFFDCE3DC))
              : null,
          boxShadow: slot.selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5C8D7C).withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: slot.locked
              ? const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFF8E9B94),
                  size: 18,
                )
              : CustomPaint(
                  size: Size.square(slot.selected ? 28 : 24),
                  painter: _TreeSlotPainter(
                    type: slot.type,
                    colors: colors,
                    subdued: !slot.selected,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TreeSlotPainter extends CustomPainter {
  const _TreeSlotPainter({
    required this.type,
    required this.colors,
    required this.subdued,
  });

  final TreeSlotType type;
  final _TreeSlotColors colors;
  final bool subdued;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final leafPaint = Paint()
      ..color = subdued ? colors.leaf.withValues(alpha: 0.9) : colors.leaf;
    final leafAccentPaint = Paint()
      ..color = subdued
          ? colors.leafAccent.withValues(alpha: 0.82)
          : colors.leafAccent;
    final trunkPaint = Paint()
      ..color = subdued ? colors.trunk.withValues(alpha: 0.88) : colors.trunk;
    final branchPaint = Paint()
      ..color = trunkPaint.color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085;
    final plusPaint = Paint()
      ..color = colors.trunk
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;

    switch (type) {
      case TreeSlotType.seed:
        _drawStem(
          canvas,
          size,
          trunkPaint,
          heightFactor: 0.26,
          widthFactor: 0.12,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.55, size.height * 0.4),
          size: Size(size.width * 0.32, size.height * 0.18),
          rotation: -0.48,
          paint: leafPaint,
        );
        break;
      case TreeSlotType.sprout:
        _drawStem(
          canvas,
          size,
          trunkPaint,
          heightFactor: 0.32,
          widthFactor: 0.14,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.4, size.height * 0.41),
          size: Size(size.width * 0.3, size.height * 0.18),
          rotation: -0.78,
          paint: leafPaint,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.61, size.height * 0.39),
          size: Size(size.width * 0.32, size.height * 0.19),
          rotation: 0.56,
          paint: leafAccentPaint,
        );
        break;
      case TreeSlotType.twinLeaf:
        _drawStem(
          canvas,
          size,
          trunkPaint,
          heightFactor: 0.4,
          widthFactor: 0.14,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.39, size.height * 0.38),
          size: Size(size.width * 0.34, size.height * 0.2),
          rotation: -0.72,
          paint: leafPaint,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.61, size.height * 0.37),
          size: Size(size.width * 0.34, size.height * 0.2),
          rotation: 0.72,
          paint: leafAccentPaint,
        );
        _drawLeaf(
          canvas,
          center: Offset(size.width * 0.5, size.height * 0.28),
          size: Size(size.width * 0.28, size.height * 0.16),
          rotation: 0,
          paint: leafAccentPaint,
        );
        break;
      case TreeSlotType.youngTree:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.78),
          Offset(size.width * 0.5, size.height * 0.42),
          branchPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.57),
          Offset(size.width * 0.37, size.height * 0.49),
          branchPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.55),
          Offset(size.width * 0.63, size.height * 0.48),
          branchPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.34),
          size.width * 0.16,
          leafPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.37, size.height * 0.44),
          size.width * 0.12,
          leafAccentPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.63, size.height * 0.44),
          size.width * 0.12,
          leafAccentPaint,
        );
        break;
      case TreeSlotType.matureTree:
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.8),
          Offset(size.width * 0.5, size.height * 0.38),
          branchPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.56),
          Offset(size.width * 0.34, size.height * 0.44),
          branchPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.5, size.height * 0.52),
          Offset(size.width * 0.66, size.height * 0.41),
          branchPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.35),
          size.width * 0.22,
          leafPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.31, size.height * 0.45),
          size.width * 0.18,
          leafAccentPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.69, size.height * 0.45),
          size.width * 0.18,
          leafAccentPaint,
        );
        break;
      case TreeSlotType.add:
        canvas.drawLine(
          Offset(center.dx, size.height * 0.28),
          Offset(center.dx, size.height * 0.72),
          plusPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.28, center.dy),
          Offset(size.width * 0.72, center.dy),
          plusPaint,
        );
        break;
    }
  }

  void _drawStem(
    Canvas canvas,
    Size size,
    Paint paint, {
    required double heightFactor,
    required double widthFactor,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.67),
        width: size.width * widthFactor,
        height: size.height * heightFactor,
      ),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(rect, paint);
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset center,
    required Size size,
    required double rotation,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final path = Path()
      ..moveTo(0, -rect.height / 2)
      ..quadraticBezierTo(rect.width / 2, -rect.height / 4, rect.width / 2, 0)
      ..quadraticBezierTo(rect.width / 2, rect.height / 3, 0, rect.height / 2)
      ..quadraticBezierTo(-rect.width / 2, rect.height / 3, -rect.width / 2, 0)
      ..quadraticBezierTo(
        -rect.width / 2,
        -rect.height / 4,
        0,
        -rect.height / 2,
      )
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreeSlotPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.colors != colors ||
        oldDelegate.subdued != subdued;
  }
}

class _TreeSlotColors {
  const _TreeSlotColors({
    required this.leaf,
    required this.leafAccent,
    required this.trunk,
  });

  final Color leaf;
  final Color leafAccent;
  final Color trunk;

  @override
  bool operator ==(Object other) {
    return other is _TreeSlotColors &&
        other.leaf == leaf &&
        other.leafAccent == leafAccent &&
        other.trunk == trunk;
  }

  @override
  int get hashCode => Object.hash(leaf, leafAccent, trunk);
}

_TreeSlotColors _colorsFor(TreeSlotTone tone) {
  return switch (tone) {
    TreeSlotTone.healthy => const _TreeSlotColors(
      leaf: Color(0xFF7FB286),
      leafAccent: Color(0xFFA8C899),
      trunk: Color(0xFF6D806B),
    ),
    TreeSlotTone.thirsty => const _TreeSlotColors(
      leaf: Color(0xFFA7B46B),
      leafAccent: Color(0xFFBEC98B),
      trunk: Color(0xFF758068),
    ),
    TreeSlotTone.wilting => const _TreeSlotColors(
      leaf: Color(0xFFC6A76B),
      leafAccent: Color(0xFFD3BA87),
      trunk: Color(0xFF84705F),
    ),
    TreeSlotTone.resting => const _TreeSlotColors(
      leaf: Color(0xFFA3A89A),
      leafAccent: Color(0xFFBBC0B3),
      trunk: Color(0xFF7E776E),
    ),
  };
}
