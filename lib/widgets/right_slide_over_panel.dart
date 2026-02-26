import 'package:flutter/material.dart';

import 'package:stock_manager/theme/app_theme.dart';

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
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) {
      final availableWidth = MediaQuery.of(context).size.width;
      final panelWidth = (availableWidth * 0.42).clamp(380.0, maxWidth);

      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: panelWidth,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                left: BorderSide(color: AppColors.border, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
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
