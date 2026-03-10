import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/startup_launch_options.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DecentBenchApp(startupLaunchOptions: parseStartupLaunchOptions(args)));
}
