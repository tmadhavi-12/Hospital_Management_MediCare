import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'links.dart';
import 'emergency_screen.dart' show stockColor;

// ===========================================================================
// ADMIN: AMBULANCE
// ===========================================================================
class AdminAmbulanceTab extends StatelessWidget {
  const AdminAmbulanceTab({super.key});

  Future<void> _ambulanceDialog(BuildContext context, {Ambulance? existing}) async {
    final result = await showDialog<Ambulance>(
      context: context,
      builder: (_) => _AmbulanceDialog(ambulance: existing),
    );
    if (result == null) return;
    if (existing == null) {
      store.addAmbulance(result);
    } else {
      store.updateAmbulance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqs = [...store.ambulanceRequests]
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.time.compareTo(a.time);
      });
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Ambulance requests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (reqs.isEmpty) const Text('No ambulance requests yet.'),
        ...reqs.map((r) => _AdminAmbRequestCard(r: r)),
        const Divider(height: 28),
        Row(children: [
          Expanded(child: Text('Ambulance fleet', style: Theme.of(context).textTheme.titleMedium)),
          FilledButton.tonalIcon(
            onPressed: () => _ambulanceDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ]),
        const SizedBox(height: 6),
        ...store.ambulances.map((a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a.vehicleNo}  •  ${a.type}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Driver: ${a.driverName}  •  ${a.driverPhone}'),
                  Row(children: [
                    Switch(value: a.available, onChanged: (_) => store.toggleAmbulance(a)),
                    Text(a.available ? 'Available' : 'On duty / unavailable'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.call),
                      onPressed: () => callNumber(context, a.driverPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _ambulanceDialog(context, existing: a),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => store.deleteAmbulance(a),
                    ),
                  ]),
                ]),
              ),
            )),
      ],
    );
  }
}

class _AdminAmbRequestCard extends StatelessWidget {
  final AmbulanceRequest r;
  const _AdminAmbRequestCard({required this.r});

  void _assign(BuildContext context) {
    final free = store.freeAmbulances;
    if (free.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ambulance is free. Mark one as available in the fleet list.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Assign ambulance'),
        children: free
            .map((a) => SimpleDialogOption(
                  onPressed: () {
                    store.assignAmbulance(r, a);
                    Navigator.pop(ctx);
                  },
                  child: Text('${a.vehicleNo} (${a.type}) - ${a.driverName}'),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amb = store.ambulanceById(r.ambulanceId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${r.emergency}  •  ${r.ambulanceType}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            statusChip(r.status.label, r.status.color),
          ]),
          Text('Patient: ${r.patientName}  •  ${r.phone}'),
          Text('Pickup: ${r.address}'),
          Text('${fmtDate(r.time)}, ${fmtTime(r.time)}  •  ID ${r.code}',
              style: Theme.of(context).textTheme.bodySmall),
          if (amb != null)
            Text('Assigned: ${amb.vehicleNo} - ${amb.driverName} (${amb.driverPhone})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          if (r.isActive) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 2, children: [
              actionChip(Icons.local_shipping, amb == null ? 'Assign ambulance' : 'Reassign', () => _assign(context)),
              if (amb != null)
                actionChip(Icons.send, 'Send duty to driver',
                    () => openWhatsApp(context, amb.driverPhone, store.driverMessage(r))),
              if (amb != null)
                actionChip(Icons.call, 'Call driver', () => callNumber(context, amb.driverPhone)),
              actionChip(Icons.call, 'Call patient', () => callNumber(context, r.phone)),
              actionChip(
                Icons.chat,
                'Update patient',
                () => openWhatsApp(
                  context,
                  r.phone,
                  amb == null
                      ? 'Your ambulance request (${r.code}) is received. We are arranging a vehicle. - ${store.hospitalName}'
                      : 'Ambulance ${amb.vehicleNo} (driver ${amb.driverName}, ${amb.driverPhone}) is on the way. - ${store.hospitalName}',
                ),
              ),
              actionChip(Icons.map, 'Pickup map', () => openUrl(context, mapsDirectionsUri(r.address))),
              actionChip(Icons.check_circle, 'Completed', () => store.setAmbStatus(r, AmbStatus.completed)),
              actionChip(Icons.cancel, 'Cancel', () => store.setAmbStatus(r, AmbStatus.cancelled)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _AmbulanceDialog extends StatefulWidget {
  final Ambulance? ambulance;
  const _AmbulanceDialog({this.ambulance});

  @override
  State<_AmbulanceDialog> createState() => _AmbulanceDialogState();
}

class _AmbulanceDialogState extends State<_AmbulanceDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController vehicle, driver, phone;
  late String type;

  @override
  void initState() {
    super.initState();
    final a = widget.ambulance;
    vehicle = TextEditingController(text: a?.vehicleNo ?? '');
    driver = TextEditingController(text: a?.driverName ?? '');
    phone = TextEditingController(text: a?.driverPhone ?? '');
    type = a?.type ?? 'Basic';
  }

  @override
  void dispose() {
    vehicle.dispose();
    driver.dispose();
    phone.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ambulance == null ? 'Add ambulance' : 'Edit ambulance'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: vehicle, decoration: const InputDecoration(labelText: 'Vehicle number'), validator: _req),
            TextFormField(controller: driver, decoration: const InputDecoration(labelText: 'Driver name'), validator: _req),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Driver phone / WhatsApp'),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone' : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: ['Basic', 'ICU', 'Oxygen']
                  .map((t) => ChoiceChip(label: Text(t), selected: type == t, onSelected: (_) => setState(() => type = t)))
                  .toList(),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final a = widget.ambulance ??
                Ambulance(id: newId(), vehicleNo: '', driverName: '', driverPhone: '');
            a.vehicleNo = vehicle.text.trim();
            a.driverName = driver.text.trim();
            a.driverPhone = phone.text.trim();
            a.type = type;
            Navigator.pop(context, a);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ===========================================================================
// ADMIN: BLOOD BANK
// ===========================================================================
class AdminBloodTab extends StatelessWidget {
  const AdminBloodTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reqs = [...store.bloodRequests]
      ..sort((a, b) {
        final ap = a.status == BloodStatus.pending;
        final bp = b.status == BloodStatus.pending;
        if (ap != bp) return ap ? -1 : 1;
        return b.time.compareTo(a.time);
      });
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Blood stock (units)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: bloodGroups.map((g) {
            final n = store.stock(g);
            final c = stockColor(n);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: c, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Text(g, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => store.adjustStock(g, -1),
                ),
                SizedBox(
                  width: 28,
                  child: Text('$n', textAlign: TextAlign.center, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => store.adjustStock(g, 1),
                ),
              ]),
            );
          }).toList(),
        ),
        const Divider(height: 28),
        Text('Blood requests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (reqs.isEmpty) const Text('No blood requests yet.'),
        ...reqs.map((r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${r.group}  •  ${r.units} unit(s)  •  ${r.urgency}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    statusChip(r.status.label, r.status.color),
                  ]),
                  Text('Patient: ${r.patientName}  •  ${r.contact}'),
                  if (r.note.isNotEmpty) Text('Note: ${r.note}'),
                  Text('In stock: ${store.stock(r.group)} unit(s)  •  ID ${r.code}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (r.status == BloodStatus.pending)
                    Wrap(spacing: 6, children: [
                      actionChip(Icons.check_circle, 'Fulfil from stock', () {
                        final ok = store.fulfillBlood(r);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not enough stock for this request')));
                        }
                      }),
                      actionChip(Icons.call, 'Call', () => callNumber(context, r.contact)),
                      actionChip(
                        Icons.chat,
                        'WhatsApp',
                        () => openWhatsApp(context, r.contact,
                            'Your blood request (${r.code}) for ${r.group} is being processed. - ${store.hospitalName}'),
                      ),
                      actionChip(Icons.cancel, 'Cancel', () => store.setBloodStatus(r, BloodStatus.cancelled)),
                    ]),
                ]),
              ),
            )),
        const Divider(height: 28),
        Text('Registered donors (${store.donors.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        ...store.donors.map((d) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(d.group, style: const TextStyle(fontSize: 12))),
                title: Text(d.name),
                subtitle: Text('${d.city}  •  ${d.phone}  •  ${d.eligible ? 'Eligible' : 'Not eligible yet'}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.call), onPressed: () => callNumber(context, d.phone)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => store.deleteDonor(d),
                  ),
                ]),
              ),
            )),
      ],
    );
  }
}

// ===========================================================================
// ADMIN: HOSPITAL CONTACT SETTINGS
// ===========================================================================
class AdminHospitalTab extends StatefulWidget {
  const AdminHospitalTab({super.key});

  @override
  State<AdminHospitalTab> createState() => _AdminHospitalTabState();
}

class _AdminHospitalTabState extends State<AdminHospitalTab> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.hospitalName);
  final _address = TextEditingController(text: store.hospitalAddress);
  final _phone = TextEditingController(text: store.hospitalPhone);
  final _wa = TextEditingController(text: store.hospitalWhatsApp);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _wa.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hospital contact settings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'These details are used for ambulance / blood requests (WhatsApp + call), Google Maps '
            'directions and the location QR code. Use your real hospital name and address so Google Maps finds it.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Hospital name', border: OutlineInputBorder()),
            validator: _req,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address (with city)', border: OutlineInputBorder()),
            validator: _req,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number (for calls)', border: OutlineInputBorder()),
            validator: _req,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wa,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Management WhatsApp number',
              helperText: 'With country code, e.g. 919876543210',
              border: OutlineInputBorder(),
            ),
            validator: _req,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              store.setHospital(
                name: _name.text.trim(),
                address: _address.text.trim(),
                phone: _phone.text.trim(),
                whatsapp: _wa.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hospital details saved')));
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const Divider(height: 36),
          Text('Management login', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Login ID: ${store.activeHospital.loginId}  (created by the admin, cannot be changed here)',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _changePassword(context),
            icon: const Icon(Icons.password),
            label: const Text('Change password'),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change password'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: oldC, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            TextField(
              controller: newC,
              obscureText: true,
              decoration: InputDecoration(labelText: 'New password (min 6 characters)', errorText: error),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final err = store.changeHospitalPassword(oldC.text, newC.text);
                if (err != null) {
                  setS(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }
}
