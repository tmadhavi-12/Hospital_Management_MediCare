import 'package:flutter/material.dart';
import 'store.dart';
import 'links.dart';
import 'auth_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _numbers(BuildContext context) {
    const nums = [
      ('Ambulance', '108'),
      ('Police', '100'),
      ('Fire', '101'),
      ('Women helpline', '181'),
      ('National emergency', '112'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency numbers'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...nums.map((n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.call, color: Colors.red),
                    title: Text(n.$1),
                    subtitle: Text(n.$2),
                    onTap: () => callNumber(context, n.$2),
                  )),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_hospital, color: Colors.red),
                title: Text(store.hospitalName),
                subtitle: Text(store.hospitalPhone),
                onTap: () => callNumber(context, store.hospitalPhone),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _changePin(BuildContext context) {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change admin PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: oldC,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current PIN'),
            ),
            TextField(
              controller: newC,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'New PIN (min 4 digits)', errorText: error),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (oldC.text != store.adminPin) {
                  setS(() => error = 'Current PIN is wrong');
                  return;
                }
                if (newC.text.length < 4 || int.tryParse(newC.text) == null) {
                  setS(() => error = 'Use at least 4 digits');
                  return;
                }
                store.changePin(newC.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN changed')));
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (!store.isSuperAdmin)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.emergency, color: Theme.of(context).colorScheme.error, size: 36),
                title: const Text('Emergency numbers', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tap to call 108, 100, 101 or the hospital'),
                onTap: () => _numbers(context),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark mode'),
              value: store.dark,
              onChanged: store.setDark,
            ),
            if (store.currentUser != null) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(store.profileName),
                subtitle: Text(store.profilePhone),
              ),
              ListTile(
                leading: const Icon(Icons.local_hospital),
                title: Text(store.hospitalName),
                subtitle: const Text('Tap to change hospital'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalSelectScreen())),
              ),
            ],
            if (store.isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Change admin PIN'),
                onTap: () => _changePin(context),
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                store.logout();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
            if (store.isSuperAdmin)
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text('Reset demo data'),
              subtitle: const Text('Restore sample doctors, ambulances, blood stock and delete all requests'),
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset all data?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        store.resetAll();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
            const AboutListTile(
              icon: Icon(Icons.info),
              applicationName: 'Hospital Management',
              applicationVersion: '2.0.0',
              aboutBoxChildren: [
                Text('Doctor booking, ambulance request, blood bank, Google Maps and QR check-in.'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
