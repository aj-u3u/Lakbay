import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';

const destinationSuitability = <String, String>{
  'is_kid_friendly': 'Kid friendly',
  'is_wheelchair_accessible': 'Wheelchair accessible',
  'is_pet_friendly': 'Pet friendly',
  'is_elderly_friendly': 'Elderly friendly',
  'family_friendly': 'Family friendly',
  'couple_friendly': 'Couple friendly',
  'group_friendly': 'Group friendly',
};

/// A dedicated destination editor inside the existing admin navigation shell.
class DestinationEditor extends StatefulWidget {
  const DestinationEditor({
    super.key,
    required this.api,
    required this.onSaved,
    required this.onCancel,
    this.destination,
  });

  final ApiService api;
  final Map<String, dynamic>? destination;
  final ValueChanged<Map<String, dynamic>> onSaved;
  final VoidCallback onCancel;

  @override
  State<DestinationEditor> createState() => _DestinationEditorState();
}

class _DestinationEditorState extends State<DestinationEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _suitability = <String, bool>{};
  late Map<String, dynamic> _initial;
  bool _dirty = false;
  bool _saving = false;
  bool _leaving = false;
  String? _error;

  static const _textKeys = [
    'name',
    'description',
    'district',
    'location',
    'category',
    'vibes',
    'activities',
    'lat',
    'lng',
    'estimated_cost',
    'entrance_fee',
    'overnight_fee',
    'operating_hours',
    'best_time_to_visit',
    'how_to_get_there',
    'estimated_travel_time',
    'travel_notes',
    'what_to_bring',
    'budget_class',
    'crowd_level',
    'difficulty_level',
    'stay_duration_type',
    'transport_accessibility',
    'image_url',
  ];

  @override
  void initState() {
    super.initState();
    final record = widget.destination ?? <String, dynamic>{};
    for (final key in _textKeys) {
      final value = record[key]?.toString() ?? '';
      _controllers[key] = TextEditingController(text: value);
    }
    for (final key in destinationSuitability.keys) {
      _suitability[key] = record[key] == true;
    }
    _initial = _snapshot();
    for (final controller in _controllers.values) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    adminHasUnsavedChanges.value = false;
    if (_saving) adminIsSaving.value = false;
    super.dispose();
  }

  Map<String, dynamic> _snapshot() => {
    for (final entry in _controllers.entries)
      entry.key: entry.value.text.trim(),
    ..._suitability,
  };

  void _changed() {
    final current = _snapshot();
    final dirty = current.entries.any(
      (entry) => entry.value != _initial[entry.key],
    );
    adminHasUnsavedChanges.value = dirty;
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
  }

  Future<void> _cancel() async {
    if (_saving || _leaving) return;
    _leaving = true;
    final accepted = await confirmAdminNavigation(context);
    _leaving = false;
    if (accepted && mounted) widget.onCancel();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Check the highlighted fields before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    adminIsSaving.value = true;
    final current = _snapshot();
    final payload = <String, dynamic>{};
    for (final key in _textKeys) {
      if (widget.destination != null && current[key] == _initial[key]) continue;
      final text = _controllers[key]!.text.trim();
      payload[key] = switch (key) {
        'lat' || 'lng' => double.parse(text),
        'name' => text,
        _ => text.isEmpty ? null : text,
      };
    }
    for (final entry in _suitability.entries) {
      if (widget.destination == null || entry.value != _initial[entry.key]) {
        payload[entry.key] = entry.value;
      }
    }
    try {
      final saved = widget.destination == null
          ? await widget.api.createDestination(payload)
          : await widget.api.updateDestination(
              widget.destination!['destination_id'].toString(),
              payload,
            );
      if (!mounted) return;
      _initial = current;
      adminHasUnsavedChanges.value = false;
      adminIsSaving.value = false;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      widget.onSaved(saved);
    } catch (error) {
      if (!mounted) return;
      adminIsSaving.value = false;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.destination == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: AdminPage(
        key: PageStorageKey(
          'destination-editor-${widget.destination?['destination_id'] ?? 'new'}',
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _cancel,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(
                    creating ? 'Back to destinations' : 'Back to destination',
                  ),
                ),
                const SizedBox(height: 12),
                AdminPageHeader(
                  title: creating ? 'Add destination' : 'Edit destination',
                  description: creating
                      ? 'Add a place and the information travelers need to plan their visit.'
                      : 'Update ${widget.destination!['name'] ?? 'this destination'} and save your changes.',
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  AdminMessage(
                    icon: Icons.error_outline,
                    title: 'Destination has not been saved',
                    message: _error!,
                    isError: true,
                  ),
                  const SizedBox(height: 16),
                ],
                Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(
                          'Identity & description',
                          'Name is required. Optional information can be left blank.',
                          [
                            _field(
                              'name',
                              'Destination name *',
                              maxLength: 255,
                              validator: _name,
                            ),
                            _pair(
                              _field('district', 'District', maxLength: 255),
                              _field('category', 'Category', maxLength: 500),
                            ),
                            _field('description', 'Description', lines: 4),
                            _field(
                              'vibes',
                              'Vibes',
                              maxLength: 500,
                              helper:
                                  'Descriptive travel atmosphere, such as peaceful or adventurous.',
                            ),
                          ],
                        ),
                        _section(
                          'Location & travel',
                          'Enter geographic coordinates in decimal degrees. Both coordinates are required.',
                          [
                            _field(
                              'location',
                              'Location / address',
                              maxLength: 500,
                            ),
                            _pair(
                              _field(
                                'lat',
                                'Latitude *',
                                numeric: true,
                                validator: (value) =>
                                    _coordinate(value, -90, 90, 'latitude'),
                              ),
                              _field(
                                'lng',
                                'Longitude *',
                                numeric: true,
                                validator: (value) =>
                                    _coordinate(value, -180, 180, 'longitude'),
                              ),
                            ),
                            _pair(
                              _field(
                                'operating_hours',
                                'Operating hours',
                                maxLength: 255,
                              ),
                              _field(
                                'estimated_travel_time',
                                'Estimated travel time',
                              ),
                            ),
                            _field('best_time_to_visit', 'Best time to visit'),
                            _field(
                              'how_to_get_there',
                              'How to get there',
                              lines: 3,
                            ),
                            _field(
                              'transport_accessibility',
                              'Transport accessibility',
                              maxLength: 100,
                            ),
                            _field('travel_notes', 'Travel notes', lines: 3),
                            _field('what_to_bring', 'What to bring', lines: 3),
                          ],
                        ),
                        _section(
                          'Activities & traveler suitability',
                          'Describe activities as text. These are not separately priced activity records.',
                          [
                            _field(
                              'activities',
                              'Activities',
                              lines: 3,
                              helper:
                                  'For example: Hiking, photography, and guided walks.',
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) => Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  for (final entry
                                      in destinationSuitability.entries)
                                    SizedBox(
                                      width: constraints.maxWidth >= 640
                                          ? (constraints.maxWidth - 16) / 2
                                          : constraints.maxWidth,
                                      child: CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(entry.value),
                                        value: _suitability[entry.key],
                                        onChanged: (value) {
                                          setState(
                                            () => _suitability[entry.key] =
                                                value ?? false,
                                          );
                                          _changed();
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _pair(
                              _field(
                                'difficulty_level',
                                'Difficulty level',
                                maxLength: 50,
                              ),
                              _field(
                                'crowd_level',
                                'Crowd level',
                                maxLength: 50,
                              ),
                            ),
                            _field(
                              'stay_duration_type',
                              'Stay duration type',
                              maxLength: 50,
                            ),
                          ],
                        ),
                        _section(
                          'Estimated fees',
                          'Keep estimates separate from the accommodation and transport prices in Market Rates.',
                          [
                            _pair(
                              _field(
                                'estimated_cost',
                                'Estimated cost (PHP)',
                                numeric: true,
                                validator: _cost,
                                helper:
                                    'Leave blank if unknown. Enter 0 only for a known zero cost.',
                              ),
                              _field(
                                'budget_class',
                                'Budget class',
                                maxLength: 50,
                              ),
                            ),
                            _pair(
                              _field(
                                'entrance_fee',
                                'Entrance fee',
                                maxLength: 255,
                                helper:
                                    'Descriptive fee with a unit, such as PHP 150 / person.',
                              ),
                              _field(
                                'overnight_fee',
                                'Overnight fee',
                                maxLength: 255,
                                helper:
                                    'Descriptive fee, such as PHP 2,500 / night.',
                              ),
                            ),
                          ],
                        ),
                        _section(
                          'Image',
                          'Use a publicly accessible image URL. Images are not uploaded from this editor.',
                          [
                            _field(
                              'image_url',
                              'Image URL',
                              maxLength: 2048,
                              validator: _url,
                              helper:
                                  'An http:// or https:// image URL, or leave blank.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AdminPanel(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving || (!creating && !_dirty)
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Saving…' : 'Save destination'),
                      ),
                      OutlinedButton(
                        onPressed: _saving ? null : _cancel,
                        child: const Text('Cancel'),
                      ),
                      Text(
                        _saving
                            ? 'Saving destination…'
                            : _dirty
                            ? 'Unsaved changes'
                            : creating
                            ? 'Complete the required fields to save.'
                            : 'No unsaved changes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String description, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              for (final child in children) ...[
                child,
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      );

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 640) {
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
    },
  );

  Widget _field(
    String key,
    String label, {
    int? maxLength,
    int lines = 1,
    bool numeric = false,
    String? helper,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: _controllers[key],
    maxLines: lines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    validator: (value) {
      if (maxLength != null && (value?.trim().length ?? 0) > maxLength) {
        return 'Use at most $maxLength characters.';
      }
      return validator?.call(value);
    },
  );

  String? _name(String? value) => (value?.trim().length ?? 0) < 2
      ? 'Enter a name with at least two characters.'
      : null;

  String? _coordinate(
    String? value,
    double minimum,
    double maximum,
    String label,
  ) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || !number.isFinite) return 'Enter a valid $label.';
    if (number < minimum || number > maximum) {
      return 'Use a value between $minimum and $maximum.';
    }
    return null;
  }

  String? _cost(String? value) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty && !RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter 0 to 99,999,999.99 with at most two decimal places.';
    }
    return null;
  }

  String? _url(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme)) {
      return 'Enter a complete http:// or https:// image URL.';
    }
    return null;
  }
}
