from rest_framework.permissions import BasePermission

from .models import Role


class _HasRole(BasePermission):
    roles = ()

    def has_permission(self, request, view):
        return getattr(request.user, 'role', None) in self.roles


class IsCustomer(_HasRole):
    roles = (Role.CUSTOMER,)


class IsGroundOwner(_HasRole):
    roles = (Role.GROUND_OWNER,)


class IsAdminRole(_HasRole):
    roles = (Role.ADMIN,)
