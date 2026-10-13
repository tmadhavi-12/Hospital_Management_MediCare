import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'ui.dart';
import 'settings_screen.dart';

/// SUPER ADMIN: can ONLY add hospitals and manage their logins.
/// It has no access to doctors, appointments, patients, ambulances or blood banks - those belong to each hospital.
class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  Future<void> _addHospital(BuildContext context) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final wa = TextEditingController();
    final loginId = TextEditingController();
    final pass = TextEditingController();
    String? error;
    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add hospital'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Hospital name'), validator: req),
                  TextFormField(controller: address, decoration: const InputDecoration(labelText: 'Address (with city)'), validator: req),
                  TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'), validator: req),
                  TextFormField(
                      controller: wa,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'WhatsApp (with country code)'),
                      validator: req),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Hospital management login', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextFormField(controller: loginId, autocorrect: false, decoration: const InputDecoration(labelText: 'Login ID (e.g. apollo01)'), validator: req),
                  TextFormField(controller: pass, decoration: const InputDecoration(labelText: 'Password (min 6 characters)'), validator: req),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                    ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final err = store.addHospital(
                  name: name.text.trim(),
                  address: address.text.trim(),
                  phone: phone.text.trim(),
                  whatsapp: wa.text.trim(),
                  loginId: loginId.text,
                  password: pass.text,
                );
                if (err != null) {
                  setS(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hospital added. Give the login ID and password to the hospital: ${loginId.text.trim().toLowerCase()}')));
              },
              child: const Text('Add hospital'),
            ),
          ],
        ),
      ),
    );
    for (final c in [name, address, phone, wa, loginId, pass]) {
      c.dispose();
    }
  }

  Future<void> _resetPassword(BuildContext context, Hospital h) async {
    final c = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('New password for ${h.name}'),
          content: TextField(
            controller: c,
            decoration: InputDecoration(labelText: 'New password (min 6 characters)', errorText: error),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final err = store.resetHospitalPassword(h, c.text);
                if (err != null) {
                  setS(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = [...store.hospitals]..sort((a, b) => a.name.compareTo(b.name));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin  •  Hospitals'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: store.logout),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addHospital(context),
            icon: const Icon(Icons.add_business),
            label: const Text('Add hospital'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  GradientHeader(
                    child: Row(children: [
                      const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.apartment, size: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Hospital network', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('${list.length} hospitals registered', style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Admin adds hospitals and creates their login. Each hospital then manages its own doctors, '
                            'appointments (confirm / decline), ambulances and blood bank. The admin has no access to that data.',
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SectionTitle('Registered hospitals'),
                  ...list.map((h) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(gradient: brandGradient(), borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.local_hospital, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(h.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  Text(h.address, style: Theme.of(context).textTheme.bodySmall),
                                ]),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              Pill('Login ID: ${h.loginId}', kBrand, icon: Icons.badge),
                              Pill(h.phone, Colors.green, icon: Icons.call),
                            ]),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _resetPassword(context, h),
                                icon: const Icon(Icons.password, size: 18),
                                label: const Text('Reset password'),
                              ),
                            ),
                          ]),
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
