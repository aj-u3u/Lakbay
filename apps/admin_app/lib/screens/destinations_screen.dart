import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';
import 'destination_editor.dart';

class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key, this.initialDestination, this.api});
  final Map<String, dynamic>? initialDestination;
  final ApiService? api;

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  final TextEditingController _search = TextEditingController();
  final ScrollController _horizontal = ScrollController();
  late Future<List<dynamic>> _future;
  Map<String, dynamic>? _selected;
  bool _editing = false;
  bool _creating = false;
  bool _deactivating = false;
  bool _needsReload = false;
  String _category = '';
  String? _actionError;
  int _page = 0;
  bool _ascending = true;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDestination;
    _needsReload = _selected != null;
    _future = _selected == null ? _api.getDestinations() : Future.value([]);
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    _api.close();
    if (_deactivating) adminIsSaving.value = false;
    super.dispose();
  }

  void _refresh() => setState(() {
    _future = _api.getDestinations();
  });

  void _showList() => setState(() {
    _selected = null;
    if (_needsReload) {
      _future = _api.getDestinations();
      _needsReload = false;
    }
  });

  void _edit({bool creating = false}) => setState(() {
    _creating = creating;
    _editing = true;
    _actionError = null;
  });

  void _saved(Map<String, dynamic> record) {
    setState(() {
      _selected = record;
      _editing = false;
      _creating = false;
      _needsReload = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Destination saved.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return DestinationEditor(
        key: ValueKey(_creating ? 'new' : _selected?['destination_id']),
        destination: _creating ? null : _selected,
        api: _api,
        onSaved: _saved,
        onCancel: () => setState(() {
          _editing = false;
          _creating = false;
        }),
      );
    }
    if (_selected != null) return _detail(_selected!);
    return AdminPage(
      key: const PageStorageKey('destination-list'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Destinations',
            description:
                'Maintain traveler information and connect places to their rates.',
            action: FilledButton.icon(
              onPressed: () => _edit(creating: true),
              icon: const Icon(Icons.add),
              label: const Text('Add destination'),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminPanel(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (snapshot.hasError) {
                return AdminMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Destinations could not be loaded',
                  message: _error(snapshot.error!),
                  isError: true,
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                );
              }
              final records = (snapshot.data ?? [])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
              final categories =
                  records
                      .map((item) => _value(item, 'category', fallback: ''))
                      .where((item) => item.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
              if (_category.isNotEmpty && !categories.contains(_category)) {
                categories.add(_category);
                categories.sort();
              }
              final query = _search.text.trim().toLowerCase();
              final filtered =
                  records.where((item) {
                    final words = ['name', 'district', 'location', 'category']
                        .map((key) => _value(item, key, fallback: ''))
                        .join(' ')
                        .toLowerCase();
                    return words.contains(query) &&
                        (_category.isEmpty || item['category'] == _category);
                  }).toList()..sort((a, b) {
                    final order = _value(
                      a,
                      'name',
                    ).toLowerCase().compareTo(_value(b, 'name').toLowerCase());
                    return _ascending ? order : -order;
                  });
              final pages = (filtered.length / _pageSize).ceil();
              final page = _page.clamp(0, pages > 0 ? pages - 1 : 0);
              final visible = filtered
                  .skip(page * _pageSize)
                  .take(_pageSize)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminPanel(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 620
                                ? constraints.maxWidth
                                : constraints.maxWidth - 256,
                            child: TextField(
                              controller: _search,
                              onChanged: (_) => setState(() => _page = 0),
                              decoration: InputDecoration(
                                labelText: 'Search destinations',
                                hintText:
                                    'Name, district, location, or category',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() {
                                          _search.clear();
                                          _page = 0;
                                        }),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth < 240
                                ? constraints.maxWidth
                                : 240,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_category),
                              initialValue: categories.contains(_category)
                                  ? _category
                                  : '',
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('All categories'),
                                ),
                                ...categories.map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                _category = value ?? '';
                                _page = 0;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${filtered.length} of ${records.length} active destinations',
                      ),
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                      if (query.isNotEmpty || _category.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _category = '';
                            _page = 0;
                          }),
                          child: const Text('Reset filters'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    AdminMessage(
                      icon: Icons.place_outlined,
                      title: 'No active destinations',
                      message:
                          'Add a destination to make it available to travelers.',
                      action: FilledButton.icon(
                        onPressed: () => _edit(creating: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Add destination'),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const AdminMessage(
                      icon: Icons.search_off,
                      title: 'No matching destinations',
                      message: 'Try another search or reset your filters.',
                    )
                  else
                    AdminPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => Scrollbar(
                              controller: _horizontal,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontal,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    sortColumnIndex: 0,
                                    sortAscending: _ascending,
                                    headingRowHeight: 48,
                                    dataRowMinHeight: 64,
                                    dataRowMaxHeight: 80,
                                    columnSpacing: 28,
                                    columns: [
                                      DataColumn(
                                        label: const Text('Destination'),
                                        onSort: (_, ascending) => setState(
                                          () => _ascending = ascending,
                                        ),
                                      ),
                                      const DataColumn(label: Text('District')),
                                      const DataColumn(label: Text('Category')),
                                      const DataColumn(label: Text('State')),
                                      const DataColumn(label: Text('Actions')),
                                    ],
                                    rows: visible
                                        .map(
                                          (item) => DataRow(
                                            cells: [
                                              DataCell(
                                                SizedBox(
                                                  width: 260,
                                                  child: TextButton(
                                                    style: TextButton.styleFrom(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                    ),
                                                    onPressed: () => setState(
                                                      () => _selected = item,
                                                    ),
                                                    child: Text(
                                                      _value(item, 'name'),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(
                                                    _value(item, 'district'),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(
                                                    _value(item, 'category'),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              const DataCell(
                                                AdminBadge(label: 'Active'),
                                              ),
                                              DataCell(
                                                TextButton.icon(
                                                  onPressed: () => setState(
                                                    () => _selected = item,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.arrow_forward,
                                                    size: 16,
                                                  ),
                                                  label: const Text('View'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('Page ${page + 1} of $pages'),
                                OutlinedButton.icon(
                                  onPressed: page > 0
                                      ? () => setState(() => _page = page - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  label: const Text('Previous'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: page + 1 < pages
                                      ? () => setState(() => _page = page + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  label: const Text('Next'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Only active destinations are listed. Inactive destination browsing is not available yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _detail(Map<String, dynamic> record) {
    final active = record['is_active'] != false;
    return AdminPage(
      key: PageStorageKey('destination-detail-${record['destination_id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _deactivating ? null : _showList,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to destinations'),
          ),
          const SizedBox(height: 12),
          AdminPageHeader(
            title: _value(record, 'name'),
            description:
                'Destination #${record['destination_id']} · ${_value(record, 'district')}',
            action: FilledButton.icon(
              onPressed: _deactivating ? null : () => _edit(),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit destination'),
            ),
          ),
          const SizedBox(height: 16),
          AdminBadge(label: active ? 'Active' : 'Inactive'),
          const SizedBox(height: 24),
          if (_actionError != null) ...[
            AdminMessage(
              icon: Icons.error_outline,
              title: 'Destination was not changed',
              message: _actionError!,
              isError: true,
            ),
            const SizedBox(height: 16),
          ],
          _section('Overview', [
            _datum('Category', _value(record, 'category')),
            _datum('Description', _value(record, 'description')),
            _datum('Operating hours', _value(record, 'operating_hours')),
            _datum('Best time to visit', _value(record, 'best_time_to_visit')),
            if (_imageUrl(record['image_url']))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  record['image_url'].toString(),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) => const AdminMessage(
                    icon: Icons.broken_image_outlined,
                    title: 'Image could not be loaded',
                    message: 'Check the image URL in the editor.',
                  ),
                ),
              ),
          ]),
          _section('Location & travel', [
            _datum('Location', _value(record, 'location')),
            _datum(
              'Coordinates',
              '${_value(record, 'lat')}, ${_value(record, 'lng')}',
            ),
            _datum('How to get there', _value(record, 'how_to_get_there')),
            _datum(
              'Estimated travel time',
              _value(record, 'estimated_travel_time'),
            ),
            _datum('Travel notes', _value(record, 'travel_notes')),
            _datum('What to bring', _value(record, 'what_to_bring')),
          ]),
          _section('Activities & traveler suitability', [
            _datum('Activities', _value(record, 'activities')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in destinationSuitability.entries)
                  AdminBadge(
                    label:
                        '${entry.value}: ${record[entry.key] == true ? 'Yes' : 'No'}',
                  ),
              ],
            ),
            _datum('Difficulty', _value(record, 'difficulty_level')),
            _datum('Crowd level', _value(record, 'crowd_level')),
            _datum('Stay duration', _value(record, 'stay_duration_type')),
          ]),
          _section('Estimated fees', [
            _datum('Estimated cost', _money(record['estimated_cost'])),
            _datum('Entrance fee', _value(record, 'entrance_fee')),
            _datum('Overnight fee', _value(record, 'overnight_fee')),
            _datum('Budget class', _value(record, 'budget_class')),
            const Text(
              'These destination fees are estimates and descriptive information. Maintain accommodation and transport prices in Market Rates.',
            ),
          ]),
          _section('Related rates & feedback', [
            const Text(
              'Manage accommodation and transport options associated with this destination.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: active && !_deactivating
                    ? () => Navigator.pushNamed(
                        context,
                        '/market-rates',
                        arguments: record,
                      )
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Manage rates'),
              ),
            ),
            const Text(
              'Traveler feedback stays associated with its original trip. Administrative destination feedback inspection is not available yet.',
            ),
          ]),
          if (active)
            TextButton.icon(
              onPressed: _deactivating ? null : _deactivate,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: _deactivating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_off_outlined),
              label: Text(
                _deactivating ? 'Deactivating…' : 'Deactivate destination',
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final child in children) ...[child, const SizedBox(height: 12)],
        ],
      ),
    ),
  );

  Widget _datum(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      SelectableText(value),
    ],
  );

  Future<void> _deactivate() async {
    final record = _selected!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate destination?'),
        content: Text(
          '${_value(record, 'name')} will be hidden from traveler lists. The record is retained, and its related rate lists will no longer be available through this destination. Inactive records cannot currently be browsed from this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    adminIsSaving.value = true;
    setState(() {
      _deactivating = true;
      _actionError = null;
    });
    try {
      if (!await _api.deleteDestination(record['destination_id'].toString())) {
        throw Exception('The destination could not be deactivated.');
      }
      if (!mounted) return;
      setState(() {
        _selected = null;
        _future = _api.getDestinations();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Destination deactivated.')));
    } catch (error) {
      if (mounted) setState(() => _actionError = _error(error));
    } finally {
      if (mounted) {
        adminIsSaving.value = false;
        setState(() => _deactivating = false);
      }
    }
  }
}

String _value(
  Map<String, dynamic> data,
  String key, {
  String fallback = 'Not provided',
}) {
  final value = data[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String _error(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception: '), '');
String _money(dynamic value) {
  final amount = num.tryParse(value?.toString() ?? '');
  return amount == null ? 'Not provided' : 'PHP ${amount.toStringAsFixed(2)}';
}

bool _imageUrl(dynamic value) {
  final uri = Uri.tryParse(value?.toString() ?? '');
  return uri != null &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'https' || uri.scheme == 'http');
}
