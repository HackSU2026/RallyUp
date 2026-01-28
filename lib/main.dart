import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rally_up/provider/chat.dart';
import 'package:rally_up/provider/event.dart';
import 'package:rally_up/provider/history_event.dart';
import 'package:rally_up/provider/match.dart';
import 'package:rally_up/provider/user.dart';
// import 'package:rally_up/widget/auth/level_selection_screen.dart';
import 'package:rally_up/widget/auth/login_screen.dart';
import 'package:rally_up/widget/chat/chat_screen.dart';
import 'package:rally_up/widget/profile/profile_screen.dart';

import 'package:rally_up/widget/profile/update_profile.dart';
import 'firebase_options.dart';
import 'widget/events/event_list.dart';
import 'package:rally_up/widget/events/create_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProfileProvider()..restoreSession(),
        ),
       ChangeNotifierProvider(create: (ctx) => EventProvider()),
       ChangeNotifierProvider(create: (_) => MatchProvider()),
       ChangeNotifierProvider(create: (_) => HistoryEventProvider()),
       ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'RallyUp',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    switch (profile.step) {
      case AuthStep.loggedOut:
      case AuthStep.needsOnboarding:
        return const LoginScreen();
      case AuthStep.ready:
        return const MainScreen();
    }
  }
}

/// Main screen with bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => UpdateProfile()));
              },
            ),
          ],
        );
      case 1:
        return AppBar(
          title: const Text('Events'),
          centerTitle: true,
        );
      case 2:
        // ChatScreen has its own AppBar
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          ProfileScreen(),
          EventListView(),
          ChatScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateEventPage()),
                );
              },
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'RallyBot',
          ),
        ],
      ),
    );
  }
}
