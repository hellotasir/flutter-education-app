import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/user/profile_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final _repo = AuthRepository();

  Future<void> logout(BuildContext context) async {
    await AuthRepository().logout();

    if (!context.mounted) return;

    if (_repo.currentSession == null) {
      Navigator.pop(context);
    }
  }

  final authRepo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,

          title: const Text("Edumap"),
          actions: [
            IconButton(
              onPressed: () {
                AppNavigator(screen: ProfileScreen()).navigate(context);
              },
              icon: Icon(Icons.person_rounded),
            ),
          ],
        ),
        body: Text(''),
      ),
    );
  }
}
