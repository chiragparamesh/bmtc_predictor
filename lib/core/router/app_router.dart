import 'package:go_router/go_router.dart';

import '../../features/arrival_report/presentation/reports_screen.dart';
import '../../features/schedule/presentation/stop_screen.dart';
import '../../features/schedule/presentation/trip_screen.dart';
import '../../features/stop_search/presentation/home_screen.dart';

class AppRoutes {
  static const home = '/';
  static String stop(String id) => '/stop/$id';
  static const trip = '/trip';
  static const reports = '/reports';
}

GoRouter createRouter() => GoRouter(
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/stop/:id', builder: (_, s) => StopScreen(stopId: s.pathParameters['id']!)),
        GoRoute(path: AppRoutes.trip, builder: (_, s) => TripScreen(args: s.extra as TripArgs?)),
        GoRoute(path: AppRoutes.reports, builder: (_, _) => const ReportsScreen()),
      ],
    );
