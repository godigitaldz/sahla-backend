import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkingHoursWidget extends StatefulWidget {
  final Map<String, Map<String, String?>> workingHours;
  final Function(Map<String, Map<String, String?>>) onChanged;
  final String? Function(String)? validator;

  const WorkingHoursWidget({
    required this.workingHours,
    required this.onChanged,
    super.key,
    this.validator,
  });

  @override
  State<WorkingHoursWidget> createState() => _WorkingHoursWidgetState();
}

class _WorkingHoursWidgetState extends State<WorkingHoursWidget> {
  // Selected days for working hours
  final Set<String> _selectedDays = {
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  };

  // Common working hours for all selected days
  String? _commonOpenTime;
  String? _commonCloseTime;
  String? _commonBreakStart;
  String? _commonBreakEnd;
  bool _hasCommonBreak = false;

  // Different working times mode
  bool _useDifferentTimes = false;
  final Map<String, Map<String, String?>> _differentTimes = {};
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    _initializeFromWorkingHours();
  }

  @override
  void didUpdateWidget(WorkingHoursWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workingHours != widget.workingHours) {
      _initializeFromWorkingHours();
    }
  }

  void _initializeFromWorkingHours() {
    // Initialize from existing working hours data
    if (widget.workingHours.isNotEmpty) {
      // Check if we have different times for different days
      final days = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday'
      ];
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];

      // Check if all days have the same times (common mode)
      bool hasCommonTimes = true;
      String? commonOpen, commonClose, commonBreakStart, commonBreakEnd;
      bool commonHasBreak = false;

      for (int i = 0; i < days.length; i++) {
        final dayData = widget.workingHours[days[i]];
        if (dayData != null && dayData['isOpen'] == 'true') {
          if (commonOpen == null) {
            commonOpen = dayData['open'];
            commonClose = dayData['close'];
            commonBreakStart = dayData['breakStart'];
            commonBreakEnd = dayData['breakEnd'];
            commonHasBreak = dayData['hasBreak'] == 'true';
          } else {
            // Check if times are different
            if (dayData['open'] != commonOpen ||
                dayData['close'] != commonClose ||
                dayData['breakStart'] != commonBreakStart ||
                dayData['breakEnd'] != commonBreakEnd ||
                dayData['hasBreak'] != commonHasBreak.toString()) {
              hasCommonTimes = false;
              break;
            }
          }
        }
      }

      if (hasCommonTimes && commonOpen != null && commonClose != null) {
        // Common mode
        _useDifferentTimes = false;
        _commonOpenTime = commonOpen;
        _commonCloseTime = commonClose;
        _commonBreakStart = commonBreakStart;
        _commonBreakEnd = commonBreakEnd;
        _hasCommonBreak = commonHasBreak;

        // Set selected days
        _selectedDays.clear();
        for (int i = 0; i < days.length; i++) {
          final dayData = widget.workingHours[days[i]];
          if (dayData != null && dayData['isOpen'] == 'true') {
            _selectedDays.add(dayNames[i]);
          }
        }
      } else {
        // Different times mode
        _useDifferentTimes = true;
        _differentTimes.clear();

        for (int i = 0; i < days.length; i++) {
          final dayData = widget.workingHours[days[i]];
          if (dayData != null) {
            _differentTimes[dayNames[i]] = {
              'isOpen': dayData['isOpen'] ?? 'false',
              'open': dayData['open'],
              'close': dayData['close'],
              'hasBreak': dayData['hasBreak'] ?? 'false',
              'breakStart': dayData['breakStart'],
              'breakEnd': dayData['breakEnd'],
            };
          } else {
            _differentTimes[dayNames[i]] = {
              'isOpen': 'false',
              'open': null,
              'close': null,
              'hasBreak': 'false',
              'breakStart': null,
              'breakEnd': null,
            };
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Working Hours *',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Compact Working Hours Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Days Selection
              Text(
                'Working Days',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildDayChips(),
              ),

              const SizedBox(height: 16),

              // Working Hours Mode Selection
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Use different times for specific days',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Switch(
                    value: _useDifferentTimes,
                    onChanged: (value) {
                      debugPrint(
                          '🕐 Switching to different times mode: $value');
                      debugPrint(
                          '🕐 Current common times: $_commonOpenTime - $_commonCloseTime');
                      debugPrint('🕐 Current selected days: $_selectedDays');

                      setState(() {
                        _useDifferentTimes = value;
                        _conflictMessage = null;
                        if (value) {
                          debugPrint(
                              '🕐 Initializing different times from common...');
                          _initializeDifferentTimesFromCommon();
                          debugPrint(
                              '🕐 Different times initialized: $_differentTimes');
                        }
                      });
                      _notifyParent();
                    },
                    activeThumbColor: const Color(0xFFd47b00),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Working Hours Input
              if (_useDifferentTimes) ...[
                _buildDifferentTimesSection(),
              ] else ...[
                _buildCommonHoursSection(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDayChips() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final isSelected = _selectedDays.contains(day);

      return GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedDays.remove(day);
            } else {
              _selectedDays.add(day);
            }
          });
          _notifyParent();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFd47b00) : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFd47b00) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            dayAbbr[index],
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCommonHoursSection() {
    return Column(
      children: [
        // Opening and Closing Times
        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                label: 'Opening Time',
                value: _commonOpenTime,
                onTap: () => _selectCommonTime('open'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeField(
                label: 'Closing Time',
                value: _commonCloseTime,
                onTap: () => _selectCommonTime('close'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Break Time Toggle
        Row(
          children: [
            Expanded(
              child: Text(
                'Add break time',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Switch(
              value: _hasCommonBreak,
              onChanged: (value) {
                setState(() {
                  _hasCommonBreak = value;
                  if (!value) {
                    _commonBreakStart = null;
                    _commonBreakEnd = null;
                  }
                });
                _notifyParent();
              },
              activeThumbColor: const Color(0xFFd47b00),
            ),
          ],
        ),

        // Break Time Fields
        if (_hasCommonBreak) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  label: 'Break Start',
                  value: _commonBreakStart,
                  onTap: () => _selectCommonTime('breakStart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeField(
                  label: 'Break End',
                  value: _commonBreakEnd,
                  onTap: () => _selectCommonTime('breakEnd'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDifferentTimesSection() {
    return Column(
      children: [
        // Conflict message
        if (_conflictMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _conflictMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Different times for each selected day using chips style
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildDifferentTimeChips(),
        ),
      ],
    );
  }

  List<Widget> _buildDifferentTimeChips() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final dayTimes = _differentTimes[day];
      final isOpen = dayTimes?['isOpen'] == 'true';
      final hasTimes = dayTimes?['open'] != null && dayTimes?['close'] != null;

      // Determine chip color based on state
      Color chipColor;
      Color textColor;
      Color borderColor;

      if (isOpen && hasTimes) {
        chipColor = const Color(0xFFd47b00);
        textColor = Colors.white;
        borderColor = const Color(0xFFd47b00);
      } else if (isOpen) {
        chipColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        borderColor = Colors.orange[300]!;
      } else if (dayTimes != null && dayTimes['isOpen'] == 'false') {
        chipColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        borderColor = Colors.red[300]!;
      } else {
        chipColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        borderColor = Colors.grey[300]!;
      }

      return GestureDetector(
        onTap: () {
          // Always show time picker for any day
          _showDayTimePicker(day);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayAbbr[index],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (isOpen && hasTimes) ...[
                const SizedBox(width: 4),
                Text(
                  '${dayTimes!['open']}-${dayTimes['close']}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTimeField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: value != null ? Colors.black87 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCommonTime(String type) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final timeString = '$hour:$minute';

      setState(() {
        switch (type) {
          case 'open':
            _commonOpenTime = timeString;
            break;
          case 'close':
            _commonCloseTime = timeString;
            break;
          case 'breakStart':
            _commonBreakStart = timeString;
            break;
          case 'breakEnd':
            _commonBreakEnd = timeString;
            break;
        }
      });
      _notifyParent();
    }
  }

  Future<void> _selectDifferentTime(String day, String type,
      {StateSetter? setModalState}) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final timeString = '$hour:$minute';

      if (setModalState != null) {
        setModalState(() {
          _differentTimes[day]![type] = timeString;
        });
      } else {
        setState(() {
          _differentTimes[day]![type] = timeString;
          _checkForConflicts();
        });
      }
      _notifyParent();
    }
  }

  void _showDayTimePicker(String day) {
    // Initialize day if it doesn't exist
    if (!_differentTimes.containsKey(day)) {
      _differentTimes[day] = {
        'isOpen': 'false',
        'open': null,
        'close': null,
        'hasBreak': 'false',
        'breakStart': null,
        'breakEnd': null,
      };
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$day Schedule',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Open/Closed Toggle
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Open on $day',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Switch(
                            value: _differentTimes[day]!['isOpen'] == 'true',
                            onChanged: (value) {
                              setModalState(() {
                                _differentTimes[day] = {
                                  'isOpen': value.toString(),
                                  'open': value
                                      ? _differentTimes[day]!['open']
                                      : null,
                                  'close': value
                                      ? _differentTimes[day]!['close']
                                      : null,
                                  'hasBreak': value
                                      ? _differentTimes[day]!['hasBreak']
                                      : 'false',
                                  'breakStart': value
                                      ? _differentTimes[day]!['breakStart']
                                      : null,
                                  'breakEnd': value
                                      ? _differentTimes[day]!['breakEnd']
                                      : null,
                                };
                              });
                              setState(() {
                                _checkForConflicts();
                              });
                              _notifyParent();
                            },
                            activeThumbColor: const Color(0xFFd47b00),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Time fields (only show if open)
                      if (_differentTimes[day]!['isOpen'] == 'true') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                label: 'Opening Time',
                                value: _differentTimes[day]!['open'],
                                onTap: () => _selectDifferentTime(day, 'open',
                                    setModalState: setModalState),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimeField(
                                label: 'Closing Time',
                                value: _differentTimes[day]!['close'],
                                onTap: () => _selectDifferentTime(day, 'close',
                                    setModalState: setModalState),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Break Time Toggle
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Add break time',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Switch(
                              value:
                                  _differentTimes[day]!['hasBreak'] == 'true',
                              onChanged: (value) {
                                setModalState(() {
                                  _differentTimes[day]!['hasBreak'] =
                                      value.toString();
                                  if (!value) {
                                    _differentTimes[day]!['breakStart'] = null;
                                    _differentTimes[day]!['breakEnd'] = null;
                                  }
                                });
                                setState(() {
                                  _checkForConflicts();
                                });
                                _notifyParent();
                              },
                              activeThumbColor: const Color(0xFFd47b00),
                            ),
                          ],
                        ),

                        // Break Time Fields
                        if (_differentTimes[day]!['hasBreak'] == 'true') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeField(
                                  label: 'Break Start',
                                  value: _differentTimes[day]!['breakStart'],
                                  onTap: () => _selectDifferentTime(
                                      day, 'breakStart',
                                      setModalState: setModalState),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTimeField(
                                  label: 'Break End',
                                  value: _differentTimes[day]!['breakEnd'],
                                  onTap: () => _selectDifferentTime(
                                      day, 'breakEnd',
                                      setModalState: setModalState),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],

                      const Spacer(),

                      // Done button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFd47b00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeDifferentTimesFromCommon() {
    // Apply common timing to ALL days that were previously configured
    // This preserves the existing working hours configuration
    final allDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    for (final day in allDays) {
      // Check if this day was previously configured in the working hours
      final dayKey = day.toLowerCase();
      final existingDayData = widget.workingHours[dayKey];

      if (existingDayData != null && existingDayData['isOpen'] == 'true') {
        // This day was previously open, preserve its times
        _differentTimes[day] = {
          'isOpen': 'true',
          'open': _commonOpenTime ?? existingDayData['open'],
          'close': _commonCloseTime ?? existingDayData['close'],
          'hasBreak': _hasCommonBreak.toString(),
          'breakStart': _hasCommonBreak
              ? (_commonBreakStart ?? existingDayData['breakStart'])
              : null,
          'breakEnd': _hasCommonBreak
              ? (_commonBreakEnd ?? existingDayData['breakEnd'])
              : null,
        };
      } else {
        // This day was previously closed or not configured
        _differentTimes[day] = {
          'isOpen': 'false',
          'open': null,
          'close': null,
          'hasBreak': 'false',
          'breakStart': null,
          'breakEnd': null,
        };
      }
    }
  }

  void _checkForConflicts() {
    _conflictMessage = null;

    // Check for timing conflicts within each day
    for (final day in _differentTimes.keys) {
      final dayTimes = _differentTimes[day];
      if (dayTimes == null || dayTimes['isOpen'] != 'true') continue;

      final openTime = dayTimes['open'];
      final closeTime = dayTimes['close'];
      final breakStart = dayTimes['breakStart'];
      final breakEnd = dayTimes['breakEnd'];
      final hasBreak = dayTimes['hasBreak'] == 'true';

      // Check if open/close times are set
      if (openTime == null || closeTime == null) {
        _conflictMessage = 'Please set opening and closing times for $day';
        return;
      }

      // Check if open time is before close time
      if (!_isTimeBefore(openTime, closeTime)) {
        _conflictMessage = 'Opening time must be before closing time on $day';
        return;
      }

      // Check break time conflicts
      if (hasBreak) {
        if (breakStart == null || breakEnd == null) {
          _conflictMessage = 'Please set break start and end times for $day';
          return;
        }

        // Check if break is within working hours
        if (!_isTimeWithinRange(breakStart, openTime, closeTime) ||
            !_isTimeWithinRange(breakEnd, openTime, closeTime)) {
          _conflictMessage = 'Break time must be within working hours on $day';
          return;
        }

        // Check if break start is before break end
        if (!_isTimeBefore(breakStart, breakEnd)) {
          _conflictMessage =
              'Break start time must be before break end time on $day';
          return;
        }
      }
    }

    // Check for overlapping schedules between consecutive days
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    for (int i = 0; i < days.length - 1; i++) {
      final currentDay = days[i];
      final nextDay = days[i + 1];

      final currentTimes = _differentTimes[currentDay];
      final nextTimes = _differentTimes[nextDay];

      if (currentTimes != null &&
          nextTimes != null &&
          currentTimes['isOpen'] == 'true' &&
          nextTimes['isOpen'] == 'true') {
        final currentClose = currentTimes['close'];
        final nextOpen = nextTimes['open'];

        if (currentClose != null && nextOpen != null) {
          // Check if current day closes after next day opens (overnight conflict)
          if (_isTimeBefore(nextOpen, currentClose)) {
            _conflictMessage =
                'Schedule conflict: $currentDay closes after $nextDay opens';
            return;
          }
        }
      }
    }
  }

  bool _isTimeBefore(String time1, String time2) {
    final t1 = _parseTime(time1);
    final t2 = _parseTime(time2);
    if (t1 == null || t2 == null) return false;

    final minutes1 = t1.hour * 60 + t1.minute;
    final minutes2 = t2.hour * 60 + t2.minute;

    return minutes1 < minutes2;
  }

  bool _isTimeWithinRange(String time, String startTime, String endTime) {
    final t = _parseTime(time);
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);

    if (t == null || start == null || end == null) return false;

    final minutes = t.hour * 60 + t.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // Handle overnight schedules
    if (endMinutes < startMinutes) {
      return minutes >= startMinutes || minutes <= endMinutes;
    } else {
      return minutes >= startMinutes && minutes <= endMinutes;
    }
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Error parsing time
    }
    return null;
  }

  void _notifyParent() {
    final workingHours = _convertWorkingHoursToMap();
    widget.onChanged(workingHours);
  }

  Map<String, Map<String, String?>> _convertWorkingHoursToMap() {
    final Map<String, Map<String, String?>> result = {};

    if (_useDifferentTimes) {
      // Use different times for each day
      for (final day in _differentTimes.keys) {
        final dayTimes = _differentTimes[day];
        if (dayTimes != null &&
            dayTimes['isOpen'] == 'true' &&
            dayTimes['open'] != null &&
            dayTimes['close'] != null) {
          result[day.toLowerCase()] = {
            'isOpen': 'true',
            'open': dayTimes['open'],
            'close': dayTimes['close'],
            'hasBreak': dayTimes['hasBreak'] ?? 'false',
            'breakStart': dayTimes['breakStart'],
            'breakEnd': dayTimes['breakEnd'],
          };
        } else {
          result[day.toLowerCase()] = {
            'isOpen': 'false',
            'open': null,
            'close': null,
            'hasBreak': 'false',
            'breakStart': null,
            'breakEnd': null,
          };
        }
      }
    } else {
      // Use common hours for all selected days
      if (_commonOpenTime != null && _commonCloseTime != null) {
        final allDays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        for (final day in allDays) {
          if (_selectedDays.contains(day)) {
            result[day.toLowerCase()] = {
              'isOpen': 'true',
              'open': _commonOpenTime,
              'close': _commonCloseTime,
              'hasBreak': _hasCommonBreak.toString(),
              'breakStart': _hasCommonBreak ? _commonBreakStart : null,
              'breakEnd': _hasCommonBreak ? _commonBreakEnd : null,
            };
          } else {
            result[day.toLowerCase()] = {
              'isOpen': 'false',
              'open': null,
              'close': null,
              'hasBreak': 'false',
              'breakStart': null,
              'breakEnd': null,
            };
          }
        }
      }
    }

    return result;
  }
}
