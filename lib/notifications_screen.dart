import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'ui.dart';

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'emergency':
      return Icons.emergency;
    case 'appointment':
      return Icons.event_available;
    default:
      return Icons.notifications;
  }
}

Color _kindColor(String kind) {
  switch (kind) {
    case 'emergency':
      return Colors.red;
    case 'appointment':
      return kBrand;
    default:
      return Colors.orange;
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${fmtDate(t)}';
}

/// Bell icon with unread count. Put it in an AppBar.
class AlertBell extends StatelessWidget {
  const AlertBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final n = store.unreadAlerts;
        return IconButton(
          tooltip: 'Alerts',
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            child: const Icon(Icons.notifications),
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        );
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Alerts that were unread when the screen opened stay highlighted
  late final Set<String> _wasUnread;

  @override
  void initState() {
    super.initState();
    _wasUnread = store.myAlerts.where((n) => !n.read).map((n) => n.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) => store.markAlertsRead());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.myAlerts;
        return Scaffold(
          appBar: AppBar(title: const Text('Alerts')),
          body: list.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No alerts yet'),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final c = _kindColor(n.kind);
                    final fresh = _wasUnread.contains(n.id);
                    return Card(
                      color: fresh ? c.withOpacity(0.07) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: fresh ? c.withOpacity(0.5) : Colors.black12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          IconBadge(icon: _kindIcon(n.kind), color: c),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                                Text(_ago(n.time), style: Theme.of(context).textTheme.bodySmall),
                              ]),
                              const SizedBox(height: 4),
                              Text(n.body),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Wrap the logged-in screens with this. It
///  * shows a pop-up with the unread alerts right after login, and
///  * shows a banner whenever a new alert arrives while the app is open.
class AlertHost extends StatefulWidget {
  final Widget child;
  const AlertHost({super.key, required this.child});

  @override
  State<AlertHost> createState() => _AlertHostState();
}

class _AlertHostState extends State<AlertHost> {
  int _lastUnread = 0;

  @override
  void initState() {
    super.initState();
    _lastUnread = store.unreadAlerts;
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loginPopup());
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    final n = store.unreadAlerts;
    if (n > _lastUnread && mounted) {
      final latest = store.myAlerts.where((a) => !a.read).toList();
      if (latest.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text('${latest.first.title}\n${latest.first.body.split('\n').first}'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ));
      }
    }
    _lastUnread = n;
  }

  void _loginPopup() {
    if (!mounted) return;
    final unread = store.myAlerts.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active, color: Colors.orange, size: 40),
        title: Text('You have ${unread.length} new alert${unread.length == 1 ? '' : 's'}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ...unread.take(4).map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(_kindIcon(n.kind), color: _kindColor(n.kind), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(n.body.split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                )),
            if (unread.length > 4) Text('+ ${unread.length - 4} more'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
