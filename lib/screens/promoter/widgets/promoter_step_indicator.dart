import 'package:flutter/material.dart';

class PromoterStepIndicator extends StatelessWidget {
  final int currentStep; // 1 to 4
  final int totalSteps;

  const PromoterStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNumber = index + 1;
        final isActive = stepNumber <= currentStep;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFC2185B)
                  : const Color(0xFFE4E7EC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
