import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Shows child widget only if user has required role
class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (!authProvider.isAuthenticated) {
      return fallback ?? const SizedBox.shrink();
    }
    
    final userRole = authProvider.role?.toLowerCase() ?? '';
    final hasAccess = allowedRoles.any((role) => userRole.contains(role.toLowerCase()));
    
    if (!hasAccess) {
      return fallback ?? const SizedBox.shrink();
    }
    
    return child;
  }
}

/// Shows child only for Admin users (Global + Regional)
class AdminGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const AdminGuard({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (!authProvider.isAuthenticated || !authProvider.isAdmin) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

/// Shows child only for Clergy users (Branch Pastor + Branch Staff)
class ClergyGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const ClergyGuard({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (!authProvider.isAuthenticated || !authProvider.isClergy) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

/// Shows child only for Global Admin
class GlobalAdminGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const GlobalAdminGuard({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    if (!authProvider.isAuthenticated || !authProvider.isGlobalAdmin) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}