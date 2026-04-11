import 'package:flutter/widgets.dart';
import 'package:flutter_education_app/features/app/repositories/database_repository.dart';
import 'package:flutter_education_app/others/services/database_service.dart';

class FirestoreProvider<T> extends InheritedWidget {
  FirestoreProvider({
    super.key,
    required FirestoreRepository<T> repository,
    required super.child,
  }) : service = FirestoreService<T>(repository);

  final FirestoreService<T> service;

  static FirestoreService<T> of<T>(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<FirestoreProvider<T>>();
    assert(
      provider != null,
      'No FirestoreProvider<$T> found. Wrap a parent widget with FirestoreProvider<$T>.',
    );
    return provider!.service;
  }

  @override
  bool updateShouldNotify(FirestoreProvider<T> oldWidget) =>
      service != oldWidget.service;
}
