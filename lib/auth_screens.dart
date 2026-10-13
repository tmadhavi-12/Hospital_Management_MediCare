import 'package:flutter/material.dart';
import 'store.dart';
import 'ui.dart';

// ===========================================================================
// LOGIN SCREEN  (Patient login / register  +  Admin login)
// ===========================================================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // ---- hero banner ----
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
                  decoration: BoxDecoration(
                    gradient: brandGradient(),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: const Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.local_hospital, size: 38, color: kBrand),
                      ),
                      SizedBox(height: 14),
                      Text('MediCare Connect',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Book doctors  •  Emergency help  •  Hospital management',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const TabBar(tabs: [
                  Tab(icon: Icon(Icons.person), text: 'Patient'),
                  Tab(icon: Icon(Icons.local_hospital), text: 'Hospital'),
                  Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admin'),
                ]),
                const Expanded(
                  child: TabBarView(children: [
                    _PatientAuth(),
                    _HospitalAuth(),
                    _AdminAuth(),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientAuth extends StatefulWidget {
  const _PatientAuth();

  @override
  State<_PatientAuth> createState() => _PatientAuthState();
}

class _PatientAuthState extends State<_PatientAuth> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool register = false;
  bool hide = true;
  String? error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final err = register
        ? store.register(_name.text, _phone.text, _pass.text)
        : store.loginUser(_phone.text, _pass.text);
    // On success the AuthGate in main.dart switches screens automatically.
    if (err != null) setState(() => error = err);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(register ? 'Create patient account' : 'Patient login', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (register) ...[
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
              validator: (v) => (v == null || v.replaceAll(RegExp(r'[^0-9]'), '').length < 10) ? 'Enter a valid 10-digit phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: hide,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hide = !hide),
                ),
              ),
              validator: (v) => (v == null || v.length < 4) ? 'At least 4 characters' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: Text(register ? 'Register' : 'Login')),
            TextButton(
              onPressed: () => setState(() {
                register = !register;
                error = null;
              }),
              child: Text(register ? 'Already have an account? Login' : 'New patient? Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalAuth extends StatefulWidget {
  const _HospitalAuth();

  @override
  State<_HospitalAuth> createState() => _HospitalAuthState();
}

class _HospitalAuthState extends State<_HospitalAuth> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool hide = true;
  String? error;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    final err = store.loginHospital(_id.text, _pass.text);
    if (err != null) setState(() => error = err);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hospital management login', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Each hospital has its own login, given by the admin. Only hospital staff can confirm or decline appointments.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Hospital login ID',
              helperText: 'Demo: citycare, sunrise or lifeline',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Demo password: hospital123',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.login), label: const Text('Login to hospital')),
        ],
      ),
    );
  }
}

class _AdminAuth extends StatefulWidget {
  const _AdminAuth();

  @override
  State<_AdminAuth> createState() => _AdminAuthState();
}

class _AdminAuthState extends State<_AdminAuth> {
  final _pin = TextEditingController();
  String? error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!store.loginAdmin(_pin.text)) setState(() => error = 'Wrong PIN');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Admin login', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('The admin only adds hospitals and creates their logins. Admin cannot see appointments or patients.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Admin PIN (default: 1234)',
              prefixIcon: const Icon(Icons.pin),
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Login as Admin')),
        ],
      ),
    );
  }
}

// ===========================================================================
// HOSPITAL SELECTION (shown after patient login, and from "change hospital")
// ===========================================================================
class HospitalSelectScreen extends StatefulWidget {
  const HospitalSelectScreen({super.key});

  @override
  State<HospitalSelectScreen> createState() => _HospitalSelectScreenState();
}

class _HospitalSelectScreenState extends State<HospitalSelectScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.hospitals
            .where((h) =>
                h.name.toLowerCase().contains(query.toLowerCase()) ||
                h.address.toLowerCase().contains(query.toLowerCase()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: canGoBack,
            title: const Text('Select Hospital'),
            actions: [
              if (!canGoBack)
                IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: store.logout),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  store.currentUser == null ? 'Choose a hospital' : 'Hi ${store.profileName}, choose a hospital to see its doctors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search hospital or city',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No hospitals found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final h = list[i];
                          final selected = h.id == store.activeHospitalId;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: selected ? kBrand : Colors.black12, width: selected ? 2 : 1),
                            ),
                            child: InkWell(
                              onTap: () {
                                store.selectHospital(h.id);
                                if (canGoBack) Navigator.of(context).pop();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(gradient: brandGradient(), borderRadius: BorderRadius.circular(16)),
                                    child: const Icon(Icons.local_hospital, color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(h.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.place, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(h.address, style: Theme.of(context).textTheme.bodySmall)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Wrap(spacing: 6, children: [
                                        Pill('${store.doctorCount(h.id)} doctors', kBrand, icon: Icons.medical_services),
                                        Pill('24x7 Emergency', Colors.red, icon: Icons.emergency),
                                      ]),
                                    ]),
                                  ),
                                  Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? Colors.green : Colors.grey),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
