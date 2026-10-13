import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'admin_emergency.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'links.dart';
import 'ui.dart';

/// Accepts the plain 6-digit code, or the full text found inside the appointment QR
/// (HMS|code|patient|doctor|date) and returns just the code.
String extractCode(String text) {
  final t = text.trim();
  if (t.startsWith('HMS|')) {
    final parts = t.split('|');
    if (parts.length > 1) return parts[1].trim();
  }
  return t;
}

// ===========================================================================
// HOSPITAL MANAGEMENT PANEL
// Only the hospital's own staff can log in here. They confirm / decline appointments
// and manage doctors, ambulances, blood bank and hospital details of THEIR hospital.
// ===========================================================================
class HospitalPanel extends StatefulWidget {
  const HospitalPanel({super.key});

  @override
  State<HospitalPanel> createState() => _HospitalPanelState();
}

class _HospitalPanelState extends State<HospitalPanel> {
  int index = 0;

  static const _labels = ['Dashboard', 'Appointments', 'Doctors', 'Ambulance', 'Blood Bank', 'Hospital Profile'];
  static const _icons = [
    Icons.dashboard,
    Icons.event_note,
    Icons.medical_services,
    Icons.emergency,
    Icons.bloodtype,
    Icons.apartment,
  ];

  Widget _page() {
    switch (index) {
      case 0:
        return _Overview(onGo: (i) => setState(() => index = i));
      case 1:
        return _AllAppointments();
      case 2:
        return _ManageDoctors();
      case 3:
        return AdminAmbulanceTab();
      case 4:
        return AdminBloodTab();
      default:
        return AdminHospitalTab(key: ValueKey(store.activeHospitalId));
    }
  }

  /// Number shown on the sidebar for things that need attention
  int _badge(int i) {
    if (i == 1) return store.appointments.where((a) => a.status == ApptStatus.pending).length;
    if (i == 3) return store.ambulanceRequests.where((r) => r.status == AmbStatus.requested).length;
    if (i == 4) return store.bloodRequests.where((r) => r.status == BloodStatus.pending).length;
    return 0;
  }

  Widget _icon(int i) {
    final n = _badge(i);
    return Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(_icons[i]));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 860;
          final appBar = AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Hospital Management  •  ${_labels[index]}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [
              const AlertBell(),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: store.logout),
            ],
          );

          if (wide) {
            return Scaffold(
              appBar: appBar,
              body: Row(children: [
                NavigationRail(
                  extended: true,
                  minExtendedWidth: 210,
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  destinations: [
                    for (var i = 0; i < _labels.length; i++)
                      NavigationRailDestination(icon: _icon(i), label: Text(_labels[i])),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _page()),
              ]),
            );
          }
          return Scaffold(
            appBar: appBar,
            drawer: NavigationDrawer(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: GradientHeader(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.local_hospital, size: 30),
                      const SizedBox(height: 6),
                      Text(store.hospitalName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Text('Hospital Management', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                ),
                for (var i = 0; i < _labels.length; i++) NavigationDrawerDestination(icon: _icon(i), label: Text(_labels[i])),
              ],
            ),
            body: _page(),
          );
        });
      },
    );
  }
}

// ---------------- Appointment tile with Confirm / Decline ----------------
Future<void> _declineDialog(BuildContext context, Appointment a) async {
  final c = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.event_busy, color: Colors.deepOrange, size: 40),
      title: Text('Decline ${a.patientName}\'s appointment?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${a.doctorName}\n${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextField(
          controller: c,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Reason (shown to the patient)', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
          onPressed: () {
            store.declineAppointment(a, c.text.trim());
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment declined - patient has been alerted')));
          },
          child: const Text('Decline'),
        ),
      ],
    ),
  );
  c.dispose();
}

class _AppointmentTile extends StatelessWidget {
  final Appointment a;
  final VoidCallback? onComplete;
  const _AppointmentTile({required this.a, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final color = a.status.color;
    final token = store.tokenFor(a);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 6, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(a.patientName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Pill(a.status.label, color),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (v) {
                      if (v == 'delete') store.deleteAppointment(a);
                      if (v == 'completed' && onComplete != null) onComplete!();
                      if (v == 'pending') store.setStatus(a, ApptStatus.pending);
                    },
                    itemBuilder: (_) => [
                      if (a.status == ApptStatus.confirmed && onComplete != null)
                        const PopupMenuItem(value: 'completed', child: Text('Complete visit / write prescription')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete record')),
                    ],
                  ),
                ]),
                const SizedBox(height: 2),
                Text('${a.doctorName}  •  ${a.specialty}'),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.event, size: 15),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${fmtDate(a.dateTime)}  •  ${fmtTime(a.dateTime)}')),
                  if (token > 0) Pill('Token #$token', kBrand),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.call, size: 15),
                  const SizedBox(width: 6),
                  Text(a.phone),
                  const SizedBox(width: 12),
                  Text('Code ${a.code}', style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 2),
                Text('Reason: ${a.reason}', style: Theme.of(context).textTheme.bodySmall),
                if (a.status == ApptStatus.declined && a.declineReason.isNotEmpty)
                  Text('Declined: ${a.declineReason}', style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (a.status == ApptStatus.pending) ...[
                    FilledButton.icon(
                      onPressed: () {
                        store.confirmAppointment(a);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Appointment confirmed - patient has been alerted')));
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Confirm'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
                      onPressed: () => _declineDialog(context, a),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Decline'),
                    ),
                  ],
                  if (a.status == ApptStatus.confirmed) ...[
                    if (onComplete != null)
                      FilledButton.tonalIcon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.medical_information, size: 18),
                        label: const Text('Complete visit'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange),
                      onPressed: () => _declineDialog(context, a),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Decline'),
                    ),
                  ],
                  if (a.status != ApptStatus.cancelled)
                    TextButton.icon(
                      onPressed: () => openWhatsApp(context, a.phone, store.confirmationMessage(a)),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp patient'),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Dashboard ----------------
class _Overview extends StatelessWidget {
  final ValueChanged<int> onGo;
  const _Overview({required this.onGo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final appts = store.appointments;
    final todayCount = appts.where((a) => dateOnly(a.dateTime) == today && !a.status.isDead).length;
    final pendingList = appts.where((a) => a.status == ApptStatus.pending).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final available = store.doctors.where((d) => store.worksOn(d, today)).length;
    final revenue = appts
        .where((a) => a.status == ApptStatus.completed)
        .fold<int>(0, (sum, a) => sum + (store.doctorById(a.doctorId)?.fee ?? 0));

    final rated = appts.where((a) => a.rating != null).toList();
    final avgRating = rated.isEmpty ? '-' : (rated.fold<int>(0, (sum, a) => sum + a.rating!) / rated.length).toStringAsFixed(1);
    final ambPending = store.ambulanceRequests.where((r) => r.status == AmbStatus.requested).length;
    final bloodPending = store.bloodRequests.where((r) => r.status == BloodStatus.pending).length;

    final perDoctor = <String, int>{};
    for (final a in appts.where((a) => !a.status.isDead)) {
      perDoctor[a.doctorName] = (perDoctor[a.doctorName] ?? 0) + 1;
    }
    final maxV = perDoctor.values.fold<int>(1, (m, v) => v > m ? v : m);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GradientHeader(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.local_hospital, size: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Welcome back!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    Text(store.hospitalName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${fmtDate(now)}  •  ${store.hospitalAddress}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            if (ambPending > 0 || bloodPending > 0) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('EMERGENCY REQUESTS WAITING',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Text([
                          if (ambPending > 0) '$ambPending ambulance',
                          if (bloodPending > 0) '$bloodPending blood',
                        ].join('  •  '), style: const TextStyle(color: Colors.black87)),
                      ]),
                    ),
                    if (ambPending > 0) FilledButton(onPressed: () => onGo(3), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Ambulance')),
                    if (bloodPending > 0) ...[
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => onGo(4), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Blood')),
                    ],
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 12),
            GridView.extent(
              maxCrossAxisExtent: 300,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                StatTile(label: 'Pending approval', value: '${pendingList.length}', icon: Icons.hourglass_top, color: Colors.orange),
                StatTile(label: 'Appointments today', value: '$todayCount', icon: Icons.today, color: Colors.blue),
                StatTile(label: 'Doctors available today', value: '$available / ${store.doctors.length}', icon: Icons.event_available, color: Colors.green),
                StatTile(label: 'Total appointments', value: '${appts.length}', icon: Icons.list_alt, color: Colors.indigo),
                StatTile(label: 'Revenue (completed)', value: '₹$revenue', icon: Icons.payments, color: Colors.purple),
                StatTile(label: 'Avg patient rating', value: avgRating, icon: Icons.star, color: Colors.amber.shade700),
                StatTile(label: 'Ambulance requests', value: '$ambPending', icon: Icons.emergency, color: Colors.red),
                StatTile(label: 'Blood requests', value: '$bloodPending', icon: Icons.bloodtype, color: Colors.redAccent),
              ],
            ),
            SectionTitle('Waiting for your approval',
                trailing: TextButton(onPressed: () => onGo(1), child: const Text('See all'))),
            if (pendingList.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No pending appointments. You are all caught up ✅')))
            else
              ...pendingList.take(5).map((a) => _AppointmentTile(a: a)),
            const SectionTitle('Appointments per doctor'),
            if (perDoctor.isEmpty) const Text('No bookings yet.'),
            ...perDoctor.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 150, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: e.value / maxV, minHeight: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value}'),
                  ]),
                )),
          ],
        ),
      ),
    );
  }
}

// ---------------- All appointments ----------------
class _AllAppointments extends StatefulWidget {
  const _AllAppointments();

  @override
  State<_AllAppointments> createState() => _AllAppointmentsState();
}

class _AllAppointmentsState extends State<_AllAppointments> {
  ApptStatus? filter;

  void _completeDialog(BuildContext context, Appointment a) {
    final dx = TextEditingController(text: a.diagnosis);
    final rx = TextEditingController(text: a.prescription);
    final adv = TextEditingController(text: a.advice);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete visit: ${a.patientName}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: dx,
              decoration: const InputDecoration(labelText: 'Diagnosis', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rx,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Prescription (e.g. Paracetamol 1-0-1, 5 days)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: adv,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Advice / follow-up', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              store.completeAppointment(a, dx.text.trim(), rx.text.trim(), adv.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save & complete'),
          ),
        ],
      ),
    );
  }

  void _checkIn(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Patient check-in'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '6-digit code (or paste the QR text)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final a = store.findByCode(extractCode(c.text));
              Navigator.pop(ctx);
              if (a == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code - appointment not found')));
                return;
              }
              if (a.status.isDead) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This appointment was cancelled / declined')));
                return;
              }
              store.setStatus(a, ApptStatus.confirmed);
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  icon: const Icon(Icons.verified, color: Colors.green, size: 44),
                  title: const Text('Check-in successful'),
                  content: Text('${a.patientName}\n${a.doctorName}\n${fmtDate(a.dateTime)} at ${fmtTime(a.dateTime)}\n\nStatus: Confirmed',
                      textAlign: TextAlign.center),
                  actions: [FilledButton(onPressed: () => Navigator.pop(ctx2), child: const Text('OK'))],
                ),
              );
            },
            child: const Text('Check in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = store.appointments.where((a) => filter == null || a.status == filter).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => _checkIn(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Check-in by QR code'),
          ),
        ),
      ),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: ChoiceChip(label: const Text('All'), selected: filter == null, onSelected: (_) => setState(() => filter = null)),
            ),
            ...ApptStatus.values.map((s) => Padding(
                  padding: const EdgeInsets.all(6),
                  child: ChoiceChip(label: Text(s.label), selected: filter == s, onSelected: (_) => setState(() => filter = s)),
                )),
          ],
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No appointments'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final a = list[i];
                  return _AppointmentTile(a: a, onComplete: () => _completeDialog(context, a));
                },
              ),
      ),
    ]);
  }
}

// ---------------- Manage doctors ----------------
class _ManageDoctors extends StatelessWidget {
  const _ManageDoctors();

  Future<void> _openForm(BuildContext context, {Doctor? doctor}) async {
    final result = await showDialog<Doctor>(
      context: context,
      builder: (_) => _DoctorFormDialog(doctor: doctor),
    );
    if (result == null) return;
    if (doctor == null) {
      store.addDoctor(result);
    } else {
      store.updateDoctor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add doctor'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: store.doctors.length,
        itemBuilder: (_, i) {
          final d = store.doctors[i];
          final days = d.days.map((x) => weekdayShort[x - 1]).join(', ');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(child: Text(d.initials)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(d.specialty),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(context, doctor: d)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove ${d.name}?'),
                        content: const Text('Their upcoming appointments will be cancelled.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                          FilledButton(
                            onPressed: () {
                              store.deleteDoctor(d);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
                Text('Days: $days'),
                Text('Hours: ${fmtHour(d.startHour)} - ${fmtHour(d.endHour)}'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('On leave'),
                  value: d.onLeave,
                  onChanged: (_) => store.toggleLeave(d),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _DoctorFormDialog extends StatefulWidget {
  final Doctor? doctor;
  const _DoctorFormDialog({this.doctor});

  @override
  State<_DoctorFormDialog> createState() => _DoctorFormDialogState();
}

class _DoctorFormDialogState extends State<_DoctorFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController name, specialty, exp, fee;
  late Set<int> days;
  late int start, end;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    name = TextEditingController(text: d?.name ?? 'Dr. ');
    specialty = TextEditingController(text: d?.specialty ?? '');
    exp = TextEditingController(text: d?.experience.toString() ?? '');
    fee = TextEditingController(text: d?.fee.toString() ?? '');
    days = {...(d?.days ?? [1, 2, 3, 4, 5])};
    start = d?.startHour ?? 9;
    end = d?.endHour ?? 17;
  }

  @override
  void dispose() {
    name.dispose();
    specialty.dispose();
    exp.dispose();
    fee.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _num(String? v) => (int.tryParse(v ?? '') == null) ? 'Number' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.doctor != null;
    return AlertDialog(
      title: Text(editing ? 'Edit doctor' : 'Add doctor'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: _req),
            TextFormField(controller: specialty, decoration: const InputDecoration(labelText: 'Specialty'), validator: _req),
            TextFormField(controller: exp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Experience (years)'), validator: _num),
            TextFormField(controller: fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fee (₹)'), validator: _num),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) {
                final day = i + 1;
                return FilterChip(
                  label: Text(weekdayShort[i]),
                  selected: days.contains(day),
                  onSelected: (v) => setState(() => v ? days.add(day) : days.remove(day)),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('From '),
              DropdownButton<int>(
                value: start,
                items: List.generate(24, (h) => DropdownMenuItem(value: h, child: Text(fmtHour(h)))),
                onChanged: (v) => setState(() {
                  start = v!;
                  if (end <= start) end = start + 1 > 23 ? 23 : start + 1;
                }),
              ),
              const Text(' to '),
              DropdownButton<int>(
                value: end,
                items: List.generate(24, (h) => DropdownMenuItem(value: h, child: Text(fmtHour(h)))),
                onChanged: (v) => setState(() => end = v!),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            if (days.isEmpty || end <= start) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pick at least one day and a valid time range')));
              return;
            }
            final sortedDays = days.toList()..sort();
            final d = widget.doctor ??
                Doctor(id: newId(), name: '', specialty: '', experience: 0, fee: 0, days: []);
            d.name = name.text.trim();
            d.specialty = specialty.text.trim();
            d.experience = int.parse(exp.text);
            d.fee = int.parse(fee.text);
            d.days = sortedDays;
            d.startHour = start;
            d.endHour = end;
            Navigator.pop(context, d);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
