import 'package:cloud_firestore/cloud_firestore.dart';

enum MessMealType { breakfast, lunch, snacks, dinner }

extension MessMealTypeExtension on MessMealType {
  String get displayName {
    switch (this) {
      case MessMealType.breakfast:
        return 'Breakfast';
      case MessMealType.lunch:
        return 'Lunch';
      case MessMealType.snacks:
        return 'Snacks';
      case MessMealType.dinner:
        return 'Dinner';
    }
  }

  String get timeRangeText {
    switch (this) {
      case MessMealType.breakfast:
        return '8:00 AM – 9:00 AM';
      case MessMealType.lunch:
        return '12:00 PM – 2:30 PM';
      case MessMealType.snacks:
        return '5:00 PM – 6:00 PM';
      case MessMealType.dinner:
        return '8:00 PM – 10:00 PM';
    }
  }

  int get startHour {
    switch (this) {
      case MessMealType.breakfast:
        return 8;
      case MessMealType.lunch:
        return 12;
      case MessMealType.snacks:
        return 17;
      case MessMealType.dinner:
        return 20;
    }
  }

  int get startMinute => 0;

  int get endHour {
    switch (this) {
      case MessMealType.breakfast:
        return 9;
      case MessMealType.lunch:
        return 14;
      case MessMealType.snacks:
        return 18;
      case MessMealType.dinner:
        return 22;
    }
  }

  int get endMinute {
    switch (this) {
      case MessMealType.lunch:
        return 30;
      default:
        return 0;
    }
  }
}

class MessTimings {
  /// Determines the active meal type if current time falls within meal hours.
  static MessMealType? getCurrentMeal(DateTime now) {
    for (final meal in MessMealType.values) {
      final start = DateTime(now.year, now.month, now.day, meal.startHour, meal.startMinute);
      final end = DateTime(now.year, now.month, now.day, meal.endHour, meal.endMinute);
      if (now.isAfter(start) && now.isBefore(end)) {
        return meal;
      }
    }
    return null;
  }

  /// Determines if QR code generation is allowed:
  /// Starts 20 minutes before meal start and continues until 30 minutes after meal end.
  static bool isQrWindowActive(DateTime now) {
    for (final meal in MessMealType.values) {
      final start = DateTime(now.year, now.month, now.day, meal.startHour, meal.startMinute)
          .subtract(const Duration(minutes: 20));
      final end = DateTime(now.year, now.month, now.day, meal.endHour, meal.endMinute)
          .add(const Duration(minutes: 30));
      if ((now.isAfter(start) || now.isAtSameMomentAs(start)) &&
          (now.isBefore(end) || now.isAtSameMomentAs(end))) {
        return true;
      }
    }
    return false;
  }

  /// Calculates the next upcoming meal and its exact start time.
  static Map<String, dynamic> getNextMeal(DateTime now) {
    for (final meal in MessMealType.values) {
      final start = DateTime(now.year, now.month, now.day, meal.startHour, meal.startMinute);
      if (now.isBefore(start)) {
        return {'meal': meal, 'startTime': start};
      }
    }
    // If past all meals today, next meal is Breakfast tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    final nextStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, MessMealType.breakfast.startHour, MessMealType.breakfast.startMinute);
    return {'meal': MessMealType.breakfast, 'startTime': nextStart};
  }

  /// Calculates time remaining until current active meal ends.
  static Duration? getTimeRemainingInActiveMeal(DateTime now) {
    final active = getCurrentMeal(now);
    if (active == null) return null;
    final end = DateTime(now.year, now.month, now.day, active.endHour, active.endMinute);
    return end.difference(now);
  }

  /// Feedback is open from meal start date/time until the same meal ends on the NEXT calendar day (25-hour window).
  static bool isFeedbackWindowOpen(MessMealType mealType, DateTime mealDate, DateTime now) {
    final windowStart = DateTime(mealDate.year, mealDate.month, mealDate.day, mealType.startHour, mealType.startMinute);
    final windowEnd = DateTime(mealDate.year, mealDate.month, mealDate.day + 1, mealType.endHour, mealType.endMinute);
    return (now.isAfter(windowStart) || now.isAtSameMomentAs(windowStart)) && now.isBefore(windowEnd);
  }
}

class MessMenuItem {
  final String id;
  final String date; // YYYY-MM-DD
  final MessMealType mealType;
  final List<String> items;
  final String? updatedBy;
  final DateTime? updatedAt;

  MessMenuItem({
    required this.id,
    required this.date,
    required this.mealType,
    required this.items,
    this.updatedBy,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'mealType': mealType.name,
      'items': items,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory MessMenuItem.fromMap(Map<String, dynamic> map, String docId) {
    final mealTypeStr = map['mealType']?.toString() ?? 'breakfast';
    final resolvedMeal = MessMealType.values.firstWhere(
      (e) => e.name == mealTypeStr,
      orElse: () => MessMealType.breakfast,
    );

    return MessMenuItem(
      id: docId,
      date: map['date']?.toString() ?? '',
      mealType: resolvedMeal,
      items: (map['items'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      updatedBy: map['updatedBy']?.toString(),
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}

class MessAttendance {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String hostel;
  final String? roomNo;
  final String? photoUrl;
  final MessMealType mealType;
  final String date; // YYYY-MM-DD
  final DateTime timestamp;
  final String scannerId;
  final String status; // PASS

  MessAttendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.hostel,
    this.roomNo,
    this.photoUrl,
    required this.mealType,
    required this.date,
    required this.timestamp,
    required this.scannerId,
    this.status = 'PASS',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'rollNo': rollNo,
      'hostel': hostel,
      'roomNo': roomNo,
      'photoUrl': photoUrl,
      'mealType': mealType.name,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
      'scannerId': scannerId,
      'status': status,
    };
  }

  factory MessAttendance.fromMap(Map<String, dynamic> map, String docId) {
    return MessAttendance(
      id: docId,
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      rollNo: map['rollNo']?.toString() ?? '',
      hostel: map['hostel']?.toString() ?? '',
      roomNo: map['roomNo']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      mealType: MessMealType.values.firstWhere(
        (e) => e.name == map['mealType']?.toString(),
        orElse: () => MessMealType.breakfast,
      ),
      date: map['date']?.toString() ?? '',
      timestamp: map['timestamp'] is Timestamp ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
      scannerId: map['scannerId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'PASS',
    );
  }
}

class MessScanLog {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String hostel;
  final MessMealType mealType;
  final String date; // YYYY-MM-DD
  final DateTime timestamp;
  final String scannerId;
  final String status; // PASS or FAIL
  final String? failureReason;

  MessScanLog({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.hostel,
    required this.mealType,
    required this.date,
    required this.timestamp,
    required this.scannerId,
    required this.status,
    this.failureReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'rollNo': rollNo,
      'hostel': hostel,
      'mealType': mealType.name,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
      'scannerId': scannerId,
      'status': status,
      'failureReason': failureReason,
    };
  }

  factory MessScanLog.fromMap(Map<String, dynamic> map, String docId) {
    return MessScanLog(
      id: docId,
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      rollNo: map['rollNo']?.toString() ?? '',
      hostel: map['hostel']?.toString() ?? '',
      mealType: MessMealType.values.firstWhere(
        (e) => e.name == map['mealType']?.toString(),
        orElse: () => MessMealType.breakfast,
      ),
      date: map['date']?.toString() ?? '',
      timestamp: map['timestamp'] is Timestamp ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
      scannerId: map['scannerId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'PASS',
      failureReason: map['failureReason']?.toString(),
    );
  }
}

class MessWeeklyPdf {
  final String id;
  final String title;
  final String pdfUrl;
  final String storagePath;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int version;

  MessWeeklyPdf({
    required this.id,
    required this.title,
    required this.pdfUrl,
    required this.storagePath,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.version,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pdfUrl': pdfUrl,
      'storagePath': storagePath,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'version': version,
    };
  }

  factory MessWeeklyPdf.fromMap(Map<String, dynamic> map, String docId) {
    return MessWeeklyPdf(
      id: docId,
      title: map['title']?.toString() ?? 'Weekly Mess Menu',
      pdfUrl: map['pdfUrl']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      uploadedBy: map['uploadedBy']?.toString() ?? '',
      uploadedAt: map['uploadedAt'] is Timestamp ? (map['uploadedAt'] as Timestamp).toDate() : DateTime.now(),
      version: map['version'] is int ? map['version'] as int : 1,
    );
  }
}

class MessFeedback {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String hostel;
  final String date; // YYYY-MM-DD
  final MessMealType mealType;
  final Map<String, double> itemRatings; // Dish -> Rating (1.0 to 5.0)
  final String? comment;
  final DateTime timestamp;

  MessFeedback({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.hostel,
    required this.date,
    required this.mealType,
    required this.itemRatings,
    this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'rollNo': rollNo,
      'hostel': hostel,
      'date': date,
      'mealType': mealType.name,
      'itemRatings': itemRatings,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory MessFeedback.fromMap(Map<String, dynamic> map, String docId) {
    final rawRatings = map['itemRatings'] as Map<String, dynamic>? ?? {};
    final Map<String, double> parsedRatings = {};
    rawRatings.forEach((key, val) {
      if (val is num) {
        parsedRatings[key] = val.toDouble();
      }
    });

    return MessFeedback(
      id: docId,
      studentId: map['studentId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      rollNo: map['rollNo']?.toString() ?? '',
      hostel: map['hostel']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      mealType: MessMealType.values.firstWhere(
        (e) => e.name == map['mealType']?.toString(),
        orElse: () => MessMealType.breakfast,
      ),
      itemRatings: parsedRatings,
      comment: map['comment']?.toString(),
      timestamp: map['timestamp'] is Timestamp ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}
