import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MinimalPageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const MinimalPageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 26 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.charcoalDark : AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
