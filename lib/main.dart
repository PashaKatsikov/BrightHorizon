import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/profile.dart';
import 'src/screens/boot.dart';
import 'src/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Both orientations while the loading plates are up. The cabinet locks
  // portrait once those plates leave.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final profile = Profile();
  await profile.load();
  runApp(ProfileScope(profile: profile, child: const HorizonApp()));
}

class HorizonApp extends StatelessWidget {
  const HorizonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bright Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          surface: ink,
        ),
        fontFamily: 'Roboto',
        splashFactory: InkSplash.splashFactory,
      ),
      home: const BootPage(),
    );
  }
}
