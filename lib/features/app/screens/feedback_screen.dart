// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/others/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/constants/messages.dart';
import 'package:flutter_education_app/features/app/models/feedback_model.dart';
import 'package:flutter_education_app/features/app/repositories/feedback_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/others/services/cloud/database_service.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';
import 'package:flutter_education_app/features/app/widgets/snackbar_widget.dart';

enum _SortOrder { newest, oldest, highestRating, lowestRating }

class _FilterState {
  const _FilterState({
    this.query = '',
    this.category = 'all',
    this.minRating = 0,
    this.sortOrder = _SortOrder.newest,
  });

  final String query;
  final String category;
  final int minRating;
  final _SortOrder sortOrder;

  bool get isActive =>
      query.isNotEmpty ||
      category != 'all' ||
      minRating > 0 ||
      sortOrder != _SortOrder.newest;

  _FilterState copyWith({
    String? query,
    String? category,
    int? minRating,
    _SortOrder? sortOrder,
  }) => _FilterState(
    query: query ?? this.query,
    category: category ?? this.category,
    minRating: minRating ?? this.minRating,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(
      screen: FeedbackScreen(authRepository: authRepository),
    ).navigate(context);
  }

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _firestoreService = FirestoreService<FeedbackModel>(
    FeedbackRepository(),
  );
  final _searchCtrl = TextEditingController();

  List<FeedbackModel> _allFeedback = [];
  bool _fetching = true;
  FeedbackModel? _myFeedback;
  _FilterState _filter = const _FilterState();

  static const _categories = [
    ('all', 'All'),
    ('general', 'General'),
    ('bug', 'Bug Report'),
    ('feature', 'Feature Request'),
    ('content', 'Content Issue'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _filter = _filter.copyWith(query: _searchCtrl.text.trim()));
  }

  Future<void> _loadFeedback() async {
    if (mounted) setState(() => _fetching = true);
    try {
      final all = await _firestoreService.getAll(
        query: (col) => col.orderBy('createdAt', descending: true),
      );

      final seen = <String, FeedbackModel>{};
      for (final f in all) {
        if (!seen.containsKey(f.userId)) seen[f.userId] = f;
      }

      final deduped = seen.values.toList();

      final userId = _firestoreService.currentUserId;
      if (mounted) {
        setState(() {
          _allFeedback = deduped;
          _myFeedback = userId != null
              ? deduped.where((f) => f.userId == userId).firstOrNull
              : null;
        });
      }
    } catch (_) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  List<FeedbackModel> get _filtered {
    var list = List<FeedbackModel>.from(_allFeedback);

    if (_filter.category != 'all') {
      list = list.where((f) => f.category == _filter.category).toList();
    }
    if (_filter.minRating > 0) {
      list = list.where((f) => f.rating >= _filter.minRating).toList();
    }
    if (_filter.query.isNotEmpty) {
      final q = _filter.query.toLowerCase();
      list = list
          .where(
            (f) =>
                f.userName.toLowerCase().contains(q) ||
                f.message.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_filter.sortOrder) {
      case _SortOrder.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOrder.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOrder.highestRating:
        list.sort((a, b) {
          final r = b.rating.compareTo(a.rating);
          return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
        });
      case _SortOrder.lowestRating:
        list.sort((a, b) {
          final r = a.rating.compareTo(b.rating);
          return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
        });
    }

    return list;
  }

  void _openForm({FeedbackModel? existing}) {
    try {
      if (existing == null && _myFeedback != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have already submitted feedback. Use Edit to update it.',
            ),
          ),
        );
        return;
      }

      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) => _FeedbackForm(
            service: _firestoreService,
            existing: existing,
            scrollController: scrollController,
          ),
        ),
      ).then((submitted) {
        if (submitted == true) _loadFeedback();
      });
    } catch (e) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    }
  }

  Future<void> _deleteSingle(FeedbackModel feedback) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Feedback'),
          content: const Text(
            'Are you sure you want to delete your submitted feedback?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _firestoreService.deleteByDocId(feedback.id!);
      _loadFeedback();
    } catch (e) {
      SnackbarWidget(message: actionErrorMessage).showSnackbar(context);
    }
  }

  Future<void> _deleteAll() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete ALL Feedback'),
          content: const Text(
            'This will permanently delete every feedback document. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete All'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _firestoreService.deleteCollection();
      _loadFeedback();
    } catch (e) {
      SnackbarWidget(message: actionErrorMessage).showSnackbar(context);
    }
  }

  void _showSortFilter() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _FilterSheet(
          initial: _filter,
          categories: _categories,
          onApply: (updated) => setState(() => _filter = updated),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filter = const _FilterState();
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final currentUserId = _firestoreService.currentUserId;

    final canAdd = !_fetching && _myFeedback == null;

    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          actions: [
            if (canAdd)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (_allFeedback.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete All Feedback',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete_all') _deleteAll();
                },
              ),
          ],
        ),
        body: _fetching
            ? const Center(child: CircularProgressIndicator())
            : _allFeedback.isEmpty
            ? _EmptyState(onAdd: () => _openForm())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search by name or message…',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        onPressed: _searchCtrl.clear,
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Badge(
                            isLabelVisible: _filter.isActive,
                            child: IconButton.outlined(
                              onPressed: _showSortFilter,
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              tooltip: 'Filter & Sort',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _categories.map((c) {
                            final selected = _filter.category == c.$1;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(c.$2),
                                selected: selected,
                                onSelected: (_) => setState(
                                  () => _filter = _filter.copyWith(
                                    category: c.$1,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_filter.isActive)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 16,
                              ),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 24,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _resetFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final feedback = filtered[i];
                        final isOwner = feedback.userId == currentUserId;
                        return _FeedbackTile(
                          feedback: feedback,
                          isOwner: isOwner,
                          onEdit: isOwner
                              ? () => _openForm(existing: feedback)
                              : null,
                          onDelete: isOwner
                              ? () => _deleteSingle(feedback)
                              : null,
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No feedback yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to share your thoughts.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.categories,
    required this.onApply,
  });

  final _FilterState initial;
  final List<(String, String)> categories;
  final ValueChanged<_FilterState> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterState _current;

  static const _sortLabels = {
    _SortOrder.newest: 'Newest First',
    _SortOrder.oldest: 'Oldest First',
    _SortOrder.highestRating: 'Highest Rating',
    _SortOrder.lowestRating: 'Lowest Rating',
  };

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ).copyWith(top: 8, bottom: 4),
            child: Row(
              children: [
                Text(
                  'Filter & Sort',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _current = const _FilterState()),
                  child: const Text('Reset'),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sort By', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _SortOrder.values.map((order) {
                    return ChoiceChip(
                      label: Text(_sortLabels[order]!),
                      selected: _current.sortOrder == order,
                      onSelected: (_) => setState(
                        () => _current = _current.copyWith(sortOrder: order),
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.categories.map((c) {
                    return ChoiceChip(
                      label: Text(c.$2),
                      selected: _current.category == c.$1,
                      onSelected: (_) => setState(
                        () => _current = _current.copyWith(category: c.$1),
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Minimum Rating',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    Text(
                      _current.minRating == 0
                          ? 'Any'
                          : '${_current.minRating}★ & above',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(6, (i) {
                    final selected = _current.minRating == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _current = _current.copyWith(minRating: i),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              i == 0 ? 'All' : '$i★',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: selected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    widget.onApply(_current);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({
    required this.feedback,
    required this.isOwner,
    this.onEdit,
    this.onDelete,
  });

  final FeedbackModel feedback;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const _categoryLabels = {
    'general': 'General',
    'bug': 'Bug Report',
    'feature': 'Feature Request',
    'content': 'Content Issue',
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  (feedback.userName.isNotEmpty ? feedback.userName[0] : '?')
                      .toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            feedback.userName.isNotEmpty
                                ? feedback.userName
                                : 'Anonymous',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'You',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < feedback.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: i < feedback.rating
                                ? Colors.amber
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                          );
                        }),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoryLabels[feedback.category] ??
                                feedback.category,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(feedback.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feedback.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: onEdit,
                            child: Text(
                              'Edit',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: onDelete,
                            child: Text(
                              'Delete',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({
    required this.service,
    this.existing,
    this.scrollController,
  });

  final FirestoreService<FeedbackModel> service;
  final FeedbackModel? existing;
  final ScrollController? scrollController;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  late final TextEditingController _feedbackCtrl;
  late String _category;
  late int _rating;
  bool _loading = false;

  bool _checking = false;
  bool _alreadySubmitted = false;

  static const _categories = [
    ('general', 'General'),
    ('bug', 'Bug Report'),
    ('feature', 'Feature Request'),
    ('content', 'Content Issue'),
  ];

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = TextEditingController(text: widget.existing?.message ?? '');
    _category = widget.existing?.category ?? 'general';
    _rating = widget.existing?.rating ?? 0;

    if (widget.existing == null) _checkDuplicate();
  }

  Future<void> _checkDuplicate() async {
    final userId = widget.service.currentUserId;
    if (userId == null) return;

    setState(() => _checking = true);
    try {
      final results = await widget.service.getAll(
        query: (col) => col.where('userId', isEqualTo: userId).limit(1),
      );
      if (mounted && results.isNotEmpty) {
        setState(() => _alreadySubmitted = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_alreadySubmitted) return;

    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = widget.service.currentUser;
      final meta = user?.userMetadata;
      final userName =
          meta?['full_name'] as String? ??
          meta?['name'] as String? ??
          meta?['display_name'] as String? ??
          meta?['username'] as String? ??
          'Anonymous';

      final model = FeedbackModel(
        userId: user?.id ?? 'anonymous',
        userName: userName,
        category: _category,
        rating: _rating,
        message: text,

        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.existing?.id != null) {
        await widget.service.replace(widget.existing!.id!, model);
      } else {
        final userId = user?.id;
        if (userId != null) {
          final existing = await widget.service.getAll(
            query: (col) => col.where('userId', isEqualTo: userId).limit(1),
          );
          if (existing.isNotEmpty) {
            if (mounted) {
              setState(() {
                _alreadySubmitted = true;
                _loading = false;
              });
            }
            return;
          }
        }
        await widget.service.add(model);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return _FormSheetScaffold(
      title: isEditing ? 'Edit Feedback' : 'New Feedback',
      scrollController: widget.scrollController,
      child: _checking
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : _alreadySubmitted
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Feedback Already Submitted',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have already submitted feedback. To make changes, close this and use the Edit option on your existing entry.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "We'd love to hear from you. Your feedback helps us improve.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Overall Rating',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      ...List.generate(5, (i) {
                        return IconButton(
                          onPressed: () => setState(() => _rating = i + 1),
                          icon: Icon(
                            i < _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < _rating ? Colors.amber : null,
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c.$1;
                      return ChoiceChip(
                        label: Text(c.$2),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = c.$1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _feedbackCtrl,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Your feedback',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText: 'Tell us what you think…',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Update Feedback' : 'Submit Feedback',
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

class _FormSheetScaffold extends StatelessWidget {
  const _FormSheetScaffold({
    required this.title,
    required this.child,
    this.scrollController,
  });

  final String title;
  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline
                ..withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ).copyWith(top: 8, bottom: 4),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );

    if (scrollController != null) {
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: CustomScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverToBoxAdapter(child: child),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [header, child],
    );
  }
}
