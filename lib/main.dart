
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store.dart';
import 'doctors_screen.dart';
import 'appointments_screen.dart';
import 'health_screen.dart';
import 'admin_screen.dart';
import 'emergency_screen.dart';
import 'auth_screens.dart';
import 'super_admin_screen.dart';
import 'notifications_screen.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fawpwvgulnfrkqbzxdxu.supabase.co',
    publishableKey:
        'sb_publishable_1ZR86kGz4uw-a7T8KMoO4Q_VDNeiR4B',
  );

  await store.init();

  runApp(const HospitalApp());
}

class HospitalApp extends StatelessWidget {
  const HospitalApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kBrand,
      brightness: brightness,
    );

    final light = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          light ? const Color(0xFFF2F6F9) : null,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return MaterialApp(
          title: 'MediCare Connect',
          debugShowCheckedModeBanner: false,
          themeMode:
              store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Selects the correct screen based on the current login state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.loggedIn) {
          return const LoginScreen();
        }

        if (store.isSuperAdmin) {
          return const SuperAdminScreen();
        }

        if (store.isHospital) {
          return AlertHost(
            key: ValueKey(
              'hospital-${store.activeHospitalId}',
            ),
            child: const HospitalPanel(),
          );
        }

        if (store.needsHospital) {
          return const HospitalSelectScreen();
        }

        return AlertHost(
          key: ValueKey('user-${store.currentUser?.id}'),
          child: HomeShell(
            key: ValueKey(
              '${store.currentUser?.id}-${store.activeHospitalId}',
            ),
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DoctorsScreen(),
      const AppointmentsScreen(),
      const EmergencyScreen(),
      const HealthScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() {
            index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency),
            selectedIcon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
        ],
      ),
    );
  }
}