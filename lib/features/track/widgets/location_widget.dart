import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_education_app/features/track/models/local_model.dart';
import 'package:flutter_education_app/others/services/local_service.dart';
import 'package:flutter_education_app/features/track/screens/location_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT WIDGET — can only upload current GPS location
// ─────────────────────────────────────────────────────────────────────────────

class StudentLocationWidget extends StatefulWidget {
  const StudentLocationWidget({
    super.key,
    required this.userId,
    required this.locationService,
    this.onSaved,
  });

  final String userId;
  final LocationService locationService;
  final void Function(LocationModel)? onSaved;

  @override
  State<StudentLocationWidget> createState() => _StudentLocationWidgetState();
}

class _StudentLocationWidgetState extends State<StudentLocationWidget> {
  bool _isLoading = false;
  LocationModel? _saved;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final loc = await widget.locationService
        .watchStudentLocation(widget.userId)
        .first
        .catchError((_) => null);
    if (mounted) setState(() => _saved = loc);
  }

  Future<void> _updateLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final model = await widget.locationService.saveStudentCurrentLocation(
        userId: widget.userId,
      );
      if (mounted) {
        setState(() => _saved = model);
        widget.onSaved?.call(model);
        _showSnack('Location updated ✓', isError: false);
      }
    } on LocationPermissionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LocationServiceDisabledException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openLiveMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: LiveMapScreen(
            currentUserId: widget.userId,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'My Location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'GPS only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your location is used to measure distance to instructors.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 28),

            // ── Saved location ────────────────────────────────────────────
            if (_saved != null) ...[
              _LocationTile(
                icon: Icons.location_on_rounded,
                label: 'Current position',
                address: _saved!.address.formattedAddress,
                accuracy: _saved!.accuracy,
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'No location saved yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],

            // ── Actions ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _updateLocation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(
                  _saved == null ? 'Share My Location' : 'Refresh Location',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openLiveMap,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Open Live Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTRUCTOR WIDGET — GPS current location + custom addresses
// ─────────────────────────────────────────────────────────────────────────────

class InstructorLocationWidget extends StatefulWidget {
  const InstructorLocationWidget({
    super.key,
    required this.userId,
    required this.locationService,
  });

  final String userId;
  final LocationService locationService;

  @override
  State<InstructorLocationWidget> createState() =>
      _InstructorLocationWidgetState();
}

class _InstructorLocationWidgetState extends State<InstructorLocationWidget> {
  bool _gpsLoading = false;
  bool _addLoading = false;
  String? _error;

  final _addressCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _addressCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _saveGpsLocation() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      await widget.locationService.saveInstructorCurrentLocation(
        userId: widget.userId,
        isVisible: true,
      );
      if (mounted) _showSnack('GPS location updated ✓', isError: false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Custom address ────────────────────────────────────────────────────────

  Future<void> _addCustomAddress() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter an address.');
      return;
    }
    setState(() {
      _addLoading = true;
      _error = null;
    });
    try {
      await widget.locationService.saveInstructorCustomAddress(
        userId: widget.userId,
        rawAddress: address,
        label: _labelCtrl.text.trim().isNotEmpty
            ? _labelCtrl.text.trim()
            : null,
        isDefault: false,
        isVisible: true,
      );
      if (mounted) {
        _addressCtrl.clear();
        _labelCtrl.clear();
        _showSnack('Address saved ✓', isError: false);
      }
    } on GeocodingException catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not geocode address: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _addLoading = false);
    }
  }

  Future<void> _setDefault(LocationModel model) async {
    if (model.id == null) return;
    await widget.locationService.setDefaultAddress(
      userId: widget.userId,
      locationId: model.id!,
    );
    _showSnack('Default address updated ✓', isError: false);
  }

  Future<void> _delete(LocationModel model) async {
    if (model.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(model.label ?? model.address.formattedAddress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.locationService.deleteInstructorCustomAddress(model.id!);
      if (mounted) _showSnack('Address deleted', isError: false);
    }
  }

  void _openLiveMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: LiveMapScreen(
            currentUserId: widget.userId,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── GPS section ──────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.gps_fixed_rounded,
            title: 'Current Location (GPS)',
            subtitle:
                'Auto-detected from your device. Students use this to '
                'estimate travel distance.',
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _gpsLoading ? null : _saveGpsLocation,
                    icon: _gpsLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('Update GPS Location'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openLiveMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open Live Map'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Custom addresses list ─────────────────────────────────────────
          _SectionCard(
            icon: Icons.home_work_rounded,
            title: 'Saved Addresses',
            subtitle:
                'Add your studio, home, or any teaching venue. '
                'Visible to students.',
            child: StreamBuilder<List<LocationModel>>(
              stream: widget.locationService.watchInstructorLocations(
                widget.userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final locations = (snapshot.data ?? [])
                    .where((l) => l.type == LocationType.customAddress)
                    .toList();

                if (locations.isEmpty) {
                  return Text(
                    'No custom addresses yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: locations
                      .map(
                        (loc) => _InstructorAddressTile(
                          location: loc,
                          onSetDefault: () => _setDefault(loc),
                          onDelete: () => _delete(loc),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Add custom address form ───────────────────────────────────────
          _SectionCard(
            icon: Icons.add_location_alt_rounded,
            title: 'Add Custom Address',
            subtitle: 'Enter a full address to be geocoded via Google Maps.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label (optional)',
                    hintText: 'e.g. Home, Studio',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    hintText: 'e.g. 221B Baker Street, London',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomAddress(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addLoading ? null : _addCustomAddress,
                    icon: _addLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Save Address'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT VIEW — see instructor's address + distance + live map button
// ─────────────────────────────────────────────────────────────────────────────

class InstructorAddressStudentView extends StatefulWidget {
  const InstructorAddressStudentView({
    super.key,
    required this.studentUserId,
    required this.instructorUserId,
    required this.locationService,
  });

  final String studentUserId;
  final String instructorUserId;
  final LocationService locationService;

  @override
  State<InstructorAddressStudentView> createState() =>
      _InstructorAddressStudentViewState();
}

class _InstructorAddressStudentViewState
    extends State<InstructorAddressStudentView> {
  late Future<({LocationModel? location, double? distanceKm})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({LocationModel? location, double? distanceKm})> _load() async {
    final location = await widget.locationService.getInstructorDefaultLocation(
      widget.instructorUserId,
    );
    final distanceKm = await widget.locationService.distanceToInstructor(
      studentUserId: widget.studentUserId,
      instructorUserId: widget.instructorUserId,
    );
    return (location: location, distanceKm: distanceKm);
  }

  void _openLiveMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: LiveMapScreen(
            currentUserId: widget.studentUserId,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<({LocationModel? location, double? distanceKm})>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        final location = data?.location;

        if (location == null) {
          return const Center(
            child: Text('Instructor has not set a location yet.'),
          );
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Instructor Location',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── Location tile ─────────────────────────────────────────
                _LocationTile(
                  icon: location.type == LocationType.customAddress
                      ? Icons.home_work_rounded
                      : Icons.gps_fixed_rounded,
                  label:
                      location.label ??
                      (location.type == LocationType.customAddress
                          ? 'Studio address'
                          : 'Current location'),
                  address: location.address.formattedAddress,
                ),

                // ── Distance ──────────────────────────────────────────────
                if (data?.distanceKm != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${data!.distanceKm!.toStringAsFixed(1)} km from you',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // ── Live map button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openLiveMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open Live Map'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.label,
    required this.address,
    this.accuracy,
  });

  final IconData icon;
  final String label;
  final String address;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(address, style: theme.textTheme.bodyMedium),
              if (accuracy != null)
                Text(
                  '±${accuracy!.toStringAsFixed(0)} m accuracy',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InstructorAddressTile extends StatelessWidget {
  const _InstructorAddressTile({
    required this.location,
    required this.onSetDefault,
    required this.onDelete,
  });

  final LocationModel location;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: location.isDefault
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceVariant,
        child: Icon(
          Icons.location_on_rounded,
          color: location.isDefault
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        location.label ?? 'Address',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.address.formattedAddress,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (location.isDefault)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Default (shown to students)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!location.isDefault)
            IconButton(
              icon: const Icon(Icons.star_outline_rounded),
              tooltip: 'Set as default',
              onPressed: onSetDefault,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
