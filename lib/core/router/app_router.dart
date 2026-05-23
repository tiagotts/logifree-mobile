import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/delivery/presentation/deliver_package_screen.dart';
import '../../features/delivery/presentation/return_package_screen.dart';
import '../../features/offline/presentation/pending_operations_screen.dart';
import '../../features/packages/presentation/home_screen.dart';
import '../../features/packages/presentation/identify_recipient_screen.dart';
import '../../features/packages/presentation/package_details_screen.dart';
import '../../features/packages/presentation/packages_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/scan/domain/scan_capture.dart';
import '../../features/scan/presentation/confirm_receipt_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';

/// Rotas do protótipo.
///
/// Sem o prefixo `/c/:slug/` (multi-condomínio) nem guard de autenticação —
/// ambos entram quando a feature de auth real for implementada.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
    GoRoute(
      path: '/scan/confirm',
      builder: (_, state) =>
          ConfirmReceiptScreen(capture: state.extra! as ScanCapture),
    ),
    GoRoute(path: '/packages', builder: (_, _) => const PackagesListScreen()),
    GoRoute(
      path: '/packages/:id',
      builder: (_, state) =>
          PackageDetailsScreen(packageId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/packages/:id/deliver',
      builder: (_, state) =>
          DeliverPackageScreen(packageId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/packages/:id/identify',
      builder: (_, state) =>
          IdentifyRecipientScreen(packageId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/packages/:id/return',
      builder: (_, state) =>
          ReturnPackageScreen(packageId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/pending',
      builder: (_, _) => const PendingOperationsScreen(),
    ),
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
  ],
);
