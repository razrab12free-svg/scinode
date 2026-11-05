import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/scientist.dart';
import '../models/taxonomy.dart';
import '../strings.dart';
import '../utils.dart';

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCode(s.runes.first);
  if (parts.length == 1) return first(parts.first).toUpperCase();
  return (first(parts.first) + first(parts.last)).toUpperCase();
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.radius = 24});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withAlpha(36),
      child: Text(
        initials(name),
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
          ),
        ],
      ),
    );
  }
}

class ScientistCard extends StatelessWidget {
  const ScientistCard({super.key, required this.s, required this.onTap});
  final Scientist s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = [
      s.institution.isEmpty ? t('sci.no_inst') : s.institution,
      if (s.countryCode.isNotEmpty) countryName(s.countryCode),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(s.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (s.count != null)
                          _Stat(Icons.article_outlined,
                              t('net.works_here', {'n': s.count!})),
                        _Stat(Icons.bar_chart, t('sci.h', {'n': s.hIndex})),
                        _Stat(Icons.format_quote,
                            t('sci.cited', {'n': s.citations})),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showScientistSheet(BuildContext context, Scientist s) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final bottom = MediaQuery.of(ctx).viewPadding.bottom;
      final sub = [
        s.institution.isEmpty ? t('sci.no_inst') : s.institution,
        if (s.countryCode.isNotEmpty) countryName(s.countryCode),
      ].join(' · ');
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(s.name, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(s.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(sub,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Stat(Icons.bar_chart, t('sci.h', {'n': s.hIndex})),
                _Stat(Icons.article_outlined, t('sci.works', {'n': s.works})),
                _Stat(Icons.format_quote, t('sci.cited', {'n': s.citations})),
              ],
            ),
            if (s.topics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(t('sci.topics'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [for (final x in s.topics) Chip(label: Text(x))],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openLink(ctx, s.openAlexUrl),
              icon: const Icon(Icons.open_in_new),
              label: Text(t('sci.open_oa')),
            ),
            if (s.orcid != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => openLink(ctx, s.orcid!),
                icon: const Icon(Icons.badge_outlined),
                label: Text(t('sci.open_orcid')),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.p,
    required this.isMe,
    required this.onTap,
  });
  final UserProfile p;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = [
      t('role.${p.role}'),
      if (p.org.isNotEmpty) p.org,
      if (p.country.isNotEmpty) countryName(p.country),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(p.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                    if (p.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final x in p.tags.take(3))
                            _Stat(Icons.science_outlined, x.label),
                        ],
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(height: 6),
                      Text(t('sci.you'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMemberSheet(BuildContext context, UserProfile p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final bottom = MediaQuery.of(ctx).viewPadding.bottom;
      final sub = [
        t('role.${p.role}'),
        if (p.org.isNotEmpty) p.org,
        if (p.country.isNotEmpty) countryName(p.country),
      ].join(' · ');
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(p.name, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(sub,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
            if (p.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final x in p.tags) Chip(label: Text(x.label)),
                ],
              ),
            ],
            if (p.bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(t('sci.about'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(p.bio, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
            const SizedBox(height: 16),
            if (p.oaId.isNotEmpty)
              FilledButton.icon(
                onPressed: () =>
                    openLink(ctx, 'https://openalex.org/${p.oaId}'),
                icon: const Icon(Icons.open_in_new),
                label: Text(t('sci.open_oa')),
              ),
            if (p.orcid.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => openLink(ctx, 'https://orcid.org/${p.orcid}'),
                icon: const Icon(Icons.badge_outlined),
                label: Text(t('sci.open_orcid')),
              ),
            ],
          ],
        ),
      );
    },
  );
}
