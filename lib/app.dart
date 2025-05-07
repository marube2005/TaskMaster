import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/splash/splash_screen.dart';
import 'package:myapp/screens/auth/login_screen.dart';
import 'package:myapp/screens/auth/signup_screen.dart';
import 'package:myapp/screens/home/home_screen.dart';
import 'package:myapp/screens/tasks/tasks_screen.dart';
import 'package:myapp/screens/chatbot/chatbot_screen.dart';
import 'package:myapp/screens/settings/settings_screen.dart';
import 'package:myapp/screens/insights/insights.dart';
import 'package:myapp/widgets/bottom_navbar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upgraded To-Do App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const Scaffold(
          body: Center(child: Text('Route not found')),
        ),
      ),
    );
  }
}

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String home = '/home'; // Changed from '/' to '/home' to match login_screen.dart
  static const String tasks = '/tasks';
  static const String chatbot = '/chatbot';
  static const String insights = '/insights';
  static const String settings = '/settings';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignUpScreen(),
    home: (_) => const HomePage(),
    tasks: (_) =>  TasksPage(),
    chatbot: (_) => ProfilePage(),
    insights: (_) => const InsightPage(),
    settings: (_) => SettingsPage(),
  };

  static const List<String> bottomNavRoutes = [
    home,
    tasks,
    chatbot,
    insights,
    settings,
  ];
}

class NavigationService {
  static void push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  static void pushReplacement(BuildContext context, String routeName) {
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  static void pushAndRemoveUntil(BuildContext context, String routeName) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
    );
  }

  static void pop(BuildContext context) {
    Navigator.of(context).pop();
  }

  static void navigateToBottomNavPage(BuildContext context, int index) {
    if (index >= 0 && index < AppRoutes.bottomNavRoutes.length) {
      pushReplacement(context, AppRoutes.bottomNavRoutes[index]);
    }
  }

  static void navigateToSplash(BuildContext context) {
    push(context, AppRoutes.splash);
  }

  static void navigateToLogin(BuildContext context) {
    push(context, AppRoutes.login);
  }

  static void navigateToSignUp(BuildContext context) {
    push(context, AppRoutes.signup);
  }

  static void navigateToMain(BuildContext context) {
    pushAndRemoveUntil(context, AppRoutes.main);
  }

  static void navigateToHome(BuildContext context) {
    pushReplacement(context, AppRoutes.home);
  }

  static void navigateToTasks(BuildContext context) {
    pushReplacement(context, AppRoutes.tasks);
  }

  static void navigateToChatbot(BuildContext context) {
    pushReplacement(context, AppRoutes.chatbot);
  }

  static void navigateToInsights(BuildContext context) {
    pushReplacement(context, AppRoutes.insights);
  }

  static void navigateToSettings(BuildContext context) {
    pushReplacement(context, AppRoutes.settings);
  }

  static void replaceWithMain(BuildContext context) {
    pushAndRemoveUntil(context, AppRoutes.main);
  }

  static void replaceWithLogin(BuildContext context) {
    pushAndRemoveUntil(context, AppRoutes.login);
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.navigateToHome(context);
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      NavigationService.navigateToBottomNavPage(context, index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        key: GlobalKey<NavigatorState>(),
        initialRoute: AppRoutes.home,
        onGenerateRoute: (settings) {
          WidgetBuilder? builder = AppRoutes.routes[settings.name];
          if (builder != null) {
            return MaterialPageRoute(builder: builder, settings: settings);
          }
          return null;
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}