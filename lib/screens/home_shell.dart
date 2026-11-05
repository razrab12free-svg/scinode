import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../services/library_service.dart';
import '../strings.dart';
import '../widgets/logo.dart';
import 'grants_screen.dart';
import 'library_screen.dart';
import 'network_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

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
          NetworkScreen(),
          ProfileScreen(),
        ],
      ),
      // Подписи нижней панели не увеличиваем, иначе на узких экранах
      // они переносятся на две строки.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: NavigationBar(
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
            // При крупном системном шрифте плитки становятся выше,
            // чтобы подпись не вылезала за край.
            childAspectRatio: 1.05 /
                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
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
                onTap: () => onGo(3),
              ),
              _Tile(
                icon: Icons.payments_outlined,
                label: t('qa.grants'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GrantsScreen()),
                ),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
