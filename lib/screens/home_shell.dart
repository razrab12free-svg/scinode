import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../services/library_service.dart';
import '../services/openalex_service.dart';
import '../strings.dart';
import '../widgets/logo.dart';
import 'library_screen.dart';
import 'search_screen.dart';

const appVersion = '0.2.0';

void showSoonSheet(BuildContext context, String title, String text) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Chip(label: Text(t('soon.in_dev'))),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onGo: (i) => setState(() => _tab = i)),
          SearchScreen(),
          LibraryScreen(),
          ComingSoonTab(
            icon: Icons.hub,
            title: t('tab.network'),
            text: t('soon.network'),
          ),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t('tab.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            selectedIcon: const Icon(Icons.search),
            label: t('tab.search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books),
            label: t('tab.library'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.hub_outlined),
            selectedIcon: const Icon(Icons.hub),
            label: t('tab.network'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t('tab.profile'),
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onGo});
  final void Function(int) onGo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = AuthService.instance.user?.displayName ?? '';
    final first =
        full.trim().isEmpty ? t('home.friend') : full.trim().split(' ').first;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 20, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LogoMark(size: 40),
                  const SizedBox(width: 10),
                  Text(
                    'Scinode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                t('home.hello', {'name': first}),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('home.sub'),
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onPrimary.withAlpha(220),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _Tile(
                icon: Icons.article_outlined,
                label: t('qa.papers'),
                onTap: () => onGo(1),
              ),
              _Tile(
                icon: Icons.library_books_outlined,
                label: t('tab.library'),
                onTap: () => onGo(2),
              ),
              _Tile(
                icon: Icons.groups_outlined,
                label: t('qa.scientists'),
                soon: true,
                onTap: () => onGo(3),
              ),
              _Tile(
                icon: Icons.payments_outlined,
                label: t('qa.grants'),
                soon: true,
                onTap: () =>
                    showSoonSheet(context, t('qa.grants'), t('soon.grants')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.soon = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  if (soon)
                    Text(
                      t('soon'),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: scheme.primary),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Chip(label: Text(t('soon.in_dev'))),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _editKey(BuildContext context) async {
    final svc = OpenAlexService.instance;
    final ctrl = TextEditingController(text: svc.apiKey ?? '');
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('key.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('key.text'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: t('key.hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              svc.setKey(null);
              Navigator.pop(d);
            },
            child: Text(t('key.clear')),
          ),
          TextButton(
            onPressed: () {
              svc.setKey(ctrl.text.trim());
              Navigator.pop(d);
            },
            child: Text(t('key.save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([Strings.instance, OpenAlexService.instance]),
      builder: (context, _) {
        final st = Strings.instance;
        final svc = OpenAlexService.instance;
        final user = AuthService.instance.user;
        final photo = user?.photoURL;
        final name = (user?.displayName ?? '').trim();
        final email = user?.email ?? '';

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  onBackgroundImageError: photo != null ? (_, __) {} : null,
                  child:
                      photo == null ? const Icon(Icons.person, size: 44) : null,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  name.isEmpty ? t('profile.guest') : name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              if (email.isNotEmpty)
                Center(
                    child: Text(email, style: const TextStyle(fontSize: 14))),
              const SizedBox(height: 28),
              Text(t('profile.language'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in const ['uz', 'ru', 'en'])
                    ChoiceChip(
                      label: Text(Strings.names[code]!,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      selected: st.lang == code,
                      showCheckmark: false,
                      onSelected: (_) => st.setLang(code),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: Text(t('profile.key')),
                  subtitle: Text(
                      svc.hasKey ? t('profile.key_set') : t('profile.key_none')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editKey(context),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => AuthService.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: Text(t('profile.signout')),
              ),
              const SizedBox(height: 24),
              Text(t('profile.about'), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(t('profile.version', {'v': appVersion}),
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
