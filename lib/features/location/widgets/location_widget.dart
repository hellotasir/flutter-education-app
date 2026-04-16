import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/screens/location_screen.dart';
import 'package:flutter_education_app/others/services/cloud/local_service.dart';

class LocationWidget extends StatefulWidget {
  const LocationWidget({
    super.key,
    required this.userId,
    required this.role,
    required this.locationService,
    this.onSaved,
  });

  final String userId;
  final String role;
  final LocationService locationService;
  final void Function(LocationModel)? onSaved;

  @override
  State<LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<LocationWidget> {
  bool _isLoading = false;
  LocationModel? _current;
  String? _error;

  bool get _isInstructor => widget.role == 'instructor';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final loc = await widget.locationService
        .watchCurrentLocation(widget.userId, widget.role)
        .first
        .catchError((_) => null);
    if (mounted) setState(() => _current = loc);
  }

  Future<void> _shareLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final model = await widget.locationService.saveCurrentLocation(
        userId: widget.userId,
        role: widget.role,
      );
      if (mounted) {
        setState(() => _current = model);
        widget.onSaved?.call(model);
        _snack('Location updated', isError: false);
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

  void _openMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: LiveMapScreen(
            currentUserId: widget.userId,
            currentRole: widget.role,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
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
                    'GPS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Used to calculate distance between you and others.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 28),
            if (_current != null) ...[
              _LocationTile(
                icon: Icons.location_on_rounded,
                label: 'Current position',
                address: _current!.address.formattedAddress,
                accuracy: _current!.accuracy,
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'No location shared yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _shareLocation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(
                  _current == null ? 'Share My Location' : 'Refresh Location',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Track Distance'),
              ),
            ),
            if (_isInstructor) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageLocationsScreen(
                        userId: widget.userId,
                        role: widget.role,
                        locationService: widget.locationService,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.home_work_rounded),
                  label: const Text('Manage Saved Addresses'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ManageLocationsScreen extends StatefulWidget {
  const ManageLocationsScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.locationService,
  });

  final String userId;
  final String role;
  final LocationService locationService;

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
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
      await widget.locationService.saveCustomLocation(
        userId: widget.userId,
        role: widget.role,
        rawAddress: address,
        label: _labelCtrl.text.trim().isNotEmpty
            ? _labelCtrl.text.trim()
            : null,
        isVisible: true,
      );
      if (mounted) {
        _addressCtrl.clear();
        _labelCtrl.clear();
        _snack('Address saved');
      }
    } on GeocodingException catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not find address: ${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _addLoading = false);
    }
  }

  Future<void> _setDefault(LocationModel model) async {
    if (model.id == null) return;
    await widget.locationService.setDefaultLocation(
      userId: widget.userId,
      role: widget.role,
      locationId: model.id!,
    );
    _snack('Default address updated');
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
    if (confirm == true && model.id != null) {
      await widget.locationService.deleteCustomLocation(model.id!);
      if (mounted) _snack('Address deleted');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<List<LocationModel>>(
              stream: widget.locationService.watchAllLocations(
                widget.userId,
                widget.role,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final locations = (snapshot.data ?? [])
                    .where((l) => l.type == LocationType.customAddress)
                    .toList();

                if (locations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No saved addresses yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return Column(
                  children: locations
                      .map(
                        (loc) => _SavedAddressTile(
                          location: loc,
                          onSetDefault: () => _setDefault(loc),
                          onDelete: () => _delete(loc),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Add New Address',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
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
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  const _SavedAddressTile({
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
            : theme.colorScheme.surfaceContainerHighest,
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
            Text(
              'Default',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
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
