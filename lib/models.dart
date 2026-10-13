import 'package:flutter/material.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtDate(DateTime d) => '${weekdayShort[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtHour(int h) => fmtTime(DateTime(2000, 1, 1, h));

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class Doctor {
  String id;
  String hospitalId;
  String name;
  String specialty;
  int experience;
  int fee;
  double rating;
  int ratingCount;
  List<int> days; // 1 = Monday ... 7 = Sunday
  int startHour;
  int endHour;
  bool onLeave;
  bool favorite;

  Doctor({
    required this.id,
    this.hospitalId = '',
    required this.name,
    required this.specialty,
    required this.experience,
    required this.fee,
    this.rating = 4.5,
    this.ratingCount = 10,
    required this.days,
    this.startHour = 9,
    this.endHour = 17,
    this.onLeave = false,
    this.favorite = false,
  });

  String get initials {
    final parts = name.replaceAll('Dr.', '').trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospitalId': hospitalId,
        'name': name,
        'specialty': specialty,
        'experience': experience,
        'fee': fee,
        'rating': rating,
        'ratingCount': ratingCount,
        'days': days,
        'startHour': startHour,
        'endHour': endHour,
        'onLeave': onLeave,
        'favorite': favorite,
      };

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'],
        hospitalId: j['hospitalId'] ?? '',
        name: j['name'],
        specialty: j['specialty'],
        experience: j['experience'],
        fee: j['fee'],
        rating: (j['rating'] as num).toDouble(),
        ratingCount: j['ratingCount'] ?? 10,
        days: List<int>.from(j['days']),
        startHour: j['startHour'],
        endHour: j['endHour'],
        onLeave: j['onLeave'],
        favorite: j['favorite'],
      );
}

// 'cancelled' = cancelled by the patient, 'declined' = declined by the hospital
enum ApptStatus { pending, confirmed, completed, cancelled, declined }

extension ApptStatusX on ApptStatus {
  String get label => name[0].toUpperCase() + name.substring(1);
  Color get color {
    switch (this) {
      case ApptStatus.pending:
        return Colors.orange;
      case ApptStatus.confirmed:
        return Colors.blue;
      case ApptStatus.completed:
        return Colors.green;
      case ApptStatus.cancelled:
        return Colors.red;
      case ApptStatus.declined:
        return Colors.deepOrange;
    }
  }

  /// Cancelled or declined: the slot is free again and no actions are possible.
  bool get isDead => this == ApptStatus.cancelled || this == ApptStatus.declined;
}

class Appointment {
  String id;
  String hospitalId;
  String userId;
  String doctorId;
  String doctorName;
  String specialty;
  String patientName;
  String phone;
  String reason;
  DateTime dateTime;
  ApptStatus status;

  // Filled by the doctor/admin when the visit is completed
  String diagnosis;
  String prescription;
  String advice;

  // Reason given by the hospital when it declines a booking
  String declineReason;

  // Filled by the patient after the visit
  int? rating;
  String review;

  Appointment({
    required this.id,
    this.hospitalId = '',
    this.userId = '',
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.patientName,
    required this.phone,
    required this.reason,
    required this.dateTime,
    this.status = ApptStatus.pending,
    this.diagnosis = '',
    this.prescription = '',
    this.advice = '',
    this.declineReason = '',
    this.rating,
    this.review = '',
  });

  /// Short check-in code (last 6 digits of the id)
  String get code => id.substring(id.length - 6);

  /// Text stored inside the QR code
  String get qrData =>
      'HMS|$code|$patientName|$doctorName|${fmtDate(dateTime)} ${fmtTime(dateTime)}';

  bool get hasPrescription =>
      diagnosis.isNotEmpty || prescription.isNotEmpty || advice.isNotEmpty;

  bool get isUpcoming =>
      dateTime.isAfter(DateTime.now()) &&
      (status == ApptStatus.pending || status == ApptStatus.confirmed);

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospitalId': hospitalId,
        'userId': userId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialty': specialty,
        'patientName': patientName,
        'phone': phone,
        'reason': reason,
        'dateTime': dateTime.toIso8601String(),
        'status': status.index,
        'diagnosis': diagnosis,
        'prescription': prescription,
        'advice': advice,
        'declineReason': declineReason,
        'rating': rating,
        'review': review,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'],
        hospitalId: j['hospitalId'] ?? '',
        userId: j['userId'] ?? '',
        doctorId: j['doctorId'],
        doctorName: j['doctorName'],
        specialty: j['specialty'],
        patientName: j['patientName'],
        phone: j['phone'],
        reason: j['reason'],
        dateTime: DateTime.parse(j['dateTime']),
        status: ApptStatus.values[j['status']],
        diagnosis: j['diagnosis'] ?? '',
        prescription: j['prescription'] ?? '',
        advice: j['advice'] ?? '',
        declineReason: j['declineReason'] ?? '',
        rating: j['rating'],
        review: j['review'] ?? '',
      );
}

class Slot {
  final DateTime time;
  final bool available;
  Slot(this.time, this.available);
}

// ===========================================================================
// Emergency: blood bank + ambulance
// ===========================================================================
const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Donor groups a patient of the given group can safely receive from
const Map<String, List<String>> compatibleDonors = {
  'A+': ['A+', 'A-', 'O+', 'O-'],
  'A-': ['A-', 'O-'],
  'B+': ['B+', 'B-', 'O+', 'O-'],
  'B-': ['B-', 'O-'],
  'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'AB-': ['A-', 'B-', 'AB-', 'O-'],
  'O+': ['O+', 'O-'],
  'O-': ['O-'],
};

class Ambulance {
  String id;
  String hospitalId;
  String vehicleNo;
  String driverName;
  String driverPhone;
  String type; // Basic / ICU / Oxygen
  bool available;

  Ambulance({
    required this.id,
    this.hospitalId = '',
    required this.vehicleNo,
    required this.driverName,
    required this.driverPhone,
    this.type = 'Basic',
    this.available = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospitalId': hospitalId,
        'vehicleNo': vehicleNo,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'type': type,
        'available': available,
      };

  factory Ambulance.fromJson(Map<String, dynamic> j) => Ambulance(
        id: j['id'],
        hospitalId: j['hospitalId'] ?? '',
        vehicleNo: j['vehicleNo'],
        driverName: j['driverName'],
        driverPhone: j['driverPhone'],
        type: j['type'] ?? 'Basic',
        available: j['available'] ?? true,
      );
}

enum AmbStatus { requested, dispatched, completed, cancelled }

extension AmbStatusX on AmbStatus {
  String get label => name[0].toUpperCase() + name.substring(1);
  Color get color {
    switch (this) {
      case AmbStatus.requested:
        return Colors.orange;
      case AmbStatus.dispatched:
        return Colors.blue;
      case AmbStatus.completed:
        return Colors.green;
      case AmbStatus.cancelled:
        return Colors.red;
    }
  }
}

class AmbulanceRequest {
  String id;
  String hospitalId;
  String userId;
  String patientName;
  String phone;
  String address;
  String emergency;
  String ambulanceType;
  DateTime time;
  AmbStatus status;
  String? ambulanceId;

  AmbulanceRequest({
    required this.id,
    this.hospitalId = '',
    this.userId = '',
    required this.patientName,
    required this.phone,
    required this.address,
    required this.emergency,
    required this.ambulanceType,
    required this.time,
    this.status = AmbStatus.requested,
    this.ambulanceId,
  });

  String get code => id.substring(id.length - 6);

  bool get isActive => status == AmbStatus.requested || status == AmbStatus.dispatched;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospitalId': hospitalId,
        'userId': userId,
        'patientName': patientName,
        'phone': phone,
        'address': address,
        'emergency': emergency,
        'ambulanceType': ambulanceType,
        'time': time.toIso8601String(),
        'status': status.index,
        'ambulanceId': ambulanceId,
      };

  factory AmbulanceRequest.fromJson(Map<String, dynamic> j) => AmbulanceRequest(
        id: j['id'],
        hospitalId: j['hospitalId'] ?? '',
        userId: j['userId'] ?? '',
        patientName: j['patientName'],
        phone: j['phone'],
        address: j['address'],
        emergency: j['emergency'],
        ambulanceType: j['ambulanceType'],
        time: DateTime.parse(j['time']),
        status: AmbStatus.values[j['status']],
        ambulanceId: j['ambulanceId'],
      );
}

class Donor {
  String id;
  String name;
  String phone;
  String group;
  String city;
  DateTime? lastDonated;

  Donor({
    required this.id,
    required this.name,
    required this.phone,
    required this.group,
    required this.city,
    this.lastDonated,
  });

  /// A donor can give blood again after 90 days
  bool get eligible => lastDonated == null || DateTime.now().difference(lastDonated!).inDays >= 90;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'group': group,
        'city': city,
        'lastDonated': lastDonated?.toIso8601String(),
      };

  factory Donor.fromJson(Map<String, dynamic> j) => Donor(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        group: j['group'],
        city: j['city'],
        lastDonated: j['lastDonated'] == null ? null : DateTime.parse(j['lastDonated']),
      );
}

enum BloodStatus { pending, fulfilled, cancelled }

extension BloodStatusX on BloodStatus {
  String get label => name[0].toUpperCase() + name.substring(1);
  Color get color {
    switch (this) {
      case BloodStatus.pending:
        return Colors.orange;
      case BloodStatus.fulfilled:
        return Colors.green;
      case BloodStatus.cancelled:
        return Colors.red;
    }
  }
}

class BloodRequest {
  String id;
  String hospitalId;
  String userId;
  String patientName;
  String contact;
  String group;
  int units;
  String urgency; // Normal / Urgent / Critical
  String note;
  DateTime time;
  BloodStatus status;

  BloodRequest({
    required this.id,
    this.hospitalId = '',
    this.userId = '',
    required this.patientName,
    required this.contact,
    required this.group,
    required this.units,
    required this.urgency,
    this.note = '',
    required this.time,
    this.status = BloodStatus.pending,
  });

  String get code => id.substring(id.length - 6);

  Map<String, dynamic> toJson() => {
        'id': id,
        'hospitalId': hospitalId,
        'userId': userId,
        'patientName': patientName,
        'contact': contact,
        'group': group,
        'units': units,
        'urgency': urgency,
        'note': note,
        'time': time.toIso8601String(),
        'status': status.index,
      };

  factory BloodRequest.fromJson(Map<String, dynamic> j) => BloodRequest(
        id: j['id'],
        hospitalId: j['hospitalId'] ?? '',
        userId: j['userId'] ?? '',
        patientName: j['patientName'],
        contact: j['contact'],
        group: j['group'],
        units: j['units'],
        urgency: j['urgency'],
        note: j['note'] ?? '',
        time: DateTime.parse(j['time']),
        status: BloodStatus.values[j['status']],
      );
}

// ===========================================================================
// Hospitals + patient accounts
// ===========================================================================
class Hospital {
  String id;
  String name;
  String address;
  String phone;
  String whatsapp;

  // Hospital management login (created by the admin). Password is stored only as a salted hash.
  String loginId;
  String salt;
  String passHash;

  Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    this.loginId = '',
    this.salt = '',
    this.passHash = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'loginId': loginId,
        'salt': salt,
        'passHash': passHash,
      };

  factory Hospital.fromJson(Map<String, dynamic> j) => Hospital(
        id: j['id'],
        name: j['name'],
        address: j['address'] ?? '',
        phone: j['phone'] ?? '',
        whatsapp: j['whatsapp'] ?? '',
        loginId: j['loginId'] ?? '',
        salt: j['salt'] ?? '',
        passHash: j['passHash'] ?? '',
      );
}

/// A patient account. The password is never stored - only a salted SHA-256 hash.
class AppUser {
  String id;
  String name;
  String phone;
  String salt;
  String passHash;

  // Emergency health card (per patient)
  String cardAge;
  String cardBloodGroup;
  String cardAllergies;
  String cardConditions;
  String cardContactName;
  String cardContactPhone;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.salt,
    required this.passHash,
    this.cardAge = '',
    this.cardBloodGroup = '',
    this.cardAllergies = '',
    this.cardConditions = '',
    this.cardContactName = '',
    this.cardContactPhone = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'salt': salt,
        'passHash': passHash,
        'cardAge': cardAge,
        'cardBloodGroup': cardBloodGroup,
        'cardAllergies': cardAllergies,
        'cardConditions': cardConditions,
        'cardContactName': cardContactName,
        'cardContactPhone': cardContactPhone,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        salt: j['salt'],
        passHash: j['passHash'],
        cardAge: j['cardAge'] ?? '',
        cardBloodGroup: j['cardBloodGroup'] ?? '',
        cardAllergies: j['cardAllergies'] ?? '',
        cardConditions: j['cardConditions'] ?? '',
        cardContactName: j['cardContactName'] ?? '',
        cardContactPhone: j['cardContactPhone'] ?? '',
      );
}

// ===========================================================================
// In-app alerts (notifications)
// ===========================================================================
/// toType is 'user' (a patient) or 'hospital'; toId is the user id / hospital id.
/// kind is 'appointment', 'emergency' or 'info'.
class AppNotification {
  String id;
  String toType;
  String toId;
  String kind;
  String title;
  String body;
  DateTime time;
  bool read;

  AppNotification({
    required this.id,
    required this.toType,
    required this.toId,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'toType': toType,
        'toId': toId,
        'kind': kind,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        toType: j['toType'],
        toId: j['toId'],
        kind: j['kind'] ?? 'info',
        title: j['title'],
        body: j['body'] ?? '',
        time: DateTime.parse(j['time']),
        read: j['read'] ?? false,
      );
}
