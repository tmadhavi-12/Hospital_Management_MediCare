import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'db.dart';
import 'models.dart';
import 'links.dart';

final HospitalStore store = HospitalStore();

class HospitalStore extends ChangeNotifier {
  // ---- All data (stored in the database) ----
  List<Hospital> hospitals = [];
  List<AppUser> users = [];
  List<Doctor> allDoctors = [];
  List<Appointment> allAppointments = [];
  List<Ambulance> allAmbulances = [];
  List<AmbulanceRequest> allAmbulanceRequests = [];
  List<BloodRequest> allBloodRequests = [];
  List<Donor> donors = [];
  Map<String, Map<String, int>> stockByHospital = {}; // hospitalId -> (blood group -> units)
  List<AppNotification> notifications = [];

  // ---- Settings / session ----
  bool dark = false;
  String adminPin = '1234';
  // Three kinds of login:
  //  * patient        -> currentUser is set
  //  * hospital staff -> isHospital = true (manages ONLY its own hospital: confirm / decline etc.)
  //  * super admin    -> isSuperAdmin = true (can ONLY add hospitals + create their logins)
  AppUser? currentUser;
  bool isHospital = false;
  bool isSuperAdmin = false;
  String activeHospitalId = ''; // hospital the patient selected, or the hospital that staff logged into

  bool get loggedIn => isSuperAdmin || isHospital || currentUser != null;
  bool get needsHospital => currentUser != null && hospitalById(activeHospitalId) == null;

  /// Another device changed shared data: reload everything and refresh the UI.
  void _onRemoteChange() {
    _loadAll();
    final cu = currentUser;
    if (cu != null) {
      for (final u in users) {
        if (u.id == cu.id) {
          currentUser = u;
          break;
        }
      }
    }
    notifyListeners();
  }

  Future<void> init() async {
    Db.onRemoteChange = _onRemoteChange;
    await Db.init();
    dark = Db.getMeta('dark') == '1';
    adminPin = Db.getMeta('adminPin') ?? '1234';

    if (Db.isFirstRun) {
      _seedAll();
      await _save();
    } else {
      _loadAll();
      if (_ensureHospitalLogins()) await _save();
    }
    _restoreSession();
  }

  void _loadAll() {
    List<T> load<T>(String table, T Function(Map<String, dynamic>) f) => Db.all(table).map(f).toList();
    hospitals = load('hospitals', Hospital.fromJson);
    users = load('users', AppUser.fromJson);
    allDoctors = load('doctors', Doctor.fromJson);
    allAppointments = load('appointments', Appointment.fromJson);
    allAmbulances = load('ambulances', Ambulance.fromJson);
    allAmbulanceRequests = load('ambulanceRequests', AmbulanceRequest.fromJson);
    allBloodRequests = load('bloodRequests', BloodRequest.fromJson);
    donors = load('donors', Donor.fromJson);
    stockByHospital = {
      for (final r in Db.all('bloodStock')) r['id'] as String: Map<String, int>.from(r['stock'] as Map),
    };
    notifications = load('notifications', AppNotification.fromJson);
  }

  /// Older saved data has hospitals without a login. Give each one a default login.
  bool _ensureHospitalLogins() {
    var changed = false;
    const known = {'h1': 'citycare', 'h2': 'sunrise', 'h3': 'lifeline'};
    for (final h in hospitals) {
      if (h.loginId.isEmpty) {
        h.loginId = known[h.id] ?? 'hospital${h.id}';
        _setHospitalPassword(h, 'hospital123');
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _save() async {
    await Db.sync('hospitals', hospitals.map((e) => e.toJson()));
    await Db.sync('users', users.map((e) => e.toJson()));
    await Db.sync('doctors', allDoctors.map((e) => e.toJson()));
    await Db.sync('appointments', allAppointments.map((e) => e.toJson()));
    await Db.sync('ambulances', allAmbulances.map((e) => e.toJson()));
    await Db.sync('ambulanceRequests', allAmbulanceRequests.map((e) => e.toJson()));
    await Db.sync('bloodRequests', allBloodRequests.map((e) => e.toJson()));
    await Db.sync('donors', donors.map((e) => e.toJson()));
    await Db.sync(
        'bloodStock', stockByHospital.entries.map((e) => <String, dynamic>{'id': e.key, 'stock': e.value}));
    await Db.sync('notifications', notifications.map((e) => e.toJson()));
    await Db.setMeta('dark', dark ? '1' : '0');
    await Db.setMeta('adminPin', adminPin);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // =====================================================================
  // Login / register / logout
  // =====================================================================
  String _hash(String salt, String password) => sha256.convert(utf8.encode('$salt:$password')).toString();

  String _normalizePhone(String p) {
    var d = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length > 10) d = d.substring(d.length - 10);
    return d;
  }

  /// Creates a patient account and logs in. Returns an error message, or null on success.
  String? register(String name, String phone, String password) {
    final ph = _normalizePhone(phone);
    if (name.trim().isEmpty) return 'Enter your name';
    if (ph.length != 10) return 'Enter a valid 10-digit phone number';
    if (password.length < 4) return 'Password must be at least 4 characters';
    if (users.any((u) => u.phone == ph)) return 'This phone number is already registered. Please login.';
    final salt = newId();
    final u = AppUser(id: newId(), name: name.trim(), phone: ph, salt: salt, passHash: _hash(salt, password));
    users.add(u);
    _startUserSession(u);
    _changed();
    return null;
  }

  /// Patient login. Returns an error message, or null on success.
  String? loginUser(String phone, String password) {
    final ph = _normalizePhone(phone);
    for (final u in users) {
      if (u.phone == ph) {
        if (_hash(u.salt, password) != u.passHash) return 'Wrong password';
        _startUserSession(u);
        notifyListeners();
        return null;
      }
    }
    return 'No account found for this phone number. Please register first.';
  }

  void _startUserSession(AppUser u) {
    _clearSession();
    currentUser = u;
    final last = Db.getMeta('hospital_${u.id}') ?? '';
    activeHospitalId = hospitalById(last) == null ? '' : last;
    Db.setMeta('session', 'user:${u.id}');
  }

  void _clearSession() {
    isSuperAdmin = false;
    isHospital = false;
    currentUser = null;
    activeHospitalId = '';
  }

  /// Super admin login with the PIN. Returns true on success.
  bool loginAdmin(String pin) {
    if (pin != adminPin) return false;
    _clearSession();
    isSuperAdmin = true;
    Db.setMeta('session', 'admin');
    notifyListeners();
    return true;
  }

  /// Hospital management login (each hospital has its own ID + password). Returns an error or null.
  String? loginHospital(String loginId, String password) {
    final id = loginId.trim().toLowerCase();
    for (final h in hospitals) {
      if (h.loginId.toLowerCase() == id) {
        if (_hash(h.salt, password) != h.passHash) return 'Wrong password';
        _clearSession();
        isHospital = true;
        activeHospitalId = h.id;
        Db.setMeta('session', 'hospital:${h.id}');
        notifyListeners();
        return null;
      }
    }
    return 'No hospital found with this login ID';
  }

  void logout() {
    _clearSession();
    Db.deleteMeta('session');
    notifyListeners();
  }

  void _restoreSession() {
    final s = Db.getMeta('session');
    if (s == null) return;
    if (s == 'admin') {
      isSuperAdmin = true;
    } else if (s.startsWith('hospital:')) {
      final h = hospitalById(s.substring(9));
      if (h != null) {
        isHospital = true;
        activeHospitalId = h.id;
      }
    } else if (s.startsWith('user:')) {
      final id = s.substring(5);
      for (final u in users) {
        if (u.id == id) {
          currentUser = u;
          final last = Db.getMeta('hospital_${u.id}') ?? '';
          activeHospitalId = hospitalById(last) == null ? '' : last;
        }
      }
    }
  }

  /// Patient picks a hospital.
  void selectHospital(String id) {
    if (currentUser == null) return;
    activeHospitalId = id;
    Db.setMeta('hospital_${currentUser!.id}', id);
    notifyListeners();
  }

  // =====================================================================
  // Hospitals
  // =====================================================================
  Hospital? hospitalById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final h in hospitals) {
      if (h.id == id) return h;
    }
    return null;
  }

  Hospital get activeHospital =>
      hospitalById(activeHospitalId) ??
      (hospitals.isNotEmpty
          ? hospitals.first
          : Hospital(id: '', name: 'Hospital', address: '', phone: '', whatsapp: ''));

  String get hospitalName => activeHospital.name;
  String get hospitalAddress => activeHospital.address;
  String get hospitalPhone => activeHospital.phone;
  String get hospitalWhatsApp => activeHospital.whatsapp;

  String get hospitalMapQuery => '$hospitalName, $hospitalAddress';
  String get hospitalMapLink => mapsSearchUri(hospitalMapQuery).toString();

  String mapQueryFor(String hospitalId) {
    final h = hospitalById(hospitalId) ?? activeHospital;
    return '${h.name}, ${h.address}';
  }

  int doctorCount(String hospitalId) => allDoctors.where((d) => d.hospitalId == hospitalId).length;

  void setHospital({required String name, required String address, required String phone, required String whatsapp}) {
    final h = hospitalById(activeHospitalId);
    if (h == null) return;
    h.name = name;
    h.address = address;
    h.phone = phone;
    h.whatsapp = whatsapp;
    _changed();
  }

  void _setHospitalPassword(Hospital h, String password) {
    h.salt = newId();
    h.passHash = _hash(h.salt, password);
  }

  /// SUPER ADMIN: adds a hospital together with its management login. Returns an error or null.
  String? addHospital({
    required String name,
    required String address,
    required String phone,
    required String whatsapp,
    required String loginId,
    required String password,
  }) {
    final lid = loginId.trim().toLowerCase();
    if (lid.length < 3 || lid.contains(' ')) return 'Login ID must be at least 3 characters, without spaces';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (hospitals.any((h) => h.loginId.toLowerCase() == lid)) return 'This login ID is already used';
    final h = Hospital(id: newId(), name: name, address: address, phone: phone, whatsapp: whatsapp, loginId: lid);
    _setHospitalPassword(h, password);
    hospitals.add(h);
    stockByHospital[h.id] = _emptyStock();
    _changed();
    return null;
  }

  /// SUPER ADMIN: sets a new password for a hospital's management login.
  String? resetHospitalPassword(Hospital h, String newPassword) {
    if (newPassword.length < 6) return 'Password must be at least 6 characters';
    _setHospitalPassword(h, newPassword);
    _changed();
    return null;
  }

  /// HOSPITAL: changes its own password.
  String? changeHospitalPassword(String oldPassword, String newPassword) {
    final h = hospitalById(activeHospitalId);
    if (h == null || !isHospital) return 'Not logged in';
    if (_hash(h.salt, oldPassword) != h.passHash) return 'Current password is wrong';
    if (newPassword.length < 6) return 'New password must be at least 6 characters';
    _setHospitalPassword(h, newPassword);
    _changed();
    return null;
  }

  // =====================================================================
  // Data scoped to the active hospital / logged-in patient
  // =====================================================================
  List<Doctor> get doctors => allDoctors.where((d) => d.hospitalId == activeHospitalId).toList();

  /// Admin: all appointments of the managed hospital. Patient: the patient's own appointments.
  List<Appointment> get appointments => isHospital
      ? allAppointments.where((a) => a.hospitalId == activeHospitalId).toList()
      : allAppointments.where((a) => a.userId == currentUser?.id).toList();

  List<Ambulance> get ambulances => allAmbulances.where((a) => a.hospitalId == activeHospitalId).toList();

  List<AmbulanceRequest> get ambulanceRequests => allAmbulanceRequests
      .where((r) => r.hospitalId == activeHospitalId && (isHospital || r.userId == currentUser?.id))
      .toList();

  List<BloodRequest> get bloodRequests => allBloodRequests
      .where((r) => r.hospitalId == activeHospitalId && (isHospital || r.userId == currentUser?.id))
      .toList();

  Map<String, int> get bloodStock => stockByHospital.putIfAbsent(activeHospitalId, _emptyStock);

  Map<String, int> _emptyStock() => {for (final g in bloodGroups) g: 0};

  List<String> get specialties => doctors.map((e) => e.specialty).toSet().toList()..sort();

  Doctor? doctorById(String id) {
    for (final d in allDoctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ---------- Availability ----------
  bool worksOn(Doctor d, DateTime day) => !d.onLeave && d.days.contains(day.weekday);

  bool isBooked(String doctorId, DateTime t, {String? excludeId}) => allAppointments.any((a) =>
      a.doctorId == doctorId &&
      a.id != excludeId &&
      !a.status.isDead &&
      a.dateTime == t);

  List<Slot> slotsFor(Doctor d, DateTime day, {String? excludeId}) {
    if (!worksOn(d, day)) return [];
    final now = DateTime.now();
    final slots = <Slot>[];
    var t = DateTime(day.year, day.month, day.day, d.startHour);
    final end = DateTime(day.year, day.month, day.day, d.endHour);
    while (t.isBefore(end)) {
      final ok = t.isAfter(now) && !isBooked(d.id, t, excludeId: excludeId);
      slots.add(Slot(t, ok));
      t = t.add(const Duration(minutes: 30));
    }
    return slots;
  }

  int freeSlotsToday(Doctor d) => slotsFor(d, dateOnly(DateTime.now())).where((s) => s.available).length;

  // ---------- Appointments ----------
  Appointment? book(Doctor d, DateTime t, String patient, String phone, String reason) {
    if (isBooked(d.id, t)) return null;
    final appt = Appointment(
      id: newId(),
      hospitalId: d.hospitalId,
      userId: currentUser?.id ?? '',
      doctorId: d.id,
      doctorName: d.name,
      specialty: d.specialty,
      patientName: patient,
      phone: phone,
      reason: reason,
      dateTime: t,
    );
    allAppointments.add(appt);
    _alert('hospital', d.hospitalId, 'appointment', 'New appointment request',
        '$patient booked ${d.name} (${d.specialty}) on ${fmtDate(t)} at ${fmtTime(t)}.\nReason: $reason\nPlease confirm or decline.');
    _changed();
    return appt;
  }

  /// Reception check-in by code (admin: searches only the hospital being managed).
  Appointment? findByCode(String code) {
    for (final a in allAppointments) {
      if (a.hospitalId == activeHospitalId && a.code == code.trim()) return a;
    }
    return null;
  }

  /// Patient cancels his own booking.
  void cancel(Appointment a) {
    a.status = ApptStatus.cancelled;
    _alert('hospital', a.hospitalId, 'appointment', 'Appointment cancelled',
        '${a.patientName} cancelled the visit with ${a.doctorName} on ${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}.');
    _changed();
  }

  bool reschedule(Appointment a, DateTime t) {
    if (isBooked(a.doctorId, t, excludeId: a.id)) return false;
    a.dateTime = t;
    a.status = ApptStatus.pending;
    _alert('hospital', a.hospitalId, 'appointment', 'Appointment rescheduled',
        '${a.patientName} moved the visit with ${a.doctorName} to ${fmtDate(t)} at ${fmtTime(t)}. Please confirm again.');
    _changed();
    return true;
  }

  /// HOSPITAL: confirms a booking and alerts the patient.
  void confirmAppointment(Appointment a) {
    final was = a.status;
    a.status = ApptStatus.confirmed;
    if (was != ApptStatus.confirmed) {
      final h = hospitalById(a.hospitalId);
      _alert('user', a.userId, 'appointment', 'Appointment confirmed ✅',
          '${h?.name ?? 'The hospital'} confirmed your visit with ${a.doctorName}.\n${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}  •  Token #${tokenFor(a)}\nCheck-in code: ${a.code}');
    }
    _changed();
  }

  /// HOSPITAL: declines a booking and alerts the patient. The slot becomes free again.
  void declineAppointment(Appointment a, String reason) {
    a.status = ApptStatus.declined;
    a.declineReason = reason;
    final h = hospitalById(a.hospitalId);
    _alert('user', a.userId, 'appointment', 'Appointment declined',
        '${h?.name ?? 'The hospital'} could not accept your visit with ${a.doctorName} on ${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}.'
        '${reason.isEmpty ? '' : '\nReason: $reason'}\nPlease book another slot.');
    _changed();
  }

  void setStatus(Appointment a, ApptStatus s) {
    if (s == ApptStatus.confirmed) {
      confirmAppointment(a);
      return;
    }
    if (s == ApptStatus.declined) {
      declineAppointment(a, a.declineReason);
      return;
    }
    a.status = s;
    _changed();
  }

  void completeAppointment(Appointment a, String diagnosis, String prescription, String advice) {
    a.diagnosis = diagnosis;
    a.prescription = prescription;
    a.advice = advice;
    a.status = ApptStatus.completed;
    _alert('user', a.userId, 'appointment', 'Visit completed',
        'Your prescription from ${a.doctorName} is ready. Open Bookings → History to view it.');
    _changed();
  }

  /// Message the hospital can send to the patient on WhatsApp
  String confirmationMessage(Appointment a) {
    final h = hospitalById(a.hospitalId);
    if (a.status == ApptStatus.declined) {
      return 'Hello ${a.patientName}, ${h?.name ?? 'the hospital'} could not accept your appointment with ${a.doctorName} on '
          '${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}.${a.declineReason.isEmpty ? '' : ' Reason: ${a.declineReason}.'} Please book another slot.';
    }
    return 'Hello ${a.patientName}, your appointment at ${h?.name ?? 'the hospital'} is ${a.status.label.toLowerCase()}.\n'
        'Doctor: ${a.doctorName}\n${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}\nToken #${tokenFor(a)}  •  Check-in code ${a.code}\n'
        'Please arrive 10 minutes early.';
  }

  void deleteAppointment(Appointment a) {
    allAppointments.remove(a);
    _changed();
  }

  /// Patient rates a completed visit; the doctor's average rating is updated.
  void rate(Appointment a, int stars, String review) {
    if (a.rating != null) return;
    a.rating = stars;
    a.review = review;
    final d = doctorById(a.doctorId);
    if (d != null) {
      final total = d.rating * d.ratingCount + stars;
      d.ratingCount += 1;
      d.rating = double.parse((total / d.ratingCount).toStringAsFixed(1));
    }
    _changed();
  }

  /// Queue token: position of this appointment among the doctor's bookings that day.
  int tokenFor(Appointment a) {
    if (a.status.isDead) return 0;
    final same = allAppointments
        .where((x) =>
            x.doctorId == a.doctorId &&
            dateOnly(x.dateTime) == dateOnly(a.dateTime) &&
            !x.status.isDead)
        .toList()
      ..sort((p, q) => p.dateTime.compareTo(q.dateTime));
    final i = same.indexWhere((x) => x.id == a.id);
    return i < 0 ? 0 : i + 1;
  }

  Appointment? get nextAppointment {
    final up = appointments.where((a) => a.isUpcoming).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return up.isEmpty ? null : up.first;
  }

  /// Plain-text appointment slip (can be copied / pasted into WhatsApp etc.)
  String slipText(Appointment a) {
    final fee = doctorById(a.doctorId)?.fee ?? 0;
    final token = tokenFor(a);
    final h = hospitalById(a.hospitalId);
    return [
      'HOSPITAL APPOINTMENT SLIP',
      '-------------------------',
      if (h != null) 'Hospital      : ${h.name}',
      'Check-in code : ${a.code}',
      if (token > 0) 'Token number  : #$token',
      'Patient       : ${a.patientName} (${a.phone})',
      'Doctor        : ${a.doctorName} - ${a.specialty}',
      'Date          : ${fmtDate(a.dateTime)}',
      'Time          : ${fmtTime(a.dateTime)}',
      'Fee           : Rs.$fee',
      'Status        : ${a.status.label}',
      '-------------------------',
      'Please arrive 10 minutes early and show the QR / code at reception.',
    ].join('\n');
  }

  // =====================================================================
  // Alerts (in-app notifications)
  // =====================================================================
  void _alert(String toType, String toId, String kind, String title, String body) {
    if (toId.isEmpty) return;
    notifications.add(AppNotification(
      id: newId(),
      toType: toType,
      toId: toId,
      kind: kind,
      title: title,
      body: body,
      time: DateTime.now(),
    ));
    if (notifications.length > 400) notifications.removeRange(0, notifications.length - 400);
  }

  bool _isMine(AppNotification n) {
    if (isHospital) return n.toType == 'hospital' && n.toId == activeHospitalId;
    if (currentUser != null) return n.toType == 'user' && n.toId == currentUser!.id;
    return false;
  }

  /// Alerts for whoever is logged in (newest first)
  List<AppNotification> get myAlerts => notifications.where(_isMine).toList()..sort((a, b) => b.time.compareTo(a.time));

  int get unreadAlerts => notifications.where((n) => _isMine(n) && !n.read).length;

  void markAlertsRead() {
    var any = false;
    for (final n in notifications) {
      if (_isMine(n) && !n.read) {
        n.read = true;
        any = true;
      }
    }
    if (any) _changed();
  }

  // ---------- Profile (the logged-in patient) ----------
  String get profileName => currentUser?.name ?? '';
  String get profilePhone => currentUser?.phone ?? '';

  /// Kept for older screens: the profile now always comes from the patient's account.
  void saveProfileIfEmpty(String name, String phone) {}

  void changePin(String pin) {
    adminPin = pin;
    _changed();
  }

  // =====================================================================
  // Seed data (first launch / reset)
  // =====================================================================
  void _seedAll() {
    hospitals = _seedHospitals();
    allDoctors = _seedDoctors();
    allAppointments = [];
    allAmbulances = _seedAmbulances();
    allAmbulanceRequests = [];
    allBloodRequests = [];
    donors = _seedDonors();
    notifications = [];
    stockByHospital = {for (final h in hospitals) h.id: _seedStock()};
  }

  /// Demo hospitals. Their logins: citycare / sunrise / lifeline, password hospital123
  List<Hospital> _seedHospitals() {
    final list = [
      Hospital(id: 'h1', name: 'City Care Hospital', address: 'Main Road, Vijayawada, Andhra Pradesh', phone: '9876543210', whatsapp: '919876543210', loginId: 'citycare'),
      Hospital(id: 'h2', name: 'Sunrise Multispeciality Hospital', address: 'Benz Circle, Vijayawada, Andhra Pradesh', phone: '9876543211', whatsapp: '919876543211', loginId: 'sunrise'),
      Hospital(id: 'h3', name: 'Lifeline Hospital', address: 'Brodipet, Guntur, Andhra Pradesh', phone: '9876543212', whatsapp: '919876543212', loginId: 'lifeline'),
    ];
    for (final h in list) {
      _setHospitalPassword(h, 'hospital123');
    }
    return list;
  }

  List<Doctor> _seedDoctors() => [
        // City Care Hospital
        Doctor(id: 'd01', hospitalId: 'h1', name: 'Dr. Ananya Rao', specialty: 'Cardiologist', experience: 12, fee: 800, rating: 4.8, days: [1, 2, 3, 4, 5], startHour: 9, endHour: 15),
        Doctor(id: 'd02', hospitalId: 'h1', name: 'Dr. Rahul Verma', specialty: 'Dermatologist', experience: 8, fee: 600, rating: 4.6, days: [1, 3, 5], startHour: 10, endHour: 16),
        Doctor(id: 'd03', hospitalId: 'h1', name: 'Dr. Priya Sharma', specialty: 'Pediatrician', experience: 10, fee: 500, rating: 4.9, days: [1, 2, 3, 4, 5, 6], startHour: 9, endHour: 13),
        Doctor(id: 'd04', hospitalId: 'h1', name: 'Dr. Suresh Kumar', specialty: 'Orthopedic', experience: 15, fee: 900, rating: 4.7, days: [2, 4, 6], startHour: 11, endHour: 17),
        Doctor(id: 'd05', hospitalId: 'h1', name: 'Dr. Meena Iyer', specialty: 'Neurologist', experience: 14, fee: 1000, rating: 4.8, days: [1, 2, 4], startHour: 10, endHour: 14),
        Doctor(id: 'd06', hospitalId: 'h1', name: 'Dr. Arjun Reddy', specialty: 'General Physician', experience: 6, fee: 300, rating: 4.4, days: [1, 2, 3, 4, 5, 6, 7], startHour: 8, endHour: 20),
        // Sunrise Multispeciality Hospital
        Doctor(id: 'd07', hospitalId: 'h2', name: 'Dr. Kavitha Reddy', specialty: 'Gynecologist', experience: 13, fee: 700, rating: 4.7, days: [1, 2, 3, 5, 6], startHour: 9, endHour: 14),
        Doctor(id: 'd08', hospitalId: 'h2', name: 'Dr. Venkat Rao', specialty: 'Cardiologist', experience: 18, fee: 1000, rating: 4.9, days: [2, 3, 4, 5], startHour: 10, endHour: 16),
        Doctor(id: 'd09', hospitalId: 'h2', name: 'Dr. Sneha Patel', specialty: 'Dermatologist', experience: 7, fee: 550, rating: 4.5, days: [1, 2, 4, 6], startHour: 11, endHour: 17),
        Doctor(id: 'd10', hospitalId: 'h2', name: 'Dr. Mohan Das', specialty: 'General Physician', experience: 9, fee: 350, rating: 4.3, days: [1, 2, 3, 4, 5, 6, 7], startHour: 8, endHour: 18),
        // Lifeline Hospital
        Doctor(id: 'd11', hospitalId: 'h3', name: 'Dr. Lakshmi Narayan', specialty: 'Pediatrician', experience: 11, fee: 450, rating: 4.8, days: [1, 2, 3, 4, 5], startHour: 9, endHour: 15),
        Doctor(id: 'd12', hospitalId: 'h3', name: 'Dr. Imran Khan', specialty: 'Orthopedic', experience: 16, fee: 850, rating: 4.7, days: [1, 3, 5, 6], startHour: 10, endHour: 16),
        Doctor(id: 'd13', hospitalId: 'h3', name: 'Dr. Deepa Menon', specialty: 'Neurologist', experience: 12, fee: 950, rating: 4.6, days: [2, 4, 5], startHour: 10, endHour: 15),
        Doctor(id: 'd14', hospitalId: 'h3', name: 'Dr. Ramesh Babu', specialty: 'General Physician', experience: 5, fee: 300, rating: 4.2, days: [1, 2, 3, 4, 5, 6], startHour: 9, endHour: 19),
      ];

  List<Ambulance> _seedAmbulances() => [
        Ambulance(id: 'a01', hospitalId: 'h1', vehicleNo: 'AP 16 TX 1001', driverName: 'Ravi Kumar', driverPhone: '9000000001', type: 'Basic'),
        Ambulance(id: 'a02', hospitalId: 'h1', vehicleNo: 'AP 16 TX 1002', driverName: 'Suresh Babu', driverPhone: '9000000002', type: 'ICU'),
        Ambulance(id: 'a03', hospitalId: 'h1', vehicleNo: 'AP 16 TX 1003', driverName: 'Naveen', driverPhone: '9000000003', type: 'Oxygen'),
        Ambulance(id: 'a04', hospitalId: 'h2', vehicleNo: 'AP 16 TY 2001', driverName: 'Prasad', driverPhone: '9000000004', type: 'Basic'),
        Ambulance(id: 'a05', hospitalId: 'h2', vehicleNo: 'AP 16 TY 2002', driverName: 'Gopi', driverPhone: '9000000005', type: 'ICU'),
        Ambulance(id: 'a06', hospitalId: 'h3', vehicleNo: 'AP 07 TZ 3001', driverName: 'Anil', driverPhone: '9000000006', type: 'Basic'),
        Ambulance(id: 'a07', hospitalId: 'h3', vehicleNo: 'AP 07 TZ 3002', driverName: 'Srinu', driverPhone: '9000000007', type: 'Oxygen'),
      ];

  Map<String, int> _seedStock() => {'A+': 12, 'A-': 3, 'B+': 10, 'B-': 2, 'AB+': 5, 'AB-': 1, 'O+': 15, 'O-': 4};

  List<Donor> _seedDonors() => [
        Donor(id: 'n1', name: 'Kiran Kumar', phone: '9100000001', group: 'O+', city: 'Vijayawada'),
        Donor(id: 'n2', name: 'Sravani', phone: '9100000002', group: 'B+', city: 'Guntur'),
        Donor(id: 'n3', name: 'Mahesh', phone: '9100000003', group: 'A+', city: 'Vijayawada'),
        Donor(id: 'n4', name: 'Lakshmi', phone: '9100000004', group: 'O-', city: 'Vijayawada', lastDonated: DateTime.now().subtract(const Duration(days: 30))),
        Donor(id: 'n5', name: 'Rajesh', phone: '9100000005', group: 'AB+', city: 'Eluru'),
      ];

  // =====================================================================
  // Health card (saved on the patient's account)
  // =====================================================================
  String get cardAge => currentUser?.cardAge ?? '';
  String get cardBloodGroup => currentUser?.cardBloodGroup ?? '';
  String get cardAllergies => currentUser?.cardAllergies ?? '';
  String get cardConditions => currentUser?.cardConditions ?? '';
  String get cardContactName => currentUser?.cardContactName ?? '';
  String get cardContactPhone => currentUser?.cardContactPhone ?? '';

  void setHealthCard({
    required String name,
    required String phone,
    required String age,
    required String group,
    required String allergies,
    required String conditions,
    required String contactName,
    required String contactPhone,
  }) {
    final u = currentUser;
    if (u == null) return;
    if (name.isNotEmpty) u.name = name;
    final ph = _normalizePhone(phone);
    // The phone number is the login ID, so only change it if it is valid and not used by someone else.
    if (ph.length == 10 && !users.any((x) => x.id != u.id && x.phone == ph)) u.phone = ph;
    u.cardAge = age;
    u.cardBloodGroup = group;
    u.cardAllergies = allergies;
    u.cardConditions = conditions;
    u.cardContactName = contactName;
    u.cardContactPhone = contactPhone;
    _changed();
  }

  /// Text inside the Emergency Health Card QR (readable by any phone camera)
  String get healthCardText => [
        'EMERGENCY HEALTH CARD',
        'Name: ${profileName.isEmpty ? '-' : profileName}',
        if (cardAge.isNotEmpty) 'Age: $cardAge',
        'Blood group: ${cardBloodGroup.isEmpty ? '-' : cardBloodGroup}',
        'Allergies: ${cardAllergies.isEmpty ? 'None known' : cardAllergies}',
        'Conditions: ${cardConditions.isEmpty ? 'None known' : cardConditions}',
        'Emergency contact: ${cardContactName.isEmpty ? '-' : cardContactName} $cardContactPhone',
        'Patient phone: ${profilePhone.isEmpty ? '-' : profilePhone}',
      ].join('\n');

  // =====================================================================
  // Ambulance
  // =====================================================================
  Ambulance? ambulanceById(String? id) {
    if (id == null) return null;
    for (final a in allAmbulances) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<Ambulance> get freeAmbulances => ambulances.where((a) => a.available).toList();

  AmbulanceRequest requestAmbulance(String name, String phone, String address, String emergency, String type) {
    final r = AmbulanceRequest(
      id: newId(),
      hospitalId: activeHospitalId,
      userId: currentUser?.id ?? '',
      patientName: name,
      phone: phone,
      address: address,
      emergency: emergency,
      ambulanceType: type,
      time: DateTime.now(),
    );
    allAmbulanceRequests.add(r);
    _alert('hospital', r.hospitalId, 'emergency', '🚑 EMERGENCY: ambulance requested',
        'Patient: $name ($phone)\nProblem: $emergency\nAmbulance type: $type\nPickup: $address\nRequest ID ${r.code}. Dispatch an ambulance now.');
    _changed();
    return r;
  }

  void assignAmbulance(AmbulanceRequest r, Ambulance a) {
    final old = ambulanceById(r.ambulanceId);
    if (old != null) old.available = true;
    r.ambulanceId = a.id;
    r.status = AmbStatus.dispatched;
    a.available = false;
    _alert('user', r.userId, 'emergency', '🚑 Ambulance is on the way',
        'Vehicle ${a.vehicleNo} (${a.type}) - driver ${a.driverName}, ${a.driverPhone}.\nRequest ID ${r.code}.');
    _changed();
  }

  void setAmbStatus(AmbulanceRequest r, AmbStatus s) {
    r.status = s;
    if (s == AmbStatus.completed || s == AmbStatus.cancelled) {
      final a = ambulanceById(r.ambulanceId);
      if (a != null) a.available = true;
    }
    if (s == AmbStatus.cancelled) {
      _alert('user', r.userId, 'emergency', 'Ambulance request cancelled',
          'The hospital cancelled request ${r.code}. If it is still urgent, call 108 now.');
    }
    _changed();
  }

  void addAmbulance(Ambulance a) {
    a.hospitalId = activeHospitalId;
    allAmbulances.add(a);
    _changed();
  }

  void updateAmbulance() => _changed();

  void toggleAmbulance(Ambulance a) {
    a.available = !a.available;
    _changed();
  }

  void deleteAmbulance(Ambulance a) {
    allAmbulances.remove(a);
    _changed();
  }

  /// Message the patient sends to the hospital control room on WhatsApp
  String ambulanceMessage(AmbulanceRequest r) => [
        '🚑 AMBULANCE REQUEST',
        'Request ID: ${r.code}',
        'Patient: ${r.patientName}',
        'Phone: ${r.phone}',
        'Emergency: ${r.emergency}',
        'Ambulance type: ${r.ambulanceType}',
        'Pickup address: ${r.address}',
        'Pickup on map: ${mapsSearchUri(r.address)}',
        'Time: ${fmtDate(r.time)}, ${fmtTime(r.time)}',
      ].join('\n');

  /// Duty message the control room sends to the driver on WhatsApp
  String driverMessage(AmbulanceRequest r) => [
        '🚑 NEW AMBULANCE DUTY',
        'Request ID: ${r.code}',
        'Patient: ${r.patientName} (${r.phone})',
        'Emergency: ${r.emergency}',
        'Pickup: ${r.address}',
        'Navigate to pickup: ${mapsDirectionsUri(r.address)}',
        'Then drop at: $hospitalName',
        'Hospital location: $hospitalMapLink',
      ].join('\n');

  // =====================================================================
  // Blood bank
  // =====================================================================
  int stock(String group) => bloodStock[group] ?? 0;

  void adjustStock(String group, int delta) {
    final v = stock(group) + delta;
    bloodStock[group] = v < 0 ? 0 : v;
    _changed();
  }

  BloodRequest requestBlood(String name, String contact, String group, int units, String urgency, String note) {
    final r = BloodRequest(
      id: newId(),
      hospitalId: activeHospitalId,
      userId: currentUser?.id ?? '',
      patientName: name,
      contact: contact,
      group: group,
      units: units,
      urgency: urgency,
      note: note,
      time: DateTime.now(),
    );
    allBloodRequests.add(r);
    _alert('hospital', r.hospitalId, 'emergency', '🩸 Blood request ($urgency)',
        'Patient: $name\nBlood group: $group  •  $units unit(s)\nContact: $contact${note.isEmpty ? '' : '\nNote: $note'}\nRequest ID ${r.code}.');
    _changed();
    return r;
  }

  /// Gives blood from stock to the request. Returns false if stock is not enough.
  bool fulfillBlood(BloodRequest r) {
    if (stock(r.group) < r.units) return false;
    bloodStock[r.group] = stock(r.group) - r.units;
    r.status = BloodStatus.fulfilled;
    _alert('user', r.userId, 'emergency', '🩸 Blood is ready',
        '${r.units} unit(s) of ${r.group} are reserved for ${r.patientName} at ${hospitalById(r.hospitalId)?.name ?? 'the hospital'}. Request ID ${r.code}.');
    _changed();
    return true;
  }

  void setBloodStatus(BloodRequest r, BloodStatus s) {
    r.status = s;
    if (s == BloodStatus.cancelled) {
      _alert('user', r.userId, 'emergency', 'Blood request cancelled', 'The hospital cancelled request ${r.code}.');
    }
    _changed();
  }

  String bloodMessage(BloodRequest r) => [
        '🩸 BLOOD REQUEST',
        'Request ID: ${r.code}',
        'Patient: ${r.patientName}',
        'Blood group: ${r.group}',
        'Units needed: ${r.units}',
        'Urgency: ${r.urgency}',
        'Contact: ${r.contact}',
        if (r.note.isNotEmpty) 'Note: ${r.note}',
      ].join('\n');

  void addDonor(Donor d) {
    donors.add(d);
    _changed();
  }

  void deleteDonor(Donor d) {
    donors.remove(d);
    _changed();
  }

  /// group == 'All' returns everyone. With [compatible] it also returns donors who can safely give to [group].
  List<Donor> findDonors(String group, bool compatible) {
    var list = donors.toList();
    if (group != 'All') {
      final allowed = compatible ? (compatibleDonors[group] ?? [group]) : [group];
      list = list.where((d) => allowed.contains(d.group)).toList();
    }
    list.sort((a, b) {
      if (a.eligible != b.eligible) return a.eligible ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  // ---------- Doctors ----------
  void toggleFavorite(Doctor d) {
    d.favorite = !d.favorite;
    _changed();
  }

  void addDoctor(Doctor d) {
    d.hospitalId = activeHospitalId;
    allDoctors.add(d);
    _changed();
  }

  void updateDoctor() => _changed();

  void toggleLeave(Doctor d) {
    d.onLeave = !d.onLeave;
    _changed();
  }

  void deleteDoctor(Doctor d) {
    allDoctors.remove(d);
    for (final a in allAppointments) {
      if (a.doctorId == d.id && a.isUpcoming) {
        a.status = ApptStatus.declined;
        a.declineReason = '${d.name} is no longer available';
        _alert('user', a.userId, 'appointment', 'Appointment declined',
            'Your visit with ${d.name} on ${fmtDate(a.dateTime)} was cancelled by the hospital. Please book another doctor.');
      }
    }
    _changed();
  }

  void setDark(bool v) {
    dark = v;
    _changed();
  }

  /// Restores sample hospitals / doctors / ambulances / blood stock and deletes all bookings and requests.
  /// Patient accounts are kept.
  void resetAll() {
    _seedAll();
    if (hospitalById(activeHospitalId) == null) activeHospitalId = '';
    if (isHospital && activeHospitalId.isEmpty) logout();
    _changed();
  }
}
