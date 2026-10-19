import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class CheckoutStepper extends StatelessWidget {
  /// Current step: 1 (Ringkasan), 2 (Bayar), 3 (E-Tiket)
  final int currentStep;

  const CheckoutStepper({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep(1, 'Ringkasan'),
          _buildLine(isPassed: currentStep > 1),
          _buildStep(2, 'Bayar'),
          _buildLine(isPassed: currentStep > 2),
          _buildStep(3, 'E-Tiket'),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String label) {
    final isCurrent = currentStep == step;
    final isDone = currentStep > step;

    Color circleColor;
    Color textColor;
    Widget innerContent;

    if (isDone) {
      circleColor = AppColors.primary;
      textColor = AppColors.primary;
      innerContent = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      circleColor = AppColors.primary;
      textColor = AppColors.primary;
      innerContent = Text(
        '$step',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      circleColor = const Color(0xFFE4E7EC);
      textColor = AppColors.textGrey;
      innerContent = Text(
        '$step',
        style: const TextStyle(
          color: AppColors.textGrey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: innerContent,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent || isDone ? FontWeight.w600 : FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLine({required bool isPassed}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
        color: isPassed ? AppColors.primary : const Color(0xFFE4E7EC),
      ),
    );
  }
}
