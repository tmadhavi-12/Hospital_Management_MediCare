import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models.dart';
import 'store.dart';
import 'doctors_screen.dart';
import 'emergency_screen.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Health Tools'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Symptom checker'),
            Tab(text: 'Health card QR'),
            Tab(text: 'BMI'),
            Tab(text: 'Tips'),
          ]),
        ),
        body: const TabBarView(children: [
          _SymptomChecker(),
          _HealthCard(),
          _BmiCalculator(),
          _Tips(),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Symptom checker: symptoms -> suggested specialty
// ===========================================================================
const Map<String, Map<String, int>> _symptoms = {
  'Chest pain': {'Cardiologist': 3},
  'Palpitations': {'Cardiologist': 3},
  'Breathlessness': {'Cardiologist': 2, 'General Physician': 1},
  'Skin rash': {'Dermatologist': 3},
  'Itching': {'Dermatologist': 3},
  'Hair fall': {'Dermatologist': 2},
  'Fever': {'General Physician': 3},
  'Cough / cold': {'General Physician': 3},
  'Fatigue': {'General Physician': 2},
  'Stomach pain': {'General Physician': 2},
  'Joint pain': {'Orthopedic': 3},
  'Back pain': {'Orthopedic': 3},
  'Injury / fracture': {'Orthopedic': 3},
  'Headache': {'Neurologist': 2, 'General Physician': 1},
  'Dizziness': {'Neurologist': 2, 'General Physician': 1},
  'Numbness / weakness': {'Neurologist': 3},
  'Seizures': {'Neurologist': 3},
  'Child has fever': {'Pediatrician': 3},
  'Child has cough': {'Pediatrician': 3},
  'Child not eating': {'Pediatrician': 2},
};

const Set<String> _redFlags = {'Chest pain', 'Breathlessness', 'Numbness / weakness', 'Seizures'};

class _SymptomChecker extends StatefulWidget {
  const _SymptomChecker();

  @override
  State<_SymptomChecker> createState() => _SymptomCheckerState();
}

class _SymptomCheckerState extends State<_SymptomChecker> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    final scores = <String, int>{};
    for (final s in selected) {
      _symptoms[s]!.forEach((spec, w) => scores[spec] = (scores[spec] ?? 0) + w);
    }
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final urgent = selected.any(_redFlags.contains);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('What are you feeling?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Select one or more symptoms and we will suggest the right specialist.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _symptoms.keys
              .map((s) => FilterChip(
                    label: Text(s),
                    selected: selected.contains(s),
                    onSelected: (v) => setState(() => v ? selected.add(s) : selected.remove(s)),
                  ))
              .toList(),
        ),
        if (urgent) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.warning_amber, color: scheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('These symptoms can be serious',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text('If the problem is severe or sudden, do not wait for an appointment. '
                    'Call 108 or request an ambulance now.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AmbulanceRequestScreen())),
                  icon: const Icon(Icons.emergency),
                  label: const Text('Request ambulance'),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (selected.isEmpty)
          const Text('Your suggestions will appear here.')
        else ...[
          Text('Suggested specialists', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...ranked.take(3).map((e) {
            final count = store.doctors.where((d) => d.specialty == e.key).length;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.medical_services)),
                title: Text(e.key),
                subtitle: Text(count == 0 ? 'No doctor available now' : '$count doctor(s) available'),
                trailing: FilledButton.tonal(
                  onPressed: count == 0
                      ? null
                      : () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SpecialtyDoctorsScreen(specialty: e.key))),
                  child: const Text('View'),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 12),
        const Text(
          'This is only a guide to help you choose a doctor. It is not a medical diagnosis.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class SpecialtyDoctorsScreen extends StatelessWidget {
  final String specialty;
  const SpecialtyDoctorsScreen({super.key, required this.specialty});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(specialty)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.doctors.where((d) => d.specialty == specialty).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: list.map((d) => DoctorCard(doctor: d)).toList(),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Emergency health card with QR
// ===========================================================================
class _HealthCard extends StatefulWidget {
  const _HealthCard();

  @override
  State<_HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<_HealthCard> {
  final _name = TextEditingController(text: store.profileName);
  final _phone = TextEditingController(text: store.profilePhone);
  final _age = TextEditingController(text: store.cardAge);
  final _allergies = TextEditingController(text: store.cardAllergies);
  final _conditions = TextEditingController(text: store.cardConditions);
  final _cName = TextEditingController(text: store.cardContactName);
  final _cPhone = TextEditingController(text: store.cardContactPhone);
  String group = store.cardBloodGroup;

  @override
  void dispose() {
    for (final c in [_name, _phone, _age, _allergies, _conditions, _cName, _cPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    store.setHealthCard(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      age: _age.text.trim(),
      group: group,
      allergies: _allergies.text.trim(),
      conditions: _conditions.text.trim(),
      contactName: _cName.text.trim(),
      contactPhone: _cPhone.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health card saved')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('My emergency health card', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'In an accident, anyone can scan this QR with a normal phone camera and see your blood group, '
          'allergies and who to call. It also auto-fills your booking, ambulance and blood forms.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _age,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        TextField(
          controller: _allergies,
          decoration: const InputDecoration(labelText: 'Allergies (e.g. Penicillin)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _conditions,
          decoration: const InputDecoration(
              labelText: 'Medical conditions (e.g. Diabetes, BP)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cName,
          decoration: const InputDecoration(labelText: 'Emergency contact name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Emergency contact phone', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save health card')),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: store,
          builder: (context, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('Scan to read my health card', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: store.healthCardText, version: QrVersions.auto, size: 200),
                ),
                const SizedBox(height: 10),
                Text(store.healthCardText, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: store.healthCardText));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy as text'),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// BMI
// ===========================================================================
class _BmiCalculator extends StatefulWidget {
  const _BmiCalculator();

  @override
  State<_BmiCalculator> createState() => _BmiCalculatorState();
}

class _BmiCalculatorState extends State<_BmiCalculator> {
  final _h = TextEditingController();
  final _w = TextEditingController();
  double? bmi;

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  void _calc() {
    final h = double.tryParse(_h.text);
    final w = double.tryParse(_w.text);
    if (h == null || w == null || h <= 0 || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid height and weight')));
      return;
    }
    setState(() => bmi = w / ((h / 100) * (h / 100)));
  }

  @override
  Widget build(BuildContext context) {
    String label = '';
    Color color = Colors.green;
    if (bmi != null) {
      if (bmi! < 18.5) {
        label = 'Underweight';
        color = Colors.blue;
      } else if (bmi! < 25) {
        label = 'Normal weight';
        color = Colors.green;
      } else if (bmi! < 30) {
        label = 'Overweight';
        color = Colors.orange;
      } else {
        label = 'Obese';
        color = Colors.red;
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _h,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _w,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calc, child: const Text('Calculate BMI')),
        const SizedBox(height: 20),
        if (bmi != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(bmi!.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Healthy range: 18.5 - 24.9', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Tips
// ===========================================================================
class _Tips extends StatelessWidget {
  const _Tips();

  static const tips = [
    (Icons.water_drop, 'Drink 2-3 litres of water every day.'),
    (Icons.directions_walk, 'Walk for at least 30 minutes daily.'),
    (Icons.bedtime, 'Sleep 7-8 hours; keep a fixed sleep time.'),
    (Icons.restaurant, 'Eat more vegetables, fruits and less fried food.'),
    (Icons.smoke_free, 'Avoid tobacco and limit alcohol.'),
    (Icons.self_improvement, 'Take short breaks and breathe deeply to reduce stress.'),
    (Icons.health_and_safety, 'Get a full health check-up once a year after age 30.'),
    (Icons.volunteer_activism, 'Donate blood every 3 months if you are healthy - it saves lives.'),
  ];

  @override
  Widget build(BuildContext context) {
    final today = tips[DateTime.now().difference(DateTime(DateTime.now().year)).inDays % tips.length];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: Icon(today.$1, size: 32),
            title: const Text('Tip of the day'),
            subtitle: Text(today.$2),
          ),
        ),
        const SizedBox(height: 8),
        ...tips.map((t) => Card(child: ListTile(leading: Icon(t.$1), title: Text(t.$2)))),
      ],
    );
  }
}
