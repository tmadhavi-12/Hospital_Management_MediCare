import 'package:flutter/material.dart';

// ===========================================================================
// Shared look & feel
// ===========================================================================
const kBrandDark = Color(0xFF064E6B);
const kBrand = Color(0xFF0B7A9E);
const kBrandLight = Color(0xFF16A8A0);

LinearGradient brandGradient([List<Color>? colors]) => LinearGradient(
      colors: colors ?? const [kBrandDark, kBrand, kBrandLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

/// Big coloured banner used at the top of screens (hospital name, welcome text ...)
class GradientHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final List<Color>? colors;
  final double radius;
  const GradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.colors,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: brandGradient(colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: kBrand.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child)),
    );
  }
}

/// Coloured circle with an icon
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(size / 3)),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Dashboard tile: big number + label + coloured icon
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        IconBadge(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Icon + colour for each medical specialty
IconData specialtyIcon(String s) {
  final t = s.toLowerCase();
  if (t.contains('cardio')) return Icons.favorite;
  if (t.contains('derma')) return Icons.face_retouching_natural;
  if (t.contains('pedia')) return Icons.child_care;
  if (t.contains('ortho')) return Icons.accessibility_new;
  if (t.contains('neuro')) return Icons.psychology;
  if (t.contains('gyne')) return Icons.pregnant_woman;
  if (t.contains('eye') || t.contains('ophthal')) return Icons.visibility;
  if (t.contains('dent')) return Icons.mood;
  return Icons.medical_services;
}

Color specialtyColor(String s) {
  final t = s.toLowerCase();
  if (t.contains('cardio')) return const Color(0xFFE53935);
  if (t.contains('derma')) return const Color(0xFFF57C00);
  if (t.contains('pedia')) return const Color(0xFF8E24AA);
  if (t.contains('ortho')) return const Color(0xFF3949AB);
  if (t.contains('neuro')) return const Color(0xFF00897B);
  if (t.contains('gyne')) return const Color(0xFFD81B60);
  return kBrand;
}

/// Doctor avatar: coloured circle with the specialty icon
class DoctorAvatar extends StatelessWidget {
  final String specialty;
  final double radius;
  const DoctorAvatar({super.key, required this.specialty, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final c = specialtyColor(specialty);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c.withOpacity(0.85), c], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(specialtyIcon(specialty), color: Colors.white, size: radius),
    );
  }
}

/// Small rounded pill with text
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
