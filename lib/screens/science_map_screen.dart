import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../models/institution.dart';
import '../models/taxonomy.dart';
import '../services/map_service.dart';
import '../services/openalex_service.dart';
import '../services/scientist_service.dart';
import '../strings.dart';
import '../utils.dart';
import '../widgets/scientist_card.dart';
import '../widgets/taxonomy_picker.dart';

/// Типы организаций OpenAlex в порядке показа.
const institutionTypes = [
  'education',
  'healthcare',
  'facility',
  'government',
  'company',
  'nonprofit',
  'archive',
  'funder',
  'other',
];

/// Цвет метки по типу организации (одинаково читается в светлой и тёмной теме).
Color typeColor(String type) => switch (type) {
      'education' => const Color(0xFF3B82F6),
      'healthcare' => const Color(0xFFEF4444),
      'facility' => const Color(0xFFF59E0B),
      'government' => const Color(0xFF8B5CF6),
      'company' => const Color(0xFF10B981),
      'nonprofit' => const Color(0xFF14B8A6),
      'archive' => const Color(0xFFA16207),
      'funder' => const Color(0xFFEC4899),
      _ => const Color(0xFF6B7280),
    };

/// Цвета уровней цитируемости (от низкой к высокой).
const citedColors = [
  Color(0xFF94A3B8),
  Color(0xFF38BDF8),
  Color(0xFF6366F1),
  Color(0xFFDB2777),
];
const citedLabels = ['< 5', '5–15', '15–40', '> 40'];

String typeLabel(String type) =>
    t(institutionTypes.contains(type) ? 'type.$type' : 'type.other');

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Карта науки: университеты и научные организации мира.
class ScienceMapScreen extends StatefulWidget {
  const ScienceMapScreen({super.key, this.service, this.showTiles = true});

  /// Можно подменить в тестах.
  final MapService? service;

  /// В тестах подложку из интернета не грузим.
  final bool showTiles;

  @override
  State<ScienceMapScreen> createState() => _ScienceMapScreenState();
}

class _ScienceMapScreenState extends State<ScienceMapScreen> {
  final MapController _map = MapController();
  late final MapService _svc = widget.service ?? MapService.instance;

  String _country = '';
  String _type = '';
  TagRef? _topic;
  bool _colorByCited = false;
  bool _showLegend = true;

  String _region = ''; // континент, по которому загружено ('' — весь мир)
  List<Institution> _items = const [];
  bool _loading = false;
  String? _error;
  int _seq = 0;
  Timer? _debounce;

  // Режим «партнёры».
  Institution? _focus;
  List<(Institution, int)> _partners = const [];
  bool _partnersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- данные

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.institutions(
        country: _country,
        type: _type,
        continent: _region,
        topic: _topic,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on SearchException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.kind == 'limit' ? t('search.err.limit') : t('map.err');
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = t('map.err');
        _loading = false;
      });
    }
  }

  /// При сдвиге и приближении карты подгружаем организации нужного региона.
  void _onMove(MapCamera camera, bool hasGesture) {
    if (!hasGesture || _country.isNotEmpty || _focus != null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final region = camera.zoom < 3.5
          ? ''
          : (continentAt(camera.center.latitude, camera.center.longitude) ??
              '');
      if (region != _region) {
        _region = region;
        _load();
      }
    });
  }

  void _changed(VoidCallback fn) {
    setState(fn);
    _closePartners();
    _load();
  }

  Future<void> _pickCountry() async {
    final r = await pickCountry(context, selected: _country);
    if (r == null || !mounted) return;
    _changed(() {
      _country = r;
      _region = '';
    });
    if (r.isEmpty) _map.move(const LatLng(30, 20), 2);
  }

  Future<void> _pickTopic() async {
    final r = await pickTags(
      context,
      multi: false,
      selected: _topic == null ? const [] : [_topic!],
    );
    if (r == null || !mounted) return;
    _changed(() => _topic = r.isEmpty ? null : r.first);
  }

  Future<void> _pickType() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewPadding.bottom;
        return ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: bottom + 16),
          children: [
            for (final ty in ['', ...institutionTypes])
              ListTile(
                minTileHeight: 52,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: ty.isEmpty
                      ? Theme.of(ctx).colorScheme.outline
                      : typeColor(ty),
                ),
                title: Text(ty.isEmpty ? t('map.type.any') : typeLabel(ty)),
                trailing: ty == _type ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, ty),
              ),
          ],
        );
      },
    );
    if (r == null || !mounted) return;
    _changed(() => _type = r);
  }

  // ------------------------------------------------------------ партнёры

  Future<void> _showPartners(Institution i) async {
    setState(() {
      _focus = i;
      _partners = const [];
      _partnersLoading = true;
    });
    try {
      final p = await _svc.partners(i.id);
      if (!mounted || _focus?.id != i.id) return;
      setState(() {
        _partners = p;
        _partnersLoading = false;
      });
      final pts = [
        LatLng(i.lat!, i.lng!),
        for (final (x, _) in p) LatLng(x.lat!, x.lng!),
      ];
      if (pts.length > 1) {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 120),
          maxZoom: 8,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _partnersLoading = false);
      _toast(t('map.err'));
    }
  }

  void _closePartners() {
    if (_focus == null) return;
    setState(() {
      _focus = null;
      _partners = const [];
      _partnersLoading = false;
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // -------------------------------------------------------------- метки

  Color _colorOf(Institution i) => _colorByCited
      ? citedColors[citedLevel(i.citedPerWork)]
      : typeColor(i.type);

  int _sizeValue(Institution i) => _topic != null ? (i.activity ?? 0) : i.works;

  Marker _marker(Institution i, int minW, int maxW, {bool highlight = false}) {
    final r = markerRadius(_sizeValue(i), minW, maxW);
    final d = r * 2;
    return Marker(
      key: ValueKey(i.id),
      point: LatLng(i.lat!, i.lng!),
      width: d < 48 ? 48 : d, // область нажатия не меньше 48 px
      height: d < 48 ? 48 : d,
      child: Semantics(
        button: true,
        label: i.name,
        child: Center(
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: _colorOf(i).withAlpha(highlight ? 255 : 215),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: highlight ? 3 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onMarkerTap(Marker m) {
    final key = m.key;
    if (key is! ValueKey<String>) return;
    Institution? i;
    for (final x in [
      ..._items,
      if (_focus != null) _focus!,
      for (final (p, _) in _partners) p
    ]) {
      if (x.id == key.value) {
        i = x;
        break;
      }
    }
    if (i != null) _openInstitution(i);
  }

  Future<void> _openInstitution(Institution i) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => InstitutionSheet(institution: i, service: _svc),
    );
    if (action == 'partners' && mounted) _showPartners(i);
  }

  // ------------------------------------------------------------ интерфейс

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? scheme.primaryContainer : scheme.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: active
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                _roundButton(
                    Icons.arrow_back,
                    MaterialLocalizations.of(context).backButtonTooltip,
                    () => Navigator.of(context).maybePop()),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: scheme.surface,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        _focus == null
                            ? t('map.title')
                            : t('map.partners_title', {'name': _focus!.name}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                if (_focus != null) ...[
                  const SizedBox(width: 10),
                  _roundButton(
                      Icons.close, t('map.partners_close'), _closePartners),
                ],
              ],
            ),
          ),
          if (_focus == null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _chip(
                    _country.isEmpty
                        ? t('net.country.any')
                        : countryName(_country),
                    _country.isNotEmpty,
                    _pickCountry,
                    icon: Icons.public,
                  ),
                  _chip(
                    _topic?.label ?? t('net.any_field'),
                    _topic != null,
                    _pickTopic,
                    icon: Icons.category_outlined,
                  ),
                  _chip(
                    _type.isEmpty ? t('map.type.any') : typeLabel(_type),
                    _type.isNotEmpty,
                    _pickType,
                    icon: Icons.account_balance_outlined,
                  ),
                  _chip(
                    _colorByCited ? t('map.color.cited') : t('map.color.type'),
                    false,
                    () => setState(() => _colorByCited = !_colorByCited),
                    icon: Icons.palette_outlined,
                  ),
                ],
              ),
            ),
          if (_loading || _partnersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: scheme.onSurface);
    Widget dot(Color c, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: small)),
            ],
          ),
        );

    final present = {for (final i in _items) i.type};
    return Material(
      color: scheme.surface.withAlpha(235),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _colorByCited ? t('map.legend.cited') : t('map.type'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: t('map.legend.hide'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showLegend = false),
                  ),
                ],
              ),
              if (_colorByCited)
                for (var k = 0; k < citedColors.length; k++)
                  dot(citedColors[k], citedLabels[k])
              else
                for (final ty in institutionTypes)
                  if (present.contains(ty)) dot(typeColor(ty), typeLabel(ty)),
              const SizedBox(height: 4),
              Text(
                _topic != null
                    ? t('map.legend.size_field')
                    : t('map.legend.size'),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status() {
    final scheme = Theme.of(context).colorScheme;
    String? text;
    var isError = false;
    if (_error != null) {
      text = _error;
      isError = true;
    } else if (!_loading && _items.isEmpty && _focus == null) {
      text = t('map.empty');
    } else if (_focus != null && !_partnersLoading && _partners.isEmpty) {
      text = t('map.partners_empty');
    }
    if (text == null) return const SizedBox.shrink();
    return Material(
      color: isError ? scheme.errorContainer : scheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isError ? scheme.onErrorContainer : scheme.onSurface,
                ),
              ),
            ),
            if (isError)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _load,
                child: Text(t('search.retry')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _status(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_showLegend && _focus == null)
                Flexible(child: _legend())
              else if (_focus == null)
                _chip(t('map.legend.show'), false,
                    () => setState(() => _showLegend = true),
                    icon: Icons.info_outline),
              if (_focus != null && _partners.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _partnerList,
                  icon: const Icon(Icons.list),
                  label: Text(t('map.partners_list')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Подпись источников обязательна по правилам OpenStreetMap.
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: scheme.surface.withAlpha(220),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => openLink(
                    context, 'https://www.openstreetmap.org/copyright'),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    '${t('map.osm')} · ${t('map.data')}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _partnerList() async {
    final f = _focus;
    if (f == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewPadding.bottom;
        final scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: EdgeInsets.only(bottom: bottom + 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(t('map.partners_title', {'name': f.name}),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(t('map.partners_sub'),
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
              for (final (p, n) in _partners)
                ListTile(
                  minTileHeight: 56,
                  leading: CircleAvatar(
                      radius: 8, backgroundColor: typeColor(p.type)),
                  title: Text(p.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    if (p.city.isNotEmpty) p.city,
                    if (p.country.isNotEmpty) p.country,
                  ].join(', ')),
                  trailing: Text(t('map.joint', {'n': _fmt(n)}),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _map.move(LatLng(p.lat!, p.lng!), 7);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Размеры меток считаем по текущему набору.
    final source =
        _focus != null ? [_focus!, for (final (p, _) in _partners) p] : _items;
    var minW = 1 << 62, maxW = 0;
    for (final i in source) {
      final v = _sizeValue(i);
      if (v < minW) minW = v;
      if (v > maxW) maxW = v;
    }
    if (source.isEmpty) minW = 0;

    final maxJoint = _partners.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);

    final layers = <Widget>[
      if (widget.showTiles)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.scinode.scinode',
          maxNativeZoom: 19,
          tileBuilder: dark ? darkModeTileBuilder : null,
        ),
    ];

    if (_focus != null) {
      final f = _focus!;
      final from = LatLng(f.lat!, f.lng!);
      layers
        ..add(PolylineLayer(polylines: [
          for (final (p, n) in _partners)
            Polyline(
              points: [from, LatLng(p.lat!, p.lng!)],
              strokeWidth: partnerWidth(n, maxJoint),
              color: scheme.primary.withAlpha(170),
            ),
        ]))
        ..add(MarkerLayer(markers: [
          for (final (p, _) in _partners) _markerTappable(p, minW, maxW),
          _markerTappable(f, minW, maxW, highlight: true),
        ]));
    } else {
      layers.add(MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: 50,
          size: const Size(46, 46),
          disableClusteringAtZoom: 12,
          markers: [for (final i in _items) _marker(i, minW, maxW)],
          onMarkerTap: _onMarkerTap,
          polygonOptions: PolygonOptions(
            color: scheme.primary.withAlpha(40),
            borderColor: scheme.primary,
            borderStrokeWidth: 1.5,
          ),
          builder: (ctx, markers) => Container(
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 4),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${markers.length}',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ));
    }

    return PopScope(
      canPop: _focus == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePartners();
      },
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(30, 20),
                initialZoom: 2,
                minZoom: 2,
                maxZoom: 16,
                backgroundColor:
                    dark ? const Color(0xFF1B1B1F) : const Color(0xFFDDE6EE),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: _onMove,
              ),
              children: layers,
            ),
            Positioned(top: 0, left: 0, right: 0, child: _topBar()),
            Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
          ],
        ),
      ),
    );
  }

  /// Метка в режиме партнёров (без кластеров, нажатие через GestureDetector).
  Marker _markerTappable(Institution i, int minW, int maxW,
      {bool highlight = false}) {
    final m = _marker(i, minW, maxW, highlight: highlight);
    return Marker(
      key: m.key,
      point: m.point,
      width: m.width,
      height: m.height,
      child: GestureDetector(
        onTap: () => _openInstitution(i),
        child: m.child,
      ),
    );
  }
}

/// Карточка организации.
class InstitutionSheet extends StatefulWidget {
  const InstitutionSheet(
      {super.key, required this.institution, required this.service});
  final Institution institution;
  final MapService service;

  @override
  State<InstitutionSheet> createState() => _InstitutionSheetState();
}

class _InstitutionSheetState extends State<InstitutionSheet> {
  late Institution _i = widget.institution;
  late Future<List<GroupCount>> _authors =
      widget.service.topAuthors(widget.institution.id);
  bool _openingAuthor = false;

  @override
  void initState() {
    super.initState();
    // Подгружаем полные данные (темы, h-индекс), если в списке их не было.
    if (_i.topics.isEmpty || _i.hIndex == null) {
      widget.service.institution(_i.id).then((full) {
        if (mounted) setState(() => _i = full.withActivity(_i.activity));
      }).catchError((_) {});
    }
  }

  Future<void> _openAuthor(GroupCount a) async {
    if (_openingAuthor) return;
    setState(() => _openingAuthor = true);
    try {
      final s = await ScientistService.instance.getAuthor(a.id);
      if (!mounted) return;
      await showScientistSheet(context, s);
    } on SearchException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('search.err.${e.kind}'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('map.err'))));
      }
    } finally {
      if (mounted) setState(() => _openingAuthor = false);
    }
  }

  Widget _stat(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = _i;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final place = [
      if (i.city.isNotEmpty) i.city,
      if (i.countryCode.isNotEmpty)
        countryName(i.countryCode) == i.countryCode && i.country.isNotEmpty
            ? i.country
            : countryName(i.countryCode),
    ].join(', ');

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 7, backgroundColor: typeColor(i.type)),
              const SizedBox(width: 8),
              Text(typeLabel(i.type),
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(i.name,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(place,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat(
                  Icons.article_outlined, t('map.works', {'n': _fmt(i.works)})),
              _stat(Icons.format_quote, t('map.cited', {'n': _fmt(i.cited)})),
              if (i.hIndex != null)
                _stat(Icons.bar_chart, t('map.h', {'n': i.hIndex!})),
              if (i.activity != null)
                _stat(Icons.trending_up,
                    t('map.activity', {'n': _fmt(i.activity!)})),
            ],
          ),
          if (i.topics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('map.topics'),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [for (final x in i.topics) Chip(label: Text(x))],
            ),
          ],
          const SizedBox(height: 16),
          Text(t('map.authors'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FutureBuilder<List<GroupCount>>(
            future: _authors,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(t('map.err'),
                          style: TextStyle(color: scheme.error)),
                    ),
                    TextButton(
                      style:
                          TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => setState(() {
                        _authors = widget.service.topAuthors(i.id);
                      }),
                      child: Text(t('search.retry')),
                    ),
                  ],
                );
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t('net.empty')),
                );
              }
              return Column(
                children: [
                  for (var k = 0; k < list.length; k++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 52,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${k + 1}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text(list[k].name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                          t('map.authors_works', {'n': list[k].count}),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      onTap: () => _openAuthor(list[k]),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'partners'),
            icon: const Icon(Icons.hub_outlined),
            label: Text(t('map.partners_show')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => openLink(context, i.openAlexUrl),
            icon: const Icon(Icons.open_in_new),
            label: Text(t('map.open_oa')),
          ),
          if (i.homepage != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => openLink(context, i.homepage!),
              icon: const Icon(Icons.language),
              label: Text(t('map.site')),
            ),
          ],
        ],
      ),
    );
  }
}
