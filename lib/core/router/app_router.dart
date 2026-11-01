import 'package:go_router/go_router.dart';

import '../widgets/skeleton_home.dart';

/// Central route table. Add one GoRoute per feature screen.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SkeletonHome(),
    ),
  ],
);
