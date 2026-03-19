import 'package:flutter/material.dart';
import 'package:flutter_education_app/model/repositories/auth_repository.dart';
import 'package:flutter_education_app/ui/widgets/material_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await AuthRepository().logout();

    if (!context.mounted) return;

    if (AuthRepository().currentSession == null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Home"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => logout(context),
            ),
          ],
        ),
        body: Center(
          child: Text(
            "Logged in as\n${user?.email}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
