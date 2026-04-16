import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/screens/notification_screen.dart';
import 'package:flutter_education_app/features/location/widgets/location_widget.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/others/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/constants/app_details.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/others/services/cloud/local_service.dart';
import 'package:flutter_education_app/features/chat/widgets/inbox_widget.dart';
import 'package:flutter_education_app/features/profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final ProfileRepository _profileRepository = ProfileRepository();
  final AuthRepository _authRepository = AuthRepository();
  final ChatRepository chatRepository = ChatRepository();

  late final LocationService locationService = LocationService();

  Stream<ProfileModel?>? _profileStream;
  
 

  @override
  void initState() {
    super.initState();
    _initProfileStream();
  }



  void _initProfileStream() {
    final userId = _authRepository.currentUser?.id ?? '';
    final collectionPath = _profileRepository.collectionPath.first;

    _profileStream = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return _profileRepository.fromSnapshot(snapshot.docs.first);
        });
  }

  List<Widget> _studentPages(ProfileModel profile) {
    return [
      InboxWidget(
        currentUserId: profile.userId,
        currentUsername: profile.username,
        currentProfilePhoto: profile.profile.profilePhoto,
        chatRepository: chatRepository,
      ),
      LocationWidget(
        userId: profile.userId,
        locationService: locationService,
        role: profile.currentMode,
      ),
    ];
  }

  List<Widget> _instructorPages(ProfileModel profile) {
    return [
      InboxWidget(
        currentUserId: profile.userId,
        currentUsername: profile.username,
        currentProfilePhoto: profile.profile.profilePhoto,
        chatRepository: chatRepository,
      ),
      LocationWidget(
        userId: profile.userId,
        locationService: locationService,
        role: profile.currentMode,
      ),
    ];
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  String? _profilePhotoUrl(ProfileModel? profile) {
    final url = profile?.profile.profilePhoto;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness != Brightness.light;

    return StreamBuilder<ProfileModel?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Image.asset(
                isLight
                    ? 'assets/edumap-black-transparent-icon.png'
                    : 'assets/edumap-transparent-icon.png',
              ),
            ),
            title: const Text(appName),
            actions: [
              IconButton(
                onPressed: () {
                  AppNavigator(
                    screen: NotificationScreen(
                      currentUserId: profile!.userId,
                      chatRepository:
                          chatRepository, // or however you provide it
                    ),
                  ).navigate(context);
                },
                icon: Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen()),
                  );
                },
                icon: _buildProfileAvatar(isLoading, profile),
              ),
            ],
          ),

          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : profile == null
              ? const Center(child: Text('Profile not found'))
              : (profile.currentMode == 'student'
                    ? _studentPages(profile)[_currentIndex]
                    : _instructorPages(profile)[_currentIndex]),

          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_on_outlined),
                selectedIcon: Icon(Icons.location_on_rounded),
                label: 'Location',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar(bool isLoading, ProfileModel? profile) {
    if (isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final photoUrl = _profilePhotoUrl(profile);

    if (photoUrl != null) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(photoUrl));
    }

    final initial = profile?.username.isNotEmpty == true
        ? profile!.username[0].toUpperCase()
        : null;

    return CircleAvatar(
      radius: 16,
      child: initial != null
          ? Text(initial)
          : const Icon(Icons.person, size: 16),
    );
  }
}
