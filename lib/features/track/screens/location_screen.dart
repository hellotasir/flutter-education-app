// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        CameraFit,
        PolylineLayer,
        MarkerLayer,
        Marker,
        TileLayer,
        Polyline,
        MapController,
        LatLngBounds,
        InteractionOptions,
        InteractiveFlag,
        MapOptions,
        FlutterMap;
import 'package:latlong2/latlong.dart' as ll;

import 'package:flutter_education_app/features/track/models/local_model.dart';
import 'package:flutter_education_app/others/services/local_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class UserSearchResult {
  const UserSearchResult({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.profilePhoto,
    this.location,
  });

  final String userId;
  final String username;
  final String fullName;
  final String role;
  final String profilePhoto;
  final LocationModel? location;
}

// ─────────────────────────────────────────────────────────────────────────────
// USER SEARCH SERVICE  (searches the `profiles` collection by username)
// ─────────────────────────────────────────────────────────────────────────────

class UserSearchService {
  UserSearchService({
    FirebaseFirestore? firestore,
    LocationService? locationService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _locationService = locationService ?? LocationService();

  final FirebaseFirestore _db;
  final LocationService _locationService;

  /// Searches users whose username starts with [query] (case-insensitive via
  /// Firestore range query trick).
  Future<List<UserSearchResult>> searchByUsername(String query) async {
    if (query.trim().isEmpty) return [];

    final lower = query.trim().toLowerCase();
    final upper = '$lower\uf8ff'; // Unicode sentinel for prefix search

    final snap = await _db
        .collection('profiles')
        .where('username', isGreaterThanOrEqualTo: lower)
        .where('username', isLessThanOrEqualTo: upper)
        .limit(20)
        .get();

    final results = <UserSearchResult>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final userId = data['user_id'] as String? ?? doc.id;

      // Fetch their visible location in parallel
      LocationModel? location;
      try {
        location = await _locationService.getInstructorDefaultLocation(userId);
        location ??= await _db
            .collection('locations')
            .doc('student_$userId')
            .get()
            .then((s) => s.exists ? LocationModel.fromSnapshot(s) : null);
      } catch (_) {}

      final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
      results.add(
        UserSearchResult(
          userId: userId,
          username: data['username'] ?? '',
          fullName: profile['full_name'] ?? '',
          role: data['current_mode'] ?? 'student',
          profilePhoto: profile['profile_photo'] ?? '',
          location: location,
        ),
      );
    }

    return results;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY SCREEN — search bar → results list → map
// ─────────────────────────────────────────────────────────────────────────────

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({
    super.key,
    required this.currentUserId,
    required this.locationService,
  });

  final String currentUserId;
  final LocationService locationService;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  late final UserSearchService _searchService;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<UserSearchResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _searchService = UserSearchService(locationService: widget.locationService);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await _searchService.searchByUsername(query);
      if (mounted) {
        setState(() {
          _results = results;
          _hasSearched = true;
          _isSearching = false;
        });
        _slideController
          ..reset()
          ..forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openMap(UserSearchResult target) {
    _focusNode.unfocus();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DistanceMapScreen(
            currentUserId: widget.currentUserId,
            targetUser: target,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: const Color(0xFF0D0F14),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE MAP',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 10,
                      letterSpacing: 4,
                      color: const Color(0xFF00E5A0).withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Track Distance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Search bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SearchBar(
                controller: _searchCtrl,
                focusNode: _focusNode,
                isSearching: _isSearching,
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                },
              ),
            ),
          ),

          // ── Results ──────────────────────────────────────────────────────
          if (_hasSearched && _results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(query: _searchCtrl.text),
            )
          else if (_results.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return SlideTransition(
                    position: _slideAnim,
                    child: _UserResultCard(
                      result: _results[index],
                      delay: Duration(milliseconds: index * 40),
                      onTap: () => _openMap(_results[index]),
                    ),
                  );
                },
              ),
            )
          else
            SliverFillRemaining(hasScrollBody: false, child: _IdleHint()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTANCE MAP SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DistanceMapScreen extends StatefulWidget {
  const DistanceMapScreen({
    super.key,
    required this.currentUserId,
    required this.targetUser,
    required this.locationService,
  });

  final String currentUserId;
  final UserSearchResult targetUser;
  final LocationService locationService;

  @override
  State<DistanceMapScreen> createState() => _DistanceMapScreenState();
}

class _DistanceMapScreenState extends State<DistanceMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  LocationModel? _myLocation;
  LocationModel? _theirLocation;
  double? _distanceKm;
  bool _loading = true;
  String? _error;
  bool _isUpdatingMyLocation = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  StreamSubscription? _mySub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadLocations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mySub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _loading = true);
    try {
      // Listen live to my location
      _mySub = widget.locationService
          .watchStudentLocation(widget.currentUserId)
          .listen((loc) {
            if (mounted) {
              setState(() => _myLocation = loc);
              _recalculate();
              if (loc != null && _theirLocation != null) _fitBounds();
            }
          });

      // One-shot fetch of target's location (or watch if instructor)
      _theirLocation = widget.targetUser.location;

      // Also try to get a fresher location
      if (widget.targetUser.role == 'instructor') {
        _theirLocation = await widget.locationService
            .getInstructorDefaultLocation(widget.targetUser.userId);
      }

      _recalculate();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
      _fitBounds();
    }
  }

  void _recalculate() {
    if (_myLocation == null || _theirLocation == null) return;
    final km = _haversineKm(
      _myLocation!.coordinates,
      _theirLocation!.coordinates,
    );
    setState(() => _distanceKm = km);
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;

  void _fitBounds() {
    if (_myLocation == null && _theirLocation == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_myLocation != null && _theirLocation != null) {
        final bounds = LatLngBounds(
          ll.LatLng(
            math.min(
              _myLocation!.coordinates.latitude,
              _theirLocation!.coordinates.latitude,
            ),
            math.min(
              _myLocation!.coordinates.longitude,
              _theirLocation!.coordinates.longitude,
            ),
          ),
          ll.LatLng(
            math.max(
              _myLocation!.coordinates.latitude,
              _theirLocation!.coordinates.latitude,
            ),
            math.max(
              _myLocation!.coordinates.longitude,
              _theirLocation!.coordinates.longitude,
            ),
          ),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
        );
      } else {
        final loc = _myLocation ?? _theirLocation;
        if (loc != null) {
          _mapController.move(
            ll.LatLng(loc.coordinates.latitude, loc.coordinates.longitude),
            13,
          );
        }
      }
    });
  }

  Future<void> _refreshMyLocation() async {
    setState(() => _isUpdatingMyLocation = true);
    try {
      final model = await widget.locationService.saveStudentCurrentLocation(
        userId: widget.currentUserId,
      );
      if (mounted) {
        setState(() => _myLocation = model);
        _recalculate();
        _fitBounds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingMyLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5A0)),
            )
          else
            _buildMap(),

          // ── Top gradient + back button ─────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D0F14).withOpacity(0.95),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _MapBackButton(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _RefreshLocationButton(
              isLoading: _isUpdatingMyLocation,
              onTap: _refreshMyLocation,
            ),
          ),

          // ── Bottom info panel ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DistanceInfoPanel(
              targetUser: widget.targetUser,
              myLocation: _myLocation,
              theirLocation: _theirLocation,
              distanceKm: _distanceKm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final myLL = _myLocation != null
        ? ll.LatLng(
            _myLocation!.coordinates.latitude,
            _myLocation!.coordinates.longitude,
          )
        : null;
    final theirLL = _theirLocation != null
        ? ll.LatLng(
            _theirLocation!.coordinates.latitude,
            _theirLocation!.coordinates.longitude,
          )
        : null;

    final center = myLL ?? theirLL ?? const ll.LatLng(23.8103, 90.4125);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Dark tile layer
        TileLayer(
          urlTemplate:
              'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.edumap.app',
        ),

        // Line between the two points
        if (myLL != null && theirLL != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [myLL, theirLL],
                color: const Color(0xFF00E5A0),
                strokeWidth: 2.5,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            if (myLL != null)
              Marker(
                point: myLL,
                width: 60,
                height: 60,
                child: _PulsingMarker(
                  animation: _pulseAnim,
                  color: const Color(0xFF00E5A0),
                  icon: Icons.person_pin_circle_rounded,
                  label: 'You',
                ),
              ),
            if (theirLL != null)
              Marker(
                point: theirLL,
                width: 60,
                height: 60,
                child: _StaticMarker(
                  color: const Color(0xFFFF6B6B),
                  icon: widget.targetUser.role == 'instructor'
                      ? Icons.school_rounded
                      : Icons.person_rounded,
                  label: widget.targetUser.username,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP MARKERS
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({
    required this.animation,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Animation<double> animation;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 42 * animation.value,
                height: 42 * animation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2 * animation.value),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.black, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticMarker extends StatelessWidget {
  const _StaticMarker({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTANCE INFO PANEL (bottom sheet style)
// ─────────────────────────────────────────────────────────────────────────────

class _DistanceInfoPanel extends StatelessWidget {
  const _DistanceInfoPanel({
    required this.targetUser,
    required this.myLocation,
    required this.theirLocation,
    required this.distanceKm,
  });

  final UserSearchResult targetUser;
  final LocationModel? myLocation;
  final LocationModel? theirLocation;
  final double? distanceKm;

  String _formatDistance(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161920),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                _Avatar(
                  photoUrl: targetUser.profilePhoto,
                  role: targetUser.role,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetUser.fullName.isNotEmpty
                            ? targetUser.fullName
                            : '@${targetUser.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${targetUser.username}  ·  ${targetUser.role.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5A0).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E5A0).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatDistance(distanceKm!),
                          style: const TextStyle(
                            color: Color(0xFF00E5A0),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'away',
                          style: TextStyle(
                            color: const Color(0xFF00E5A0).withOpacity(0.6),
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E2128)),
            const SizedBox(height: 12),

            // Address rows
            if (myLocation != null)
              _AddressRow(
                icon: Icons.my_location_rounded,
                color: const Color(0xFF00E5A0),
                label: 'Your location',
                address: myLocation!.address.formattedAddress,
              ),
            if (myLocation != null && theirLocation != null)
              const SizedBox(height: 8),
            if (theirLocation != null)
              _AddressRow(
                icon: targetUser.role == 'instructor'
                    ? Icons.school_rounded
                    : Icons.person_rounded,
                color: const Color(0xFFFF6B6B),
                label: targetUser.role == 'instructor'
                    ? 'Instructor location'
                    : 'Student location',
                address: theirLocation!.address.formattedAddress,
              ),

            if (myLocation == null)
              _WarningRow(
                message:
                    'Your location not found. Tap the refresh button above.',
              ),
            if (theirLocation == null)
              _WarningRow(
                message:
                    '${targetUser.username} has not shared their location yet.',
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SCREEN SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161920),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5A0).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search by username...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
          ),
          prefixIcon: isSearching
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF00E5A0),
                    ),
                  ),
                )
              : const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF00E5A0),
                  size: 22,
                ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _UserResultCard extends StatefulWidget {
  const _UserResultCard({
    required this.result,
    required this.delay,
    required this.onTap,
  });

  final UserSearchResult result;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_UserResultCard> createState() => _UserResultCardState();
}

class _UserResultCardState extends State<_UserResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161920),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              _Avatar(
                photoUrl: widget.result.profilePhoto,
                role: widget.result.role,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.result.fullName.isNotEmpty
                          ? widget.result.fullName
                          : '@${widget.result.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.result.username}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                    if (widget.result.location != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 11,
                              color: const Color(0xFF00E5A0).withOpacity(0.8),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                widget.result.location!.address.city.isNotEmpty
                                    ? widget.result.location!.address.city
                                    : widget
                                          .result
                                          .location!
                                          .address
                                          .formattedAddress,
                                style: TextStyle(
                                  color: const Color(
                                    0xFF00E5A0,
                                  ).withOpacity(0.8),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoleBadge(role: widget.result.role),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.role, this.size = 42});

  final String photoUrl;
  final String role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = role == 'instructor'
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF00E5A0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        image: photoUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
            : null,
      ),
      child: photoUrl.isEmpty
          ? Icon(
              role == 'instructor'
                  ? Icons.school_rounded
                  : Icons.person_rounded,
              color: color,
              size: size * 0.45,
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isInstructor = role == 'instructor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            (isInstructor ? const Color(0xFFFF6B6B) : const Color(0xFF00E5A0))
                .withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              (isInstructor ? const Color(0xFFFF6B6B) : const Color(0xFF00E5A0))
                  .withOpacity(0.4),
        ),
      ),
      child: Text(
        isInstructor ? 'TUTOR' : 'STUDENT',
        style: TextStyle(
          color: isInstructor
              ? const Color(0xFFFF6B6B)
              : const Color(0xFF00E5A0),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MapBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF161920),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _RefreshLocationButton extends StatelessWidget {
  const _RefreshLocationButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF161920),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00E5A0).withOpacity(0.4)),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5A0),
                ),
              )
            : const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF00E5A0),
                size: 18,
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found for "$query"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5A0).withOpacity(0.08),
              border: Border.all(
                color: const Color(0xFF00E5A0).withOpacity(0.2),
              ),
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: Color(0xFF00E5A0),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Find someone',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by username to see their\nlocation and distance from you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
