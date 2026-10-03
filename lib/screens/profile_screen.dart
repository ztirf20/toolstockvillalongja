import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../utils.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to use ToolStock.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initials(user.name),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(user.email, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      RoleBadge(user.role),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Your access'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: user.isOwner
                  ? const [
                      _Perm('Add, edit and delete tools', true),
                      _Perm('Stock in, stock out and corrections', true),
                      _Perm('Reports and stock value', true),
                      _Perm('Manage staff accounts', true),
                    ]
                  : const [
                      _Perm('View tools, dashboard and history', true),
                      _Perm('Stock in and stock out', true),
                      _Perm('Add, edit or delete tools', false),
                      _Perm('Corrections, reports and team', false),
                    ],
            ),
          ),
          if (user.isOwner) ...[
            const SizedBox(height: 20),
            const SectionTitle('Staff invite code'),
            const _InviteCodeCard(),
            const SizedBox(height: 20),
            const SectionTitle('Team'),
            const _TeamList(),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Perm extends StatelessWidget {
  final String text;
  final bool allowed;
  const _Perm(this.text, this.allowed);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(allowed ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: allowed
                  ? Colors.green.shade600
                  : Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatefulWidget {
  const _InviteCodeCard();

  @override
  State<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends State<_InviteCodeCard> {
  late final Stream<String?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<AuthProvider>().watchStaffCode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: StreamBuilder<String?>(
        stream: _stream,
        builder: (context, snap) {
          final code = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code ?? '------',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy),
                    onPressed: code == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')));
                          },
                  ),
                ],
              ),
              Text(
                'New staff need this code to register. Share it only with people you trust.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().regenerateStaffCode();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('New code generated. The old one no longer works.')));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Generate new code'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamList extends StatefulWidget {
  const _TeamList();

  @override
  State<_TeamList> createState() => _TeamListState();
}

class _TeamListState extends State<_TeamList> {
  late final Stream<List<AppUser>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<AuthProvider>().watchTeam();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppCard(child: Text('Could not load the team.'));
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final team = snap.data!;
        final staffCount = team.where((u) => !u.isOwner).length;
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < team.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(initials(team[i].name),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(team[i].email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (team[i].isOwner)
                        RoleBadge(team[i].role)
                      else
                        Column(
                          children: [
                            Switch(
                              value: team[i].active,
                              onChanged: (v) => context
                                  .read<AuthProvider>()
                                  .setActive(team[i].uid, v),
                            ),
                            Text(team[i].active ? 'Active' : 'Disabled',
                                style: theme.textTheme.labelSmall),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (staffCount == 0) ...[
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No staff yet. Share the invite code above.'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}