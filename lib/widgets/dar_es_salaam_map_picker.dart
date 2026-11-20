import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap picker centered on Dar es Salaam. Users can search for a
/// place by name or tap the map to place the pin.
class DarEsSalaamMapPicker extends StatefulWidget {
  const DarEsSalaamMapPicker({
    super.key,
    this.initialPosition,
    this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  static const darEsSalaam = LatLng(-6.7924, 39.2083);
  static final _bounds = LatLngBounds(
    LatLng(-8.25, 38.25),
    LatLng(-5.65, 40.75),
  );

  final LatLng? initialPosition;
  final ValueChanged<LatLng>? onChanged;
  final bool enabled;
  final String? errorText;

  @override
  State<DarEsSalaamMapPicker> createState() => _DarEsSalaamMapPickerState();
}

class _DarEsSalaamMapPickerState extends State<DarEsSalaamMapPicker> {
  static const _searchEndpoint = 'https://nominatim.openstreetmap.org/search';
  static const _viewbox = '38.25,-8.25,40.75,-5.65';
  static DateTime? _lastSearchAt;
  static final Map<String, List<_PlaceResult>> _searchCache = {};
  static final Dio _geocoder = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {'User-Agent': 'ODS-App/1.0 (com.ods.ods_app)'},
  ));

  final _mapController = MapController();
  final _searchController = TextEditingController();
  List<_PlaceResult> _results = const [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (!widget.enabled || _isSearching) return;
    if (query.length < 3) {
      setState(() => _searchError = 'Enter at least 3 characters to search.');
      return;
    }

    final cacheKey = query.toLowerCase();
    final cachedResults = _searchCache[cacheKey];
    if (cachedResults != null) {
      setState(() {
        _results = cachedResults;
        _searchError = cachedResults.isEmpty ? 'No places found. Try another name.' : null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _results = const [];
    });

    try {
      // Nominatim's public service allows at most one request per second.
      final previousSearch = _lastSearchAt;
      if (previousSearch != null) {
        final elapsed = DateTime.now().difference(previousSearch);
        if (elapsed < const Duration(seconds: 1)) {
          await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
        }
      }
      _lastSearchAt = DateTime.now();

      final response = await _geocoder.get<List<dynamic>>(
        _searchEndpoint,
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': 8,
          'countrycodes': 'tz',
          'viewbox': _viewbox,
          'bounded': 1,
          'accept-language': 'en',
        },
      );

      final places = (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_PlaceResult.fromJson)
          .where((place) => place != null)
          .cast<_PlaceResult>()
          .toList(growable: false);
      _searchCache[cacheKey] = places;

      if (!mounted) return;
      setState(() {
        _results = places;
        _searchError = places.isEmpty ? 'No places found. Try another name.' : null;
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _searchError = 'Search is unavailable. Check your connection and try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchError = 'Could not read search results. Please try again.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectPlace(_PlaceResult place, FormFieldState<LatLng> field) {
    final point = place.point;
    field.didChange(point);
    widget.onChanged?.call(point);
    _mapController.move(point, 16);
    setState(() {
      _searchController.text = place.name;
      _results = const [];
      _searchError = null;
    });
  }

  @override
  Widget build(BuildContext context) => FormField<LatLng>(
        initialValue: widget.initialPosition,
        validator: (value) => widget.errorText ??
            (value == null ? 'Select a location on the map.' : null),
        builder: (field) {
          final selected = field.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select location',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by place name or tap the map. Map data © OpenStreetMap contributors.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      enabled: widget.enabled && !_isSearching,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchPlaces(),
                      onChanged: (_) {
                        if (_searchError != null) {
                          setState(() => _searchError = null);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Search place or address',
                        hintText: 'e.g. Kariakoo Market',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: widget.enabled && !_isSearching
                          ? _searchPlaces
                          : null,
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Search'),
                    ),
                  ),
                ],
              ),
              if (_searchError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _searchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_results.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Column(
                    children: [
                      for (final place in _results)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: widget.enabled ? () => _selectPlace(place, field) : null,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 360,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter:
                              selected ?? DarEsSalaamMapPicker.darEsSalaam,
                          initialZoom: selected == null ? 11 : 14,
                          minZoom: 8,
                          maxZoom: 18,
                          cameraConstraint: CameraConstraint.contain(
                            bounds: DarEsSalaamMapPicker._bounds,
                          ),
                          onTap: widget.enabled
                              ? (_, point) {
                                  field.didChange(point);
                                  widget.onChanged?.call(point);
                                  _searchController.clear();
                                  setState(() {
                                    _results = const [];
                                    _searchError = null;
                                  });
                                }
                              : null,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.ods.ods_app',
                          ),
                          if (selected != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: selected,
                                  width: 48,
                                  height: 56,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (!widget.enabled)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withOpacity(0.15),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                ),
              ],
              if (field.errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  field.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _PlaceResult {
  const _PlaceResult({required this.name, required this.point});

  final String name;
  final LatLng point;

  static _PlaceResult? fromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse(json['lat']?.toString() ?? '');
    final longitude = double.tryParse(json['lon']?.toString() ?? '');
    final name = json['display_name'] as String?;
    if (latitude == null || longitude == null || name == null) return null;
    return _PlaceResult(name: name, point: LatLng(latitude, longitude));
  }
}
