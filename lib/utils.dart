import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strings.dart';

/// Можно ли открывать ссылку: только обычные веб-адреса http(s) с адресом
/// сайта. Ссылки приходят из внешних данных (OpenAlex, гранты, ORCID), и
/// схемы вроде intent:, file:, tel: или javascript: открывать нельзя.
bool isSafeWebUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return false;
  return (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
}

/// Открывает веб-ссылку во внешнем приложении или браузере.
Future<void> openLink(BuildContext context, String url) async {
  var ok = false;
  if (isSafeWebUrl(url)) {
    try {
      ok = await launchUrl(Uri.parse(url.trim()),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('paper.open_fail'))));
  }
}
