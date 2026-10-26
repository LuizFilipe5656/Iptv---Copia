
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/permission_service.dart';

class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final List<String>? fallbackPermissions;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.fallbackPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    if (permissionService == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (permissionService.hasPermission(permission)) {
      return child;
    }

    if (fallbackPermissions != null &&
        permissionService.hasAnyPermission(fallbackPermissions!)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Exige todas as permissões informadas.
class AllPermissionsGuard extends StatelessWidget {
  final List<String> permissions;
  final Widget child;
  final Widget? fallback;

  const AllPermissionsGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    if (permissionService == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (permissionService.hasAllPermissions(permissions)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Exige pelo menos uma das permissões informadas.
class AnyPermissionGuard extends StatelessWidget {
  final List<String> permissions;
  final Widget child;
  final Widget? fallback;

  const AnyPermissionGuard({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    if (permissionService == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (permissionService.hasAnyPermission(permissions)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Verifica o cargo do usuário.
class RoleGuard extends StatelessWidget {
  final String role;
  final Widget child;
  final Widget? fallback;
  final List<String>? fallbackRoles;

  const RoleGuard({
    super.key,
    required this.role,
    required this.child,
    this.fallback,
    this.fallbackRoles,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    if (permissionService == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (permissionService.hasRole(role)) {
      return child;
    }

    if (fallbackRoles != null &&
        fallbackRoles!.any(permissionService.hasRole)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Verifica se o usuário está ativo.
class ActiveUserGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onInactive;

  const ActiveUserGuard({
    super.key,
    required this.child,
    this.fallback,
    this.onInactive,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    if (permissionService == null) {
      return fallback ?? const SizedBox.shrink();
    }

    if (permissionService.isUserActive) {
      return child;
    }

    if (onInactive != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onInactive!();
      });
    }

    return fallback ?? const SizedBox.shrink();
  }
}

// Botão protegido por permissão.
class PermissionButton extends StatelessWidget {
  final String permission;
  final VoidCallback onPressed;
  final Widget child;
  final List<String>? fallbackPermissions;
  final ButtonStyle? style;

  const PermissionButton({
    super.key,
    required this.permission,
    required this.onPressed,
    required this.child,
    this.fallbackPermissions,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    final hasPermission = permissionService != null &&
        (permissionService.hasPermission(permission) ||
            (fallbackPermissions != null &&
                permissionService.hasAnyPermission(
                  fallbackPermissions!,
                )));

    return ElevatedButton(
      onPressed: hasPermission ? onPressed : null,
      style: style,
      child: child,
    );
  }
}

// Botão de ícone protegido por permissão.
class PermissionIconButton extends StatelessWidget {
  final String permission;
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final List<String>? fallbackPermissions;
  final Color? color;

  const PermissionIconButton({
    super.key,
    required this.permission,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.fallbackPermissions,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final permissionService =
        Provider.of<PermissionService?>(context);

    final hasPermission = permissionService != null &&
        (permissionService.hasPermission(permission) ||
            (fallbackPermissions != null &&
                permissionService.hasAnyPermission(
                  fallbackPermissions!,
                )));

    return IconButton(
      onPressed: hasPermission ? onPressed : null,
      icon: Icon(
        icon,
        color: hasPermission ? color : Colors.grey,
      ),
      tooltip: hasPermission ? tooltip : null,
    );
  }
}
