import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'store.dart';
import 'links.dart';
import 'settings_screen.dart';
import 'auth_screens.dart';
import 'notifications_screen.dart';
import 'ui.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  String query = '';
  String specialty = 'All';
  bool favOnly = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.doctors.where((d) {
          final q = query.toLowerCase();
          final matchQ = d.name.toLowerCase().contains(q) || d.specialty.toLowerCase().contains(q);
          final matchS = specialty == 'All' || d.specialty == specialty;
          final matchF = !favOnly || d.favorite;
          return matchQ && matchS && matchF;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Find a Doctor'),
                Text(store.hospitalName, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [
              const AlertBell(),
              IconButton(
                tooltip: 'Change hospital',
                icon: const Icon(Icons.local_hospital),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalSelectScreen())),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              IconButton(
                tooltip: 'Favorites only',
                icon: Icon(favOnly ? Icons.favorite : Icons.favorite_border),
                onPressed: () => setState(() => favOnly = !favOnly),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GradientHeader(
                  child: Row(children: [
                    const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.local_hospital, size: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hi ${store.profileName.split(' ').first} 👋', style: const TextStyle(color: Colors.white70)),
                        Text(store.hospitalName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(store.hospitalAddress, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Directions',
                      icon: const Icon(Icons.directions),
                      onPressed: () => openUrl(context, mapsDirectionsUri(store.hospitalMapQuery)),
                    ),
                  ]),
                ),
              ),
              if (store.nextAppointment != null) _NextBanner(a: store.nextAppointment!),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name or specialty',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ['All', ...store.specialties]
                      .map((s) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: ChoiceChip(
                              label: Text(s),
                              selected: specialty == s,
                              onSelected: (_) => setState(() => specialty = s),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No doctors found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (_, i) => DoctorCard(doctor: list[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  const DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    String status;
    Color color;
    if (d.onLeave) {
      status = 'On leave';
      color = Colors.red;
    } else if (!d.days.contains(DateTime.now().weekday)) {
      status = 'Not available today';
      color = Colors.orange;
    } else {
      final n = store.freeSlotsToday(d);
      status = n > 0 ? 'Available today ($n slots)' : 'Fully booked today';
      color = n > 0 ? Colors.green : Colors.orange;
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctorId: d.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DoctorAvatar(specialty: d.specialty),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(d.specialty, style: TextStyle(color: specialtyColor(d.specialty), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${d.experience} yrs exp  •  ★ ${d.rating}  •  ₹${d.fee}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.circle, size: 10, color: color),
                      const SizedBox(width: 6),
                      Flexible(child: Text(status, style: TextStyle(color: color, fontSize: 12))),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(d.favorite ? Icons.favorite : Icons.favorite_border, color: d.favorite ? Colors.red : null),
                onPressed: () => store.toggleFavorite(d),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor detail + booking
// ---------------------------------------------------------------------------
class DoctorDetailScreen extends StatefulWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  DateTime? selected;

  @override
  void initState() {
    super.initState();
    _name.text = store.profileName;
    _phone.text = store.profilePhone;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _book(Doctor d) {
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date and time slot')));
      return;
    }
    if (!_form.currentState!.validate()) return;
    final appt = store.book(d, selected!, _name.text.trim(), _phone.text.trim(), _reason.text.trim());
    if (appt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sorry, that slot was just taken')));
      setState(() => selected = null);
      return;
    }
    store.saveProfileIfEmpty(_name.text.trim(), _phone.text.trim());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text('Appointment Booked', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${d.name}\n${fmtDate(appt.dateTime)} at ${fmtTime(appt.dateTime)}', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: appt.qrData, version: QrVersions.auto, size: 180),
              ),
              const SizedBox(height: 8),
              Text('Check-in code: ${appt.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Your token number: #${store.tokenFor(appt)}'),
              const Text('Show this QR at the hospital reception.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              const Text('🔔 The hospital has been alerted. You will get an alert here once they confirm or decline.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              TextButton.icon(
                onPressed: () => openUrl(context, mapsDirectionsUri(store.hospitalMapQuery)),
                icon: const Icon(Icons.directions),
                label: const Text('Directions to hospital'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = store.doctorById(widget.doctorId);
        if (d == null) return const Scaffold(body: Center(child: Text('Doctor not found')));
        return Scaffold(
          appBar: AppBar(title: Text(d.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                DoctorAvatar(specialty: d.specialty, radius: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(d.specialty),
                    Text('${d.experience} years experience  •  ★ ${d.rating}'),
                    Text('Consultation fee: ₹${d.fee}'),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Weekly availability', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final on = d.days.contains(i + 1);
                  return Chip(
                    label: Text(weekdayShort[i]),
                    backgroundColor: on ? Theme.of(context).colorScheme.primaryContainer : null,
                    side: on ? BorderSide.none : null,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text('Timings: ${fmtHour(d.startHour)} - ${fmtHour(d.endHour)}'
                  '${d.onLeave ? '   (Currently ON LEAVE)' : ''}'),
              const Divider(height: 32),
              if (d.onLeave)
                const Text('This doctor is currently on leave and cannot take bookings.')
              else ...[
                Text('Select date & time', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SlotPicker(doctor: d, onChanged: (t) => setState(() => selected = t)),
                const Divider(height: 32),
                Text('Patient details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Form(
                  key: _form,
                  child: Column(children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Patient name', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone number', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reason,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Reason for visit', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter reason' : null,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _book(d),
                  icon: const Icon(Icons.event_available),
                  label: Text(selected == null ? 'Book Appointment' : 'Book for ${fmtDate(selected!)}, ${fmtTime(selected!)}'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable date + slot picker (used for booking and rescheduling)
// ---------------------------------------------------------------------------
class SlotPicker extends StatefulWidget {
  final Doctor doctor;
  final String? excludeId;
  final ValueChanged<DateTime?> onChanged;
  const SlotPicker({super.key, required this.doctor, required this.onChanged, this.excludeId});

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  final today = dateOnly(DateTime.now());
  late DateTime day;
  DateTime? selected;

  @override
  void initState() {
    super.initState();
    day = today;
    for (var i = 0; i < 14; i++) {
      final c = today.add(Duration(days: i));
      if (store.worksOn(widget.doctor, c)) {
        day = c;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = List.generate(14, (i) => today.add(Duration(days: i)));
    final slots = store.slotsFor(widget.doctor, day, excludeId: widget.excludeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final dd = days[i];
              final works = store.worksOn(widget.doctor, dd);
              final sel = dd == day;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: works
                    ? () {
                        setState(() {
                          day = dd;
                          selected = null;
                        });
                        widget.onChanged(null);
                      }
                    : null,
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: sel ? scheme.primary : null,
                    border: Border.all(color: works ? scheme.primary : scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(weekdayShort[dd.weekday - 1],
                          style: TextStyle(fontSize: 12, color: sel ? scheme.onPrimary : (works ? null : scheme.outline))),
                      Text('${dd.day}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: sel ? scheme.onPrimary : (works ? null : scheme.outline))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(fmtDate(day), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          const Text('Doctor is not available on this day.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: slots.map((s) {
              return ChoiceChip(
                label: Text(fmtTime(s.time)),
                selected: selected == s.time,
                onSelected: s.available
                    ? (_) {
                        setState(() => selected = s.time);
                        widget.onChanged(s.time);
                      }
                    : null,
              );
            }).toList(),
          ),
        const SizedBox(height: 6),
        Text('Greyed-out slots are already booked or in the past.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}


class _NextBanner extends StatelessWidget {
  final Appointment a;
  const _NextBanner({required this.a});

  @override
  Widget build(BuildContext context) {
    final days = dateOnly(a.dateTime).difference(dateOnly(DateTime.now())).inDays;
    final when = days == 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days');
    final token = store.tokenFor(a);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.alarm),
        title: Text('Next appointment: $when at ${fmtTime(a.dateTime)}'),
        subtitle: Text('${a.doctorName}${token > 0 ? '  •  Token #$token' : ''}'),
      ),
    );
  }
}
