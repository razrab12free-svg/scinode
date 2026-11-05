import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../services/data_deletion.dart';
import '../services/openalex_service.dart';
import '../services/pdf_store.dart';
import '../services/profile_service.dart';
import '../strings.dart';
import 'profile_edit_screen.dart';

const appVersionLabel = '0.4.0';

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
    ProfileService.instance.ensureLoaded();
  }

  Future<void> _openProfileEditor() async {
    await ProfileService.instance.ensureLoaded();
    if (!mounted) return;
    final r = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ProfileEditScreen()),
    );
    if (r != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(r)));
    }
  }

  Future<void> _editKey() async {
    await showDialog<void>(
        context: context, builder: (_) => const _KeyDialog());
  }

  Future<void> _deleteData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(d).colorScheme.error),
        title: Text(t('del.title')),
        content: Text(t('del.text')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t('pdf.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: Text(t('del.confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Экран профиля закроется после выхода из аккаунта,
    // поэтому запоминаем навигатор и место для сообщений заранее.
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(t('del.progress'))),
            ],
          ),
        ),
      ),
    );
    final err = await deleteMyData();
    if (nav.mounted) nav.pop();
    messenger.showSnackBar(SnackBar(
      content:
          Text(err == null ? t('del.done') : t('del.failed', {'err': err})),
      duration: const Duration(seconds: 6),
    ));
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
        ProfileService.instance,
      ]),
      builder: (context, _) {
        final st = Strings.instance;
        final svc = OpenAlexService.instance;
        final store = PdfStore.instance;
        final mine = ProfileService.instance.mine;
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
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: scheme.primary.withAlpha(26),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openProfileEditor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            color: scheme.primary, size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('me.title'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              if (mine == null)
                                Text(t('me.card_sub_empty'),
                                    style: const TextStyle(fontSize: 13))
                              else ...[
                                LinearProgressIndicator(
                                  value: mine.percent / 100,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                Text(t('me.completeness', {'p': mine.percent}),
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                  subtitle: Text(svc.hasKey
                      ? t('profile.key_set')
                      : t('profile.key_none')),
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
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: scheme.error,
                ),
                onPressed: _deleteData,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(t('del.button')),
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

/// Окно ввода ключа OpenAlex. Контроллер живёт столько же, сколько окно,
/// поэтому не используется после закрытия (во время анимации).
class _KeyDialog extends StatefulWidget {
  const _KeyDialog();

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: OpenAlexService.instance.apiKey ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = OpenAlexService.instance;
    return AlertDialog(
      title: Text(t('key.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('key.text'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
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
            Navigator.pop(context);
          },
          child: Text(t('key.clear')),
        ),
        TextButton(
          onPressed: () {
            svc.setKey(_ctrl.text.trim());
            Navigator.pop(context);
          },
          child: Text(t('key.save')),
        ),
      ],
    );
  }
}
