import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';

String _requestErrorTitle(Object? error, String fallback) {
  if (error is ApiException) {
    if (error.statusCode == 401) return 'Sign in to continue';
    if (error.statusCode == 403) return 'Access restricted';
  }
  return fallback;
}

/// Rates are read in a destination context because the API has no global list.
class MarketRatesScreen extends StatefulWidget {
  final int initialTab;
  final String? destinationId;
  final ApiService? api;

  const MarketRatesScreen({
    super.key,
    this.initialTab = 0,
    this.destinationId,
    this.api,
  });

  @override
  State<MarketRatesScreen> createState() => _MarketRatesScreenState();
}

class _MarketRatesScreenState extends State<MarketRatesScreen>
    with SingleTickerProviderStateMixin {
  late final ApiService _api = widget.api ?? ApiService();
  final TextEditingController _search = TextEditingController();
  late final TabController _tabs;
  List<Map<String, dynamic>> _destinations = [];
  final List<Future<List<dynamic>>?> _rateRequests = [null, null];
  String? _destinationId;
  Object? _destinationError;
  bool _loadingDestinations = true;
  bool _readArguments = false;

  @override
  void initState() {
    super.initState();
    _destinationId = widget.destinationId;
    _tabs = TabController(
      length: 2,
      initialIndex: widget.initialTab == 1 ? 1 : 0,
      vsync: this,
    )..addListener(_tabChanged);
    _loadDestinations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArguments) return;
    _readArguments = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      final argumentId =
          arguments['destination_id'] ?? arguments['destinationId'];
      if (argumentId != null) _destinationId = argumentId.toString();
      if (arguments['tab'] == 'transport') _tabs.index = 1;
      if (arguments['tab'] == 'accommodation') _tabs.index = 0;
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    _search.dispose();
    _api.close();
    super.dispose();
  }

  void _tabChanged() {
    if (!mounted) return;
    setState(() {
      if (_destination != null &&
          !_loadingDestinations &&
          _destinationError == null &&
          _rateRequests[_tabs.index] == null) {
        _rateRequests[_tabs.index] = _requestRates(_tabs.index);
      }
    });
  }

  bool get _isAccommodation => _tabs.index == 0;
  String get _rateName => _isAccommodation ? 'accommodation' : 'transport';

  Map<String, dynamic>? get _destination {
    for (final destination in _destinations) {
      if (destination['destination_id'].toString() == _destinationId) {
        return destination;
      }
    }
    return null;
  }

  String get _destinationName => _destination?['name']?.toString() ?? '';

  Future<void> _loadDestinations() async {
    setState(() {
      _loadingDestinations = true;
      _destinationError = null;
    });
    try {
      final data = await _api.getDestinations();
      if (!mounted) return;
      setState(() {
        _destinations =
            data
                .map((item) {
                  return Map<String, dynamic>.from(item as Map);
                })
                .where((item) => item['destination_id'] != null)
                .toList()
              ..sort(
                (a, b) => a['name'].toString().compareTo(b['name'].toString()),
              );
        _loadingDestinations = false;
      });
      if (_destination != null) _loadRatesForDestination();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDestinations = false;
        _destinationError = error;
      });
    }
  }

  Future<List<dynamic>> _requestRates(int tab) {
    final destinationId = _destinationId!;
    return tab == 0
        ? _api.getAccommodationRates(destinationId: destinationId)
        : _api.getTransportRates(destinationId: destinationId);
  }

  void _loadRatesForDestination() {
    setState(() {
      _rateRequests[0] = null;
      _rateRequests[1] = null;
      _rateRequests[_tabs.index] = _requestRates(_tabs.index);
    });
  }

  void _refreshRates([int? tab]) {
    if (_destination == null) return;
    final index = tab ?? _tabs.index;
    setState(() {
      _rateRequests[index] = _requestRates(index);
    });
  }

  void _selectDestination(String? id) {
    setState(() {
      _destinationId = id;
      _search.clear();
      _rateRequests[0] = null;
      _rateRequests[1] = null;
    });
    if (id != null) _loadRatesForDestination();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Market Rates',
            description:
                'Maintain accommodation and transport options for each destination.',
            action: FilledButton.icon(
              onPressed:
                  _destination != null &&
                      !_loadingDestinations &&
                      _destinationError == null
                  ? () => _openEditor()
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add $_rateName rate'),
            ),
          ),
          const SizedBox(height: 24),
          AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _destinationPicker(),
                const SizedBox(height: 16),
                Text(
                  'Lists show available options for active destinations. Unavailable options cannot be browsed or restored from this workspace.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Accommodation'),
                    Tab(text: 'Transport'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ratesContent(),
        ],
      ),
    );
  }

  Widget _destinationPicker() {
    if (_loadingDestinations) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading destinations…'),
        ],
      );
    }
    if (_destinationError != null) {
      return AdminMessage(
        icon: Icons.error_outline_rounded,
        title: _requestErrorTitle(
          _destinationError,
          'Destinations could not be loaded',
        ),
        message: _destinationError.toString(),
        isError: true,
        action: OutlinedButton.icon(
          onPressed: _loadDestinations,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }
    if (_destinations.isEmpty) {
      return AdminMessage(
        icon: Icons.location_on_outlined,
        title: 'No active destinations',
        message: 'Create an active destination before adding its rates.',
        action: OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, '/destinations'),
          child: const Text('Open destinations'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final selector = DropdownButtonFormField<String>(
          key: ValueKey('destination-${_destinationId ?? 'none'}'),
          initialValue: _destination != null ? _destinationId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Destination',
            hintText: 'Choose a destination',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: _destinations.map((destination) {
            final district = destination['district']?.toString() ?? '';
            return DropdownMenuItem(
              value: destination['destination_id'].toString(),
              child: Text(
                '${destination['name']}${district.isEmpty ? '' : ' · $district'}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _selectDestination,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _loadDestinations(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh destinations'),
            ),
            if (_destination != null)
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/destinations',
                  arguments: _destination,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View destination'),
              ),
          ],
        );
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [selector, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: selector),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _ratesContent() {
    if (_loadingDestinations ||
        _destinationError != null ||
        _destinations.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_destination == null) {
      return AdminMessage(
        icon: Icons.price_change_outlined,
        title: _destinationId == null
            ? 'Choose a destination'
            : 'The selected destination is unavailable',
        message: _destinationId == null
            ? 'Select a destination above to view and maintain its rates.'
            : 'It is absent from the active destination list. Choose another destination to continue.',
      );
    }
    final tab = _tabs.index;
    return FutureBuilder<List<dynamic>>(
      key: ValueKey('rates-$_destinationId-$tab'),
      future: _rateRequests[tab],
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AdminPanel(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return AdminMessage(
            icon: Icons.error_outline_rounded,
            title: _requestErrorTitle(
              snapshot.error,
              'Rates could not be loaded',
            ),
            message: snapshot.error.toString(),
            isError: true,
            action: OutlinedButton.icon(
              onPressed: () => _refreshRates(tab),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        }
        final records = (snapshot.data ?? []).map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
        final query = _search.text.trim().toLowerCase();
        final filtered = records.where((item) {
          final fields = tab == 0
              ? ['name', 'room_type', 'description']
              : [
                  'vehicle_type',
                  'transport_mode',
                  'route_from',
                  'route_to',
                  'notes',
                ];
          return fields.any(
            (field) =>
                (item[field]?.toString() ?? '').toLowerCase().contains(query),
          );
        }).toList();
        return AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: tab == 0
                          ? 'Search name, room type or description'
                          : 'Search vehicle, route or notes',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => _search.clear()),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  );
                  final refresh = OutlinedButton.icon(
                    onPressed: () => _refreshRates(tab),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh rates'),
                  );
                  if (constraints.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [search, const SizedBox(height: 12), refresh],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      refresh,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _destinationName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  AdminBadge(label: 'Available options'),
                  Text(
                    '${filtered.length} shown',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Price is the stored amount. Confirm its currency and billing basis in the description or notes; no unit is supplied by the rate record.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              if (filtered.isEmpty)
                AdminMessage(
                  icon: Icons.price_change_outlined,
                  title: records.isEmpty
                      ? 'No available $_rateName options'
                      : 'No matching rates',
                  message: records.isEmpty
                      ? 'Add an option for this destination. Unavailable records are excluded from this list.'
                      : 'Try another search or clear it to see available options.',
                  action: records.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: Text('Add $_rateName rate'),
                        )
                      : OutlinedButton(
                          onPressed: () => setState(() => _search.clear()),
                          child: const Text('Clear search'),
                        ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: filtered.map((item) {
                          return _rateCard(item, tab);
                        }).toList(),
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _rateTable(filtered, tab),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _text(Map<String, dynamic> record, String field) {
    final value = record[field]?.toString().trim() ?? '';
    return value.isEmpty ? '—' : value;
  }

  String _price(Map<String, dynamic> record) {
    final value = num.tryParse(record['price']?.toString() ?? '');
    if (value == null) return '—';
    final currency = record['currency']?.toString() ?? 'PHP';
    final unit = switch (record['charging_unit']?.toString()) {
      'per_room_per_night' => 'room / night',
      'per_room_per_stay' => 'room / stay',
      'per_person' => 'person / one-way leg',
      'per_vehicle' => 'vehicle / one-way leg',
      'per_group' => 'group / one-way leg',
      _ => 'basis unverified',
    };
    return '${currency == 'PHP' ? '₱' : '$currency '}${value.toStringAsFixed(2)} / $unit';
  }

  String _duration(Map<String, dynamic> record) {
    final minutes = record['duration_minutes'];
    final text = record['duration_text']?.toString().trim() ?? '';
    if (minutes == null) return text.isEmpty ? '—' : text;
    return '$minutes min${text.isEmpty ? '' : ' · $text'}';
  }

  Widget _cell(String value, {double width = 180, bool strong = false}) {
    return SizedBox(
      width: width,
      child: Tooltip(
        message: value,
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: strong ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
      ),
    );
  }

  Widget _rowActions(Map<String, dynamic> record, int tab) {
    return Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: () => _openEditor(record, tab),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        TextButton.icon(
          onPressed: () => _deactivate(record, tab),
          icon: const Icon(Icons.visibility_off_outlined, size: 18),
          label: const Text('Deactivate'),
        ),
      ],
    );
  }

  Widget _rateTable(List<Map<String, dynamic>> records, int tab) {
    return DataTable(
      horizontalMargin: 12,
      columnSpacing: 24,
      dataRowMinHeight: 76,
      dataRowMaxHeight: 88,
      columns: tab == 0
          ? const [
              DataColumn(label: Text('Accommodation')),
              DataColumn(label: Text('Room type')),
              DataColumn(label: Text('Price'), numeric: true),
              DataColumn(label: Text('Capacity'), numeric: true),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Actions')),
            ]
          : const [
              DataColumn(label: Text('Vehicle / mode')),
              DataColumn(label: Text('Route')),
              DataColumn(label: Text('Price'), numeric: true),
              DataColumn(label: Text('Duration')),
              DataColumn(label: Text('Notes')),
              DataColumn(label: Text('Actions')),
            ],
      rows: records.map((record) {
        return DataRow(
          cells: tab == 0
              ? [
                  DataCell(
                    _cell(
                      '#${record['accommodation_id']} · ${_text(record, 'name')}',
                      strong: true,
                    ),
                  ),
                  DataCell(_cell(_text(record, 'room_type'), width: 140)),
                  DataCell(Text(_price(record))),
                  DataCell(Text(_text(record, 'capacity'))),
                  DataCell(_cell(_text(record, 'description'), width: 220)),
                  DataCell(_rowActions(record, tab)),
                ]
              : [
                  DataCell(
                    _cell(
                      '#${record['transportation_id']} · ${_text(record, 'vehicle_type')} · ${_text(record, 'transport_mode')}',
                      strong: true,
                    ),
                  ),
                  DataCell(
                    _cell(
                      '${_text(record, 'route_from')} → ${_text(record, 'route_to')}',
                      width: 220,
                    ),
                  ),
                  DataCell(Text(_price(record))),
                  DataCell(_cell(_duration(record), width: 150)),
                  DataCell(_cell(_text(record, 'notes'), width: 220)),
                  DataCell(_rowActions(record, tab)),
                ],
        );
      }).toList(),
    );
  }

  Widget _rateCard(Map<String, dynamic> record, int tab) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tab == 0 ? _text(record, 'name') : _text(record, 'vehicle_type'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            tab == 0
                ? _text(record, 'room_type')
                : '${_text(record, 'transport_mode')} · ${_text(record, 'route_from')} → ${_text(record, 'route_to')}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text('Price: ${_price(record)}'),
              Text(
                tab == 0
                    ? 'Capacity: ${_text(record, 'capacity')}'
                    : 'Duration: ${_duration(record)}',
              ),
              AdminBadge(
                label: record['is_available'] == false
                    ? 'Unavailable'
                    : 'Available',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_text(record, tab == 0 ? 'description' : 'notes')),
          const SizedBox(height: 8),
          _rowActions(record, tab),
        ],
      ),
    );
  }

  Future<void> _openEditor([Map<String, dynamic>? record, int? tab]) async {
    if (_destination == null) return;
    final selectedTab = tab ?? _tabs.index;
    final isAccommodation = selectedTab == 0;
    final destinationId = _destinationId!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RateEditor(
        accommodation: isAccommodation,
        destinationName: _destinationName,
        initial: record,
        onSave: (data) async {
          if (record == null) {
            data['destination_id'] = int.parse(destinationId);
            if (isAccommodation) {
              await _api.createAccommodationRate(data);
            } else {
              await _api.createTransportRate(data);
            }
          } else {
            final id =
                record[isAccommodation
                        ? 'accommodation_id'
                        : 'transportation_id']
                    .toString();
            if (isAccommodation) {
              await _api.updateAccommodationRate(id, data);
            } else {
              await _api.updateTransportRate(id, data);
            }
          }
        },
      ),
    );
    if (!mounted || result != true) return;
    _refreshRates(selectedTab);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rate saved. Available options have been refreshed.'),
      ),
    );
  }

  Future<void> _deactivate(Map<String, dynamic> record, int tab) async {
    final name = tab == 0
        ? '${_text(record, 'name')} · ${_text(record, 'room_type')}'
        : '${_text(record, 'vehicle_type')} · ${_text(record, 'route_from')} → ${_text(record, 'route_to')}';
    final id = record[tab == 0 ? 'accommodation_id' : 'transportation_id']
        .toString();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeactivateRateDialog(
        name: name,
        destinationName: _destinationName,
        onDeactivate: () async {
          if (tab == 0) {
            await _api.deleteAccommodationRate(id);
          } else {
            await _api.deleteTransportRate(id);
          }
        },
      ),
    );
    if (!mounted || result != true) return;
    _refreshRates(tab);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rate marked unavailable.')));
  }
}

class _RateEditor extends StatefulWidget {
  final bool accommodation;
  final String destinationName;
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _RateEditor({
    required this.accommodation,
    required this.destinationName,
    required this.onSave,
    this.initial,
  });

  @override
  State<_RateEditor> createState() => _RateEditorState();
}

class _RateEditorState extends State<_RateEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  bool _available = true;
  bool _saving = false;
  bool _dirty = false;
  bool _closing = false;
  String? _chargingUnit;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final keys = widget.accommodation
        ? ['name', 'room_type', 'price', 'capacity', 'description']
        : [
            'vehicle_type',
            'transport_mode',
            'route_from',
            'route_to',
            'price',
            'duration_minutes',
            'duration_text',
            'notes',
          ];
    for (final key in keys) {
      _fields[key] = TextEditingController(
        text:
            widget.initial?[key]?.toString() ?? (key == 'capacity' ? '2' : ''),
      );
    }
    _available = widget.initial?['is_available'] != false;
    _chargingUnit = widget.initial?['charging_unit']?.toString();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _closing) return;
    _closing = true;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved rate changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (discard != true) {
        _closing = false;
        return;
      }
    }
    if (!mounted) return;
    setState(() => _dirty = false);
    Navigator.pop(context, false);
  }

  String? _requiredText(String? value, String label, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return '$label needs at least 2 characters.';
    if (text.length > maxLength) return 'Use at most $maxLength characters.';
    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    final number = double.tryParse(text);
    if (number == null || !number.isFinite || number < 0) {
      return 'Enter a price of zero or more.';
    }
    if (!RegExp(r'^[0-9]+([.][0-9]{1,2})?$').hasMatch(text)) {
      return 'Use a number with up to 2 decimal places.';
    }
    if (number > 99999999.99) return 'Price must be at most 99999999.99.';
    return null;
  }

  Widget _field(
    String key,
    String label, {
    int? maxLength,
    bool required = false,
    bool numeric = false,
    int lines = 1,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: _fields[key],
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        helperText: helper,
        helperMaxLines: 3,
      ),
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (lines > 1 ? TextInputType.multiline : TextInputType.text),
      onChanged: (_) => setState(() => _dirty = true),
      validator:
          validator ??
          (required
              ? (value) => _requiredText(value, label, maxLength ?? 255)
              : null),
    );
  }

  Widget _pair(Widget first, Widget second) {
    if (MediaQuery.sizeOf(context).width < 640) {
      return Column(children: [first, const SizedBox(height: 16), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Future<bool> _confirmUnavailable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as unavailable?'),
        content: const Text(
          'This option will be hidden from available lists. Unavailable records cannot be browsed or restored from this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save unavailable'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_available && widget.initial?['is_available'] != false) {
      if (!await _confirmUnavailable() || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final Map<String, dynamic> data = {};
    for (final entry in _fields.entries) {
      final value = entry.value.text.trim();
      data[entry.key] = value.isEmpty ? null : value;
    }
    if (widget.accommodation) {
      data['capacity'] = int.parse(_fields['capacity']!.text.trim());
    } else {
      final minutes = _fields['duration_minutes']!.text.trim();
      data['duration_minutes'] = minutes.isEmpty ? null : int.parse(minutes);
    }
    data['is_available'] = _available;
    data['currency'] = 'PHP';
    data['charging_unit'] = _chargingUnit;
    try {
      await widget.onSave(data);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.accommodation ? 'accommodation' : 'transport';
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        scrollable: true,
        title: Text('${widget.initial == null ? 'Add' : 'Edit'} $type rate'),
        content: SizedBox(
          width: 640,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.destinationName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Required fields are marked *. All rates use Philippine pesos (PHP). Select how this price is charged.',
                ),
                const SizedBox(height: 24),
                if (widget.accommodation) ...[
                  _field(
                    'name',
                    'Accommodation name',
                    required: true,
                    maxLength: 255,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'room_type',
                    'Room type',
                    required: true,
                    maxLength: 255,
                  ),
                  const SizedBox(height: 16),
                  _pair(
                    _field(
                      'price',
                      'Price',
                      required: true,
                      numeric: true,
                      validator: _validatePrice,
                    ),
                    _field(
                      'capacity',
                      'Capacity',
                      required: true,
                      numeric: true,
                      validator: (value) {
                        final capacity = int.tryParse(value?.trim() ?? '');
                        return capacity == null || capacity < 1
                            ? 'Enter a whole number of 1 or more.'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field('description', 'Description', lines: 3),
                ] else ...[
                  _pair(
                    _field(
                      'vehicle_type',
                      'Vehicle type',
                      required: true,
                      maxLength: 100,
                    ),
                    _field(
                      'transport_mode',
                      'Transport mode',
                      required: true,
                      maxLength: 100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _pair(
                    _field(
                      'route_from',
                      'Route from',
                      required: true,
                      maxLength: 255,
                    ),
                    _field(
                      'route_to',
                      'Route to',
                      required: true,
                      maxLength: 255,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'price',
                    'Price',
                    required: true,
                    numeric: true,
                    validator: _validatePrice,
                  ),
                  const SizedBox(height: 16),
                  _pair(
                    _field(
                      'duration_minutes',
                      'Duration in minutes',
                      numeric: true,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final minutes = int.tryParse(text);
                        return minutes == null || minutes < 0
                            ? 'Enter a whole number of zero or more.'
                            : null;
                      },
                    ),
                    _field(
                      'duration_text',
                      'Duration description',
                      maxLength: 100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field('notes', 'Notes', lines: 3),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _chargingUnit,
                  decoration: const InputDecoration(
                    labelText: 'Charging unit *',
                  ),
                  items:
                      (widget.accommodation
                              ? const {
                                  'per_room_per_night': 'Per room per night',
                                  'per_room_per_stay': 'Per room per stay',
                                }
                              : const {
                                  'per_person': 'Per person per one-way leg',
                                  'per_vehicle': 'Per vehicle per one-way leg',
                                  'per_group': 'Per group per one-way leg',
                                })
                          .entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _chargingUnit = value;
                          _dirty = true;
                        }),
                  validator: (value) => value == null
                      ? 'Choose how this price is charged.'
                      : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  subtitle: const Text(
                    'Unavailable options are hidden from available lists.',
                  ),
                  value: _available,
                  onChanged: _saving
                      ? null
                      : (value) {
                          setState(() {
                            _available = value;
                            _dirty = true;
                          });
                        },
                ),
                if (!_available) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'You cannot rediscover or restore an unavailable option from this workspace.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AdminMessage(
                    icon: Icons.error_outline_rounded,
                    title: _requestErrorTitle(_error, 'Rate was not saved'),
                    message: _error.toString(),
                    isError: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save rate'),
          ),
        ],
      ),
    );
  }
}

class _DeactivateRateDialog extends StatefulWidget {
  final String name;
  final String destinationName;
  final Future<void> Function() onDeactivate;

  const _DeactivateRateDialog({
    required this.name,
    required this.destinationName,
    required this.onDeactivate,
  });

  @override
  State<_DeactivateRateDialog> createState() => _DeactivateRateDialogState();
}

class _DeactivateRateDialogState extends State<_DeactivateRateDialog> {
  bool _busy = false;
  Object? _error;

  Future<void> _deactivate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDeactivate();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Deactivate this rate?'),
        content: SizedBox(
          width: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(widget.destinationName),
              const SizedBox(height: 16),
              const Text(
                'This marks the option unavailable and hides it from available lists. The record stays in the database. Unavailable options cannot be browsed or restored from this workspace.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AdminMessage(
                  icon: Icons.error_outline_rounded,
                  title: _requestErrorTitle(_error, 'Rate was not deactivated'),
                  message: _error.toString(),
                  isError: true,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _deactivate,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text(_busy ? 'Deactivating…' : 'Deactivate'),
          ),
        ],
      ),
    );
  }
}
