import 'package:flutter/material.dart';

/// A wrapper that applies responsive hover effects for desktop.
class HoverableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final Color? defaultColor;
  final Color? hoverColor;
  final double elevation;
  final double hoverElevation;
  final BorderRadius? borderRadius;

  const HoverableCard({
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.defaultColor,
    this.hoverColor,
    this.elevation = 0.0,
    this.hoverElevation = 2.0,
    this.borderRadius,
    super.key,
  });

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBorderRadius = widget.borderRadius ?? BorderRadius.circular(14);
    
    return Container(
      margin: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _isHovered 
                ? (widget.hoverColor ?? theme.colorScheme.primary.withValues(alpha: 0.05))
                : (widget.defaultColor ?? theme.cardTheme.color ?? theme.colorScheme.surface),
            borderRadius: currentBorderRadius,
            border: Border.all(
              color: _isHovered ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: currentBorderRadius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: currentBorderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
