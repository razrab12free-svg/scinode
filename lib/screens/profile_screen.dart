import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../services/openalex_service.dart';
import '../services/pdf_store.dart';
import '../strings.dart';

const appVersionLabel = '0.3.0';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    PdfStore.instance.ensureLoaded();
  }

  Future<void> _editKey() async {
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
    ctrl.dispose();
  }

  Future<void> _clearPdfs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(t('storage.clear_q')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t('pdf.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t('storage.clear')),
          ),
        ],
      ),
    );
    if (ok == true) await PdfStore.instance.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        Strings.instance,
        OpenAlexService.instance,
        PdfStore.instance,
      ]),
      builder: (context, _) {
        final st = Strings.instance;
        final svc = OpenAlexService.instance;
        final store = PdfStore.instance;
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
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(t('storage.title')),
                  subtitle: Text(t('storage.info', {
                    'n': store.count,
                    'size': formatBytes(store.totalBytes),
                  })),
                  trailing: TextButton(
                    onPressed: store.count == 0 ? null : _clearPdfs,
                    child: Text(t('storage.clear')),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.key),
                  title: Text(t('profile.key')),
                  subtitle: Text(
                      svc.hasKey ? t('profile.key_set') : t('profile.key_none')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editKey,
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
              Text(t('profile.version', {'v': appVersionLabel}),
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
