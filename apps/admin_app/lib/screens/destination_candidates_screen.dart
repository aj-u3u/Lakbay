import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';

/// Reviews staged OSM places before a deliberate publish or rejection.
class DestinationCandidatesScreen extends StatefulWidget {
  const DestinationCandidatesScreen({super.key, this.api});

  final ApiService? api;

  @override
  State<DestinationCandidatesScreen> createState() =>
      _DestinationCandidatesScreenState();
}

class _DestinationCandidatesScreenState
    extends State<DestinationCandidatesScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late Future<List<dynamic>> _future;
  static const _pageSize = 50;
  int _offset = 0;
  String _status = 'staged';
  // Searches the whole queue on the server, so it finds places on any page.
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  Map<String, dynamic>? _selected;
  bool _busy = false;
  bool _dirty = false;
  bool _accessChecked = false;
  String? _error;
  String? _accessPolicy;

  final _fields = <String, TextEditingController>{
    for (final key in [
      'name',
      'lat',
      'lng',
      'district',
      'category',
      'visitor_purpose',
      'description',
      'location',
      'activities',
      'estimated_cost',
      'entrance_fee',
      'overnight_fee',
      'operating_hours',
      'access_source_url',
      'review_notes',
    ])
      key: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() => _api.getDestinationCandidates(
    reviewStatus: _status,
    limit: _pageSize,
    offset: _offset,
    query: _query,
  );

  void _reload() => setState(() => _future = _load());

  /// Waits for a pause in typing, then searches from the first page.
  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _applySearch(text),
    );
  }

  void _applySearch(String text) {
    _searchDebounce?.cancel();
    final query = text.trim();
    if (!mounted || query == _query) return;
    setState(() {
      _query = query;
      _offset = 0;
      _future = _load();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearch('');
  }

  void _select(Map<String, dynamic> candidate) {
    for (final entry in _fields.entries) {
      entry.value.text = candidate[entry.key]?.toString() ?? '';
    }
    setState(() {
      _selected = candidate;
      _accessPolicy = candidate['access_policy']?.toString();
      _accessChecked = false;
      _dirty = false;
      _error = null;
    });
    adminHasUnsavedChanges.value = false;
  }

  void _markDirty() {
    setState(() => _dirty = true);
    adminHasUnsavedChanges.value = true;
  }

  Future<void> _backToQueue() async {
    if (!await confirmAdminNavigation(context) || !mounted) return;
    adminHasUnsavedChanges.value = false;
    setState(() => _selected = null);
  }

  String? _optional(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    final candidate = _selected;
    if (candidate == null || _busy) return;
    final lat = double.tryParse(_fields['lat']!.text.trim());
    final lng = double.tryParse(_fields['lng']!.text.trim());
    final costText = _optional('estimated_cost');
    final cost = costText == null ? null : double.tryParse(costText);
    if (lat == null || lng == null || (costText != null && cost == null)) {
      setState(() => _error = 'Enter valid coordinates and estimated cost.');
      return;
    }
    if (_accessChecked &&
        (_accessPolicy == null || _optional('access_source_url') == null)) {
      setState(
        () => _error = 'Choose an access policy and add its source URL.',
      );
      return;
    }
    final data = <String, dynamic>{
      'name': _fields['name']!.text.trim(),
      'lat': lat,
      'lng': lng,
      'district': _optional('district'),
      'category': _optional('category'),
      'visitor_purpose': _optional('visitor_purpose'),
      'description': _optional('description'),
      'location': _optional('location'),
      'activities': _optional('activities'),
      'estimated_cost': cost,
      'entrance_fee': _optional('entrance_fee'),
      'overnight_fee': _optional('overnight_fee'),
      'operating_hours': _optional('operating_hours'),
      'review_notes': _optional('review_notes'),
    };
    if (_accessPolicy != candidate['access_policy'] || _accessChecked) {
      data['access_policy'] = _accessPolicy;
    }
    if (_optional('access_source_url') != candidate['access_source_url'] ||
        _accessChecked) {
      data['access_source_url'] = _optional('access_source_url');
    }
    if (_accessChecked) {
      data['access_verified_at'] = DateTime.now().toUtc().toIso8601String();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await _api.updateDestinationCandidate(
        candidate['candidate_id'] as int,
        data,
      );
      if (!mounted) return;
      _select(updated);
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidate review saved.')));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final candidate = _selected;
    if (candidate == null || _busy || _dirty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.publishDestinationCandidate(candidate['candidate_id'] as int);
      if (!mounted) return;
      adminHasUnsavedChanges.value = false;
      setState(() => _selected = null);
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Destination published.')));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final candidate = _selected;
    if (candidate == null || _busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject candidate'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    if (reason.length < 5) {
      setState(() => _error = 'Give a reason of at least five characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.rejectDestinationCandidate(
        candidate['candidate_id'] as int,
        reason,
      );
      if (!mounted) return;
      adminHasUnsavedChanges.value = false;
      setState(() => _selected = null);
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidate rejected.')));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'The review could not be completed. Please try again.';

  Widget _field(String key, String label, {int lines = 1}) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: TextField(
      controller: _fields[key],
      maxLines: lines,
      enabled: _selected?['review_status'] == 'staged' && !_busy,
      onChanged: (_) => _markDirty(),
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _detail(Map<String, dynamic> candidate) {
    final staged = candidate['review_status'] == 'staged';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _backToQueue,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to review queue'),
        ),
        const SizedBox(height: 12),
        AdminPageHeader(
          title: candidate['name']?.toString() ?? 'Candidate',
          description:
              'Review OSM identity, visitor purpose, access, and map pin.',
        ),
        const SizedBox(height: 20),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OSM source: ${candidate['osm_type']} ${candidate['osm_id']}',
              ),
              Text('Source tag: ${candidate['source_tag']}'),
              Text('Source area: ${candidate['source_area']}'),
              Text(
                'Suggested category: ${candidate['suggested_category'] ?? 'None'}',
              ),
              SelectableText(candidate['osm_url']?.toString() ?? ''),
              if (candidate['access_verified_at'] != null)
                Text(
                  'Access last verified: ${candidate['access_verified_at']}',
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _field('name', 'Destination name'),
                  _field('lat', 'Latitude'),
                  _field('lng', 'Longitude'),
                  _field('district', 'District'),
                  _field('category', 'Visitor category'),
                  _field('visitor_purpose', 'Visitor purpose', lines: 2),
                  _field('location', 'Address or location'),
                  _field('activities', 'Activities', lines: 2),
                  _field('description', 'Description', lines: 3),
                  _field('estimated_cost', 'Estimated cost (PHP)'),
                  _field('entrance_fee', 'Entrance fee'),
                  _field('overnight_fee', 'Overnight fee'),
                  _field('operating_hours', 'Operating hours'),
                  _field('review_notes', 'Review notes', lines: 2),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                key: ValueKey(candidate['candidate_id']),
                initialValue: _accessPolicy,
                decoration: const InputDecoration(
                  labelText: 'Visitor access policy',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Unverified')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(
                    value: 'customers',
                    child: Text('Customers'),
                  ),
                  DropdownMenuItem(
                    value: 'permit',
                    child: Text('Permit required'),
                  ),
                ],
                onChanged: staged && !_busy
                    ? (value) => setState(() {
                        _accessPolicy = value;
                        _dirty = true;
                        adminHasUnsavedChanges.value = true;
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              _field('access_source_url', 'Visitor access source URL'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I checked this access evidence'),
                subtitle: const Text(
                  'Saving records the current verification time.',
                ),
                value: _accessChecked,
                onChanged: staged && !_busy
                    ? (value) => setState(() {
                        _accessChecked = value ?? false;
                        _dirty = true;
                        adminHasUnsavedChanges.value = true;
                      })
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (staged) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: const Text('Save review'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || _dirty ? null : _publish,
                      child: const Text('Publish destination'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _reject,
                      child: const Text('Reject candidate'),
                    ),
                  ],
                ),
                if (_dirty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Save changes before publishing.'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    child: _selected != null
        ? _detail(_selected!)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminPageHeader(
                title: 'Place review',
                description:
                    'OSM candidates stay hidden from travelers until an admin publishes each place.',
                action: OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: TextField(
                  key: const Key('candidate-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: _applySearch,
                  decoration: InputDecoration(
                    labelText: 'Search places',
                    hintText: 'Name, district, location, category or OSM id',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('candidate-search-clear'),
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'staged', child: Text('Staged')),
                  DropdownMenuItem(
                    value: 'published',
                    child: Text('Published'),
                  ),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _status = value;
                    _offset = 0;
                    _future = _load();
                  });
                },
              ),
              FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AdminMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Review queue unavailable',
                      message: _message(snapshot.error!),
                      isError: true,
                      action: OutlinedButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    );
                  }
                  final records = snapshot.data!
                      .whereType<Map>()
                      .map((row) => Map<String, dynamic>.from(row))
                      .toList();
                  return Column(
                    children: [
                      AdminPanel(
                        child: records.isEmpty
                            ? Text(
                                _query.isEmpty
                                    ? 'No candidates on this page.'
                                    : 'No places match "$_query" in this list.',
                              )
                            : Column(
                                children: [
                                  for (final candidate in records)
                                    ListTile(
                                      title: Text(
                                        candidate['name']?.toString() ??
                                            'Unnamed place',
                                      ),
                                      subtitle: Text(
                                        '${candidate['source_area'] ?? ''} · ${candidate['source_tag'] ?? ''}',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _select(candidate),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _offset == 0
                                ? null
                                : () => setState(() {
                                    _offset -= _pageSize;
                                    _future = _load();
                                  }),
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 12),
                          Text('Page ${_offset ~/ _pageSize + 1}'),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: records.length < _pageSize
                                ? null
                                : () => setState(() {
                                    _offset += _pageSize;
                                    _future = _load();
                                  }),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
  );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    adminHasUnsavedChanges.value = false;
    for (final controller in _fields.values) {
      controller.dispose();
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }
}
