import 'package:flutter/material.dart';
import 'day_cell.dart';

/// A responsive 10×10 grid displaying all 100 days of the challenge.
class SavingsGrid extends StatelessWidget {
  final int animationTrigger;
  const SavingsGrid({super.key, required this.animationTrigger});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        childAspectRatio: 1.0,
        crossAxisSpacing: 3.0, // tighter gap for larger circles
        mainAxisSpacing: 8.5, // optimized height to fit the enlarged circles inside the sticker
      ),
      itemCount: 100,
      itemBuilder: (context, index) => DayCell(
        dayNumber: index + 1,
        animationTrigger: animationTrigger,
      ),
    );
  }
}
