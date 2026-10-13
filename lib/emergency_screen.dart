import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'store.dart';
import 'links.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.emergency), text: 'Ambulance'),
            Tab(icon: Icon(Icons.bloodtype), text: 'Blood Bank'),
            Tab(icon: Icon(Icons.local_hospital), text: 'Hospital'),
          ]),
        ),
        body: const TabBarView(children: [
          _AmbulanceTab(),
          _BloodTab(),
          _HospitalTab(),
        ]),
      ),
    );
  }
}

// ===========================================================================
// AMBULANCE
// ===========================================================================
class _AmbulanceTab extends StatelessWidget {
  const _AmbulanceTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final reqs = [...store.ambulanceRequests]..sort((a, b) => b.time.compareTo(a.time));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Icon(Icons.emergency, size: 48, color: scheme.error),
                  const SizedBox(height: 8),
                  Text('Need an ambulance?', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter the pickup address and send the request to the hospital on WhatsApp.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const AmbulanceRequestScreen())),
                    icon: const Icon(Icons.local_hospital),
                    label: const Text('Request ambulance'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    actionChip(Icons.call, 'Call hospital', () => callNumber(context, store.hospitalPhone)),
                    actionChip(Icons.chat, 'WhatsApp hospital',
                        () => openWhatsApp(context, store.hospitalWhatsApp, 'Hello, I need an ambulance urgently.')),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${store.freeAmbulances.length} of ${store.ambulances.length} ambulances available right now',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Text('My ambulance requests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (reqs.isEmpty) const Text('No requests yet.'),
            ...reqs.map((r) => _AmbRequestCard(r: r)),
          ],
        );
      },
    );
  }
}

class _AmbRequestCard extends StatelessWidget {
  final AmbulanceRequest r;
  const _AmbRequestCard({required this.r});

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            statusChip(r.status.label, r.status.color),
          ]),
          const SizedBox(height: 4),
          Text('Patient: ${r.patientName}  •  ${r.phone}'),
          Text('Pickup: ${r.address}'),
          Text('${fmtDate(r.time)}, ${fmtTime(r.time)}  •  ID ${r.code}',
              style: Theme.of(context).textTheme.bodySmall),
          if (amb != null) ...[
            const SizedBox(height: 4),
            Text('Ambulance ${amb.vehicleNo} (${amb.type})  •  Driver ${amb.driverName}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            if (r.isActive)
              actionChip(Icons.chat, 'WhatsApp hospital',
                  () => openWhatsApp(context, store.hospitalWhatsApp, store.ambulanceMessage(r))),
            if (amb != null && r.isActive) ...[
              actionChip(Icons.call, 'Call driver', () => callNumber(context, amb.driverPhone)),
              actionChip(Icons.chat_bubble_outline, 'WhatsApp driver',
                  () => openWhatsApp(context, amb.driverPhone, store.ambulanceMessage(r))),
            ],
            actionChip(Icons.map, 'Pickup map', () => openUrl(context, mapsSearchUri(r.address))),
            if (r.status == AmbStatus.requested)
              actionChip(Icons.cancel_outlined, 'Cancel', () => store.setAmbStatus(r, AmbStatus.cancelled)),
          ]),
        ]),
      ),
    );
  }
}

class AmbulanceRequestScreen extends StatefulWidget {
  const AmbulanceRequestScreen({super.key});

  @override
  State<AmbulanceRequestScreen> createState() => _AmbulanceRequestScreenState();
}

class _AmbulanceRequestScreenState extends State<AmbulanceRequestScreen> {
  static const emergencies = ['Accident', 'Chest pain', 'Pregnancy', 'Breathing problem', 'Unconscious', 'Other'];
  static const types = ['Basic', 'ICU', 'Oxygen'];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.profileName);
  final _phone = TextEditingController(text: store.profilePhone);
  final _address = TextEditingController();
  String emergency = 'Accident';
  String type = 'Basic';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final r = store.requestAmbulance(name, phone, _address.text.trim(), emergency, type);
    store.saveProfileIfEmpty(name, phone);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 44),
        title: const Text('Request created'),
        content: Text('Request ID ${r.code}\n\n🔔 ${store.hospitalName} has been alerted instantly. You will get an alert here when an ambulance is assigned.\n\n'
            'For faster help, also send it on WhatsApp so the control room and the driver can see your pickup location.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          TextButton(onPressed: () => callNumber(context, store.hospitalPhone), child: const Text('Call')),
          FilledButton.icon(
            onPressed: () => openWhatsApp(context, store.hospitalWhatsApp, store.ambulanceMessage(r)),
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp hospital'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request ambulance')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Patient name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact phone', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Pickup address with landmark',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 5) ? 'Enter pickup address' : null,
            ),
            const SizedBox(height: 16),
            Text('Emergency type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: emergencies
                  .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: emergency == e,
                        onSelected: (_) => setState(() => emergency = e),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Ambulance type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: types
                  .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: type == e,
                        onSelected: (_) => setState(() => type = e),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// BLOOD BANK
// ===========================================================================
Color stockColor(int units) => units == 0 ? Colors.red : (units < 5 ? Colors.orange : Colors.green);

class _BloodTab extends StatefulWidget {
  const _BloodTab();

  @override
  State<_BloodTab> createState() => _BloodTabState();
}

class _BloodTabState extends State<_BloodTab> {
  String filter = 'All';
  bool compatible = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final donors = store.findDonors(filter, compatible);
        final reqs = [...store.bloodRequests]..sort((a, b) => b.time.compareTo(a.time));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Blood available in hospital', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: bloodGroups.map((g) {
                final n = store.stock(g);
                final c = stockColor(n);
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(g, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('$n units', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const BloodRequestScreen())),
                  icon: const Icon(Icons.bloodtype),
                  label: const Text('Request blood'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const DonorRegisterScreen())),
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Become a donor'),
                ),
              ),
            ]),
            const Divider(height: 28),
            Text('Find blood donors', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All', ...bloodGroups]
                    .map((g) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: filter == g,
                            onSelected: (_) => setState(() => filter = g),
                          ),
                        ))
                    .toList(),
              ),
            ),
            if (filter != 'All')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Include compatible groups for $filter'),
                subtitle: Text('Can receive from: ${(compatibleDonors[filter] ?? [filter]).join(', ')}'),
                value: compatible,
                onChanged: (v) => setState(() => compatible = v),
              ),
            if (donors.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No donors found.')),
            ...donors.map((d) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(d.group, style: const TextStyle(fontSize: 12))),
                    title: Text(d.name),
                    subtitle: Text('${d.city}  •  ${d.eligible ? 'Eligible to donate' : 'Donated recently'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Call',
                        icon: const Icon(Icons.call),
                        onPressed: () => callNumber(context, d.phone),
                      ),
                      IconButton(
                        tooltip: 'WhatsApp',
                        icon: const Icon(Icons.chat),
                        onPressed: () => openWhatsApp(
                            context,
                            d.phone,
                            'Hello ${d.name}, we urgently need ${filter == 'All' ? d.group : filter} blood. '
                            'Can you please help? - ${store.hospitalName}'),
                      ),
                    ]),
                  ),
                )),
            const Divider(height: 28),
            Text('My blood requests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (reqs.isEmpty) const Text('No requests yet.'),
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
                      Text('${fmtDate(r.time)}, ${fmtTime(r.time)}  •  ID ${r.code}',
                          style: Theme.of(context).textTheme.bodySmall),
                      if (r.status == BloodStatus.pending)
                        Wrap(spacing: 6, children: [
                          actionChip(Icons.chat, 'WhatsApp hospital',
                              () => openWhatsApp(context, store.hospitalWhatsApp, store.bloodMessage(r))),
                          actionChip(Icons.share, 'Share request',
                              () => shareOnWhatsApp(context, store.bloodMessage(r))),
                          actionChip(Icons.cancel_outlined, 'Cancel',
                              () => store.setBloodStatus(r, BloodStatus.cancelled)),
                        ]),
                    ]),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({super.key});

  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.profileName);
  final _contact = TextEditingController(text: store.profilePhone);
  final _note = TextEditingController();
  String group = 'O+';
  String urgency = 'Urgent';
  int units = 1;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final r = store.requestBlood(
        _name.text.trim(), _contact.text.trim(), group, units, urgency, _note.text.trim());
    final have = store.stock(group);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 44),
        title: const Text('Blood request created'),
        content: Text('🔔 ${store.hospitalName} has been alerted.\n\n' +
            (have >= units
            ? 'Request ID ${r.code}\n\nGood news: $have unit(s) of $group are in the hospital blood bank. '
                'Send the request on WhatsApp so the staff can keep it ready.'
            : 'Request ID ${r.code}\n\nOnly $have unit(s) of $group are in stock right now. Send the request '
                'on WhatsApp and also contact donors from the Blood Bank tab.')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () => shareOnWhatsApp(context, store.bloodMessage(r)),
            child: const Text('Share'),
          ),
          FilledButton.icon(
            onPressed: () => openWhatsApp(context, store.hospitalWhatsApp, store.bloodMessage(r)),
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp hospital'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request blood')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Patient name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact phone', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null,
            ),
            const SizedBox(height: 16),
            Text('Blood group needed', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: bloodGroups
                  .map((g) => ChoiceChip(
                        label: Text(g),
                        selected: group == g,
                        onSelected: (_) => setState(() => group = g),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text('In stock now: ${store.stock(group)} unit(s)',
                style: TextStyle(color: stockColor(store.stock(group)), fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(children: [
              Text('Units needed', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                onPressed: units > 1 ? () => setState(() => units--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$units', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: units < 10 ? () => setState(() => units++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Urgency', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Normal', 'Urgent', 'Critical']
                  .map((u) => ChoiceChip(
                        label: Text(u),
                        selected: urgency == u,
                        onSelected: (_) => setState(() => urgency = u),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (ward / doctor / reason) - optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}

class DonorRegisterScreen extends StatefulWidget {
  const DonorRegisterScreen({super.key});

  @override
  State<DonorRegisterScreen> createState() => _DonorRegisterScreenState();
}

class _DonorRegisterScreenState extends State<DonorRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.profileName);
  final _phone = TextEditingController(text: store.profilePhone);
  final _city = TextEditingController();
  String group = 'O+';
  DateTime? last;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: last ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d != null) setState(() => last = d);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    store.addDonor(Donor(
      id: newId(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      group: group,
      city: _city.text.trim(),
      lastDonated: last,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! You are now a registered blood donor.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a blood donor')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City / area', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter city' : null,
            ),
            const SizedBox(height: 16),
            Text('Blood group', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: bloodGroups
                  .map((g) => ChoiceChip(
                        label: Text(g),
                        selected: group == g,
                        onSelected: (_) => setState(() => group = g),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(last == null ? 'Last donated (optional)' : 'Last donated: ${fmtDate(last!)}'),
            ),
            const SizedBox(height: 8),
            const Text('By registering you agree that people who need blood can contact you by call or WhatsApp.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Register as donor'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// HOSPITAL: Google Maps + contact + QR
// ===========================================================================
class _HospitalTab extends StatelessWidget {
  const _HospitalTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_hospital, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(store.hospitalName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(store.hospitalAddress),
                Text('Phone: ${store.hospitalPhone}'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  actionChip(Icons.directions, 'Directions',
                      () => openUrl(context, mapsDirectionsUri(store.hospitalMapQuery))),
                  actionChip(Icons.map, 'Open in Maps',
                      () => openUrl(context, mapsSearchUri(store.hospitalMapQuery))),
                  actionChip(Icons.call, 'Call', () => callNumber(context, store.hospitalPhone)),
                  actionChip(Icons.chat, 'WhatsApp',
                      () => openWhatsApp(context, store.hospitalWhatsApp, 'Hello ${store.hospitalName}, ')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text('Find nearby (uses your location in Google Maps)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            actionChip(Icons.local_pharmacy, 'Pharmacies', () => openUrl(context, mapsSearchUri('pharmacy near me'))),
            actionChip(Icons.local_hospital, 'Hospitals', () => openUrl(context, mapsSearchUri('hospital near me'))),
            actionChip(Icons.bloodtype, 'Blood banks', () => openUrl(context, mapsSearchUri('blood bank near me'))),
            actionChip(Icons.science, 'Diagnostic labs', () => openUrl(context, mapsSearchUri('diagnostic lab near me'))),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('Scan to open hospital location', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: store.hospitalMapLink, version: QrVersions.auto, size: 180),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan with any phone camera to open this hospital in Google Maps. '
                  'Print it for the reception desk, appointment slips and hospital boards.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
