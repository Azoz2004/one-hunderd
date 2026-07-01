import 'package:flutter/material.dart';
import 'day_cell.dart';

/// A responsive 10×10 grid displaying all 100 days of the challenge.
class SavingsGrid extends StatelessWidget {
  const SavingsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        childAspectRatio: 1,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: 100,
      itemBuilder: (context, index) => DayCell(dayNumber: index + 1),
    );
  }
}
