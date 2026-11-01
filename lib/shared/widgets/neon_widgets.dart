import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Reusable MXFF AI visual primitives (glass panels, neon buttons, chips).

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor = const Color(0x262EE8B0),
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPanel.withOpacity(0.92),
            kPanelStrong.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: kNeonGreen.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class NeonIconButton extends StatelessWidget {
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = kNeonGreen,
    this.size = 52,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kPanelStrong,
        border: Border.all(color: color.withOpacity(0.55), width: 1.2),
        boxShadow: onPressed == null
            ? null
            : [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14)],
      ),
      child: Icon(icon, color: onPressed == null ? kTextDim : color, size: size * 0.44),
    );
    final w = tooltip != null
        ? Tooltip(message: tooltip!, child: button)
        : button;
    return GestureDetector(onTap: onPressed, child: w);
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.label});
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 8)],
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(label!,
              style: const TextStyle(fontSize: 11, color: kTextDim)),
        ],
      ],
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = kNeonGreen,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kPanelStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// MXFF chip logo (MX in a circuit-style rounded square).
class MxffLogo extends StatelessWidget {
  const MxffLogo({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kBackground,
        border: Border.all(color: kNeonGreen.withOpacity(0.7), width: 1.4),
        boxShadow: [
          BoxShadow(color: kNeonGreen.withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: Center(
        child: Text(
          'MX',
          style: TextStyle(
            color: kNeonGreen,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.4,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: kNeonGreen)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bottom navigation bar with 5 neon tabs.
class MxffNavBar extends StatelessWidget {
  const MxffNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x332EE8B0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 18),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavItem(
              icon: items[i].$1,
              label: items[i].$2,
              selected: i == index,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kNeonRed : const Color(0xFF8AA39C);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
