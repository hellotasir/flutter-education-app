import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/user/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    Center(child: Text("Home")),
    Center(child: Text("Book")),
    Center(child: Text("Course")),
    Center(child: Text("Location")),
    Center(child: Text("Offer")),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text("Edumap"),
        actions: [
          IconButton(
            onPressed: () {
              // Navigate to notification
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: () {
              AppNavigator(screen: ProfileScreen()).navigate(context);
            },
            icon: Icon(Icons.person_2_rounded),
          ),
        ],
      ),

      body: _pages[_currentIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.people_alt_outlined),
      ),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, "Home", 0),
              _navItem(Icons.menu_book, "Book", 1),
              _navItem(Icons.school, "Course", 2),
              _navItem(Icons.location_on, "Location", 3),
              _navItem(Icons.local_offer, "Offer", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? Colors.blue : Colors.grey),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
