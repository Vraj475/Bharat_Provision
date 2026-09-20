import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary action button with minimum 48dp height
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
    this.minHeight = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.alert : null,
            foregroundColor: isDestructive ? Colors.white : null,
          ),
          child: icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                )
              : Text(label, overflow: TextOverflow.ellipsis),
        );

        if (constraints.hasBoundedWidth) {
          return SizedBox(
            width: double.infinity,
            height: minHeight,
            child: button,
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: button,
        );
      },
    );
  }
}
