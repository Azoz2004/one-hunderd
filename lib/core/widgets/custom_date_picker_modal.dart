import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:one_hunderd/core/theme/app_theme.dart';

class CustomDatePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  const CustomDatePickerModal({
    super.key,
    required this.initialDate,
    required this.onConfirm,
  });

  @override
  State<CustomDatePickerModal> createState() => _CustomDatePickerModalState();
}

class _CustomDatePickerModalState extends State<CustomDatePickerModal> {
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;

  final int minYear = 1920;
  final int maxYear = DateTime.now().year;

  final List<String> monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  late FixedExtentScrollController yearController;
  late FixedExtentScrollController monthController;
  late FixedExtentScrollController dayController;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    selectedDay = widget.initialDate.day;

    yearController = FixedExtentScrollController(initialItem: selectedYear - minYear);
    monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
    dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
  }

  @override
  void dispose() {
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  int getDaysInMonth(int year, int month) {
    if (month == 2) {
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  void updateDayController() {
    int daysInCurrentMonth = getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > daysInCurrentMonth) {
      setState(() {
        selectedDay = daysInCurrentMonth;
      });
      dayController.jumpToItem(selectedDay - 1);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Text(
            'اختر تاريخ ميلادك',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SizedBox(
                height: 120, // Exactly fits 3 items of 40px each (limits view to 1 above, 1 selected, 1 below)
                child: Directionality(
                  textDirection: TextDirection.ltr, // strictly LTR: Year(Left), Month(Center), Day(Right)
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Continuous selection overlay with borders
                      Container(
                        height: 40,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.borderLight.withValues(alpha: 0.3),
                          border: const Border(
                            top: BorderSide(color: AppColors.border, width: 1.5),
                            bottom: BorderSide(color: AppColors.border, width: 1.5),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Year (Left)
                          Expanded(
                            flex: 1,
                            child: CupertinoPicker.builder(
                              scrollController: yearController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(),
                              onSelectedItemChanged: (index) {
                                selectedYear = minYear + index;
                                updateDayController();
                              },
                              childCount: maxYear - minYear + 1,
                              itemBuilder: (context, index) {
                                final isSelected = (minYear + index) == selectedYear;
                                return Center(
                                  child: Text(
                                    '${minYear + index}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Month (Center)
                          Expanded(
                            flex: 2,
                            child: CupertinoPicker.builder(
                              scrollController: monthController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(),
                              onSelectedItemChanged: (index) {
                                selectedMonth = index + 1;
                                updateDayController();
                              },
                              childCount: 12,
                              itemBuilder: (context, index) {
                                final isSelected = (index + 1) == selectedMonth;
                                return Center(
                                  child: Text(
                                    '${monthNames[index]} (${index + 1})',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 18 : 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Day (Right)
                          Expanded(
                            flex: 1,
                            child: CupertinoPicker.builder(
                              scrollController: dayController,
                              itemExtent: 40,
                              diameterRatio: 1.5,
                              squeeze: 1.1,
                              selectionOverlay: const SizedBox(),
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedDay = index + 1;
                                });
                              },
                              childCount: getDaysInMonth(selectedYear, selectedMonth),
                              itemBuilder: (context, index) {
                                final isSelected = (index + 1) == selectedDay;
                                return Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.tajawal(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.charcoal : AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(DateTime(selectedYear, selectedMonth, selectedDay));
              },
              child: const Text('تأكيد الاختيار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
