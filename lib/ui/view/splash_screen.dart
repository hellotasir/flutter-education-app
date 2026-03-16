import 'package:flutter/material.dart';
import 'package:flutter_education_app/model/constants/app_details.dart';
import 'package:flutter_education_app/ui/widgets/material_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      title: appName,
      child: Scaffold(
        body: Center(
          child: Text(
            appName,
            style: GoogleFonts.lato(
              textStyle: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      ),
    );
  }
}
