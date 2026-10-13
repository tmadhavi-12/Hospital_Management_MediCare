import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'store.dart';
import 'links.dart';
import 'doctors_screen.dart';
import 'notifications_screen.dart';
import 'ui.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final upcoming = store.appointments.where((a) => a.isUpcoming).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        final history = store.appointments.where((a) => !a.isUpcoming).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My Appointments'),
              actions: const [AlertBell()],
              bottom: TabBar(tabs: [
                Tab(text: 'Upcoming (${upcoming.length})'),
                Tab(text: 'History (${history.length})'),
              ]),
            ),
            body: TabBarView(children: [
              _list(upcoming, 'No upcoming appointments.\nBook one from the Doctors tab.', true),
              _list(history, 'No past appointments yet.', false),
            ]),
          ),
        );
      },
    );
  }

  Widget _list(List<Appointment> items, String empty, bool actions) {
    if (items.isEmpty) {
      return Center(child: Text(empty, textAlign: TextAlign.center));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => AppointmentCard(appt: items[i], showActions: actions),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Appointment appt;
  final bool showActions;
  const AppointmentCard({super.key, required this.appt, this.showActions = true});

  void _reschedule(BuildContext context) {
    final doctor = store.doctorById(appt.doctorId);
    if (doctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This doctor is no longer available')));
      return;
    }
    DateTime? picked;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reschedule with ${doctor.name}', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              SlotPicker(doctor: doctor, excludeId: appt.id, onChanged: (t) => picked = t),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (picked == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a new slot first')));
                      return;
                    }
                    final ok = store.reschedule(appt, picked!);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Appointment rescheduled' : 'That slot is no longer free')));
                  },
                  child: const Text('Confirm new time'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQr(BuildContext context) {
    final token = store.tokenFor(appt);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Appointment QR', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: appt.qrData, version: QrVersions.auto, size: 200),
              ),
              const SizedBox(height: 10),
              Text('Check-in code: ${appt.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (token > 0) Text('Token number: #$token'),
              const SizedBox(height: 4),
              Text('${appt.patientName}\n${appt.doctorName}\n${fmtDate(appt.dateTime)} at ${fmtTime(appt.dateTime)}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Show this at the reception. Staff enter the code (or scan the QR) to check you in.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ]),
          ),
        ),
      ),
    );
  }

  void _showPrescription(BuildContext context) {
    Widget section(String title, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(text),
            ]),
          );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prescription'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${appt.doctorName}\n${fmtDate(appt.dateTime)}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            section('Diagnosis', appt.diagnosis),
            section('Medicines', appt.prescription),
            section('Advice', appt.advice),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: 'PRESCRIPTION - ${appt.doctorName}\n${fmtDate(appt.dateTime)}\n\n'
                      'Diagnosis: ${appt.diagnosis}\nMedicines: ${appt.prescription}\nAdvice: ${appt.advice}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription copied')));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _rate(BuildContext context) {
    var stars = 5;
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Rate ${appt.doctorName}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  onPressed: () => setS(() => stars = i + 1),
                ),
              ),
            ),
            TextField(
              controller: c,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Review (optional)', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            FilledButton(
              onPressed: () {
                store.rate(appt, stars, c.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text('${appt.doctorName}\n${fmtDate(appt.dateTime)} at ${fmtTime(appt.dateTime)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep')),
          FilledButton(
            onPressed: () {
              store.cancel(appt);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = store.tokenFor(appt);
    final cancelled = appt.status.isDead;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(appt.doctorName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              statusChip(appt.status.label, appt.status.color),
            ]),
            Text(appt.specialty),
            if (store.hospitalById(appt.hospitalId) != null)
              Text(store.hospitalById(appt.hospitalId)!.name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.event, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('${fmtDate(appt.dateTime)}  •  ${fmtTime(appt.dateTime)}')),
              if (token > 0) Text('Token #$token', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('${appt.patientName}  •  ${appt.phone}')),
            ]),
            const SizedBox(height: 4),
            Text('Reason: ${appt.reason}', style: Theme.of(context).textTheme.bodySmall),
            if (appt.status == ApptStatus.declined)
              Text('Declined by hospital${appt.declineReason.isEmpty ? '' : ': ${appt.declineReason}'}',
                  style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
            if (appt.status == ApptStatus.pending)
              const Text('Waiting for the hospital to confirm', style: TextStyle(color: Colors.orange, fontSize: 12)),
            if (appt.rating != null)
              Row(children: [
                ...List.generate(
                    5, (i) => Icon(i < appt.rating! ? Icons.star : Icons.star_border, color: Colors.amber, size: 18)),
                if (appt.review.isNotEmpty) Expanded(child: Text('  ${appt.review}', overflow: TextOverflow.ellipsis)),
              ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 0, children: [
              if (!cancelled) actionChip(Icons.qr_code_2, 'QR', () => _showQr(context)),
              if (!cancelled)
                actionChip(Icons.share, 'Share slip', () => shareOnWhatsApp(context, store.slipText(appt))),
              if (!cancelled)
                actionChip(Icons.copy, 'Copy slip', () {
                  Clipboard.setData(ClipboardData(text: store.slipText(appt)));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slip copied')));
                }),
              if (!cancelled)
                actionChip(Icons.directions, 'Directions',
                    () => openUrl(context, mapsDirectionsUri(store.mapQueryFor(appt.hospitalId)))),
              if (appt.hasPrescription)
                actionChip(Icons.medication, 'Prescription', () => _showPrescription(context)),
              if (appt.status == ApptStatus.completed && appt.rating == null)
                actionChip(Icons.star_rate, 'Rate doctor', () => _rate(context)),
              if (showActions && appt.isUpcoming) ...[
                actionChip(Icons.schedule, 'Reschedule', () => _reschedule(context)),
                actionChip(Icons.cancel_outlined, 'Cancel', () => _cancel(context)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
