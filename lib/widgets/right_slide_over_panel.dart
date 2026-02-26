import 'package:flutter/material.dart';

Future<T?> showRightSlideOverPanel<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 520,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'Close panel',
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final availableWidth = MediaQuery.of(context).size.width;
      final panelWidth = (availableWidth * 0.42).clamp(380.0, maxWidth);

      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 10,
            child: SizedBox(
              width: panelWidth,
              height: double.infinity,
              child: child,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return SlideTransition(position: slide, child: child);
    },
  );
}
