import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Shows a beautiful, app-themed date picker as a modal bottom sheet.
/// Returns the picked DateTime, or null if dismissed.
Future<DateTime?> showBubimoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  Set<DateTime>? highlightedDates, // e.g. days that already have entries
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now(),
      highlightedDates: highlightedDates ?? const {},
    ),
  );
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.highlightedDates,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> highlightedDates;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
  }

  bool _hasEntry(DateTime day) {
    return widget.highlightedDates.any((d) =>
        d.year == day.year && d.month == day.month && d.day == day.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
       
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select date',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDay = DateTime.now();
                        _focusedDay = DateTime.now();
                      });
                    },
                    child: const Text('Today'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: theme.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: colorScheme.onSurfaceVariant,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                weekendStyle: theme.textTheme.labelSmall!.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: const EdgeInsets.all(4),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                ),
                todayTextStyle: TextStyle(color: colorScheme.primary),
                selectedDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
                selectedTextStyle: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: theme.textTheme.bodyMedium!,
                weekendTextStyle: theme.textTheme.bodyMedium!,
                markerDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary,
                ),
                markersAlignment: Alignment.bottomCenter,
                markerSize: 4,
                markerMargin: const EdgeInsets.only(top: 2),
              ),
              // Show a small dot under days that already have an entry
              eventLoader: (day) => _hasEntry(day) ? [true] : [],
              enabledDayPredicate: (day) =>
                  !day.isAfter(widget.lastDate) &&
                  !day.isBefore(widget.firstDate),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedDay),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}