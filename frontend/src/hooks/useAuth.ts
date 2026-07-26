import { useSelector } from 'react-redux';
import { RootState } from '../store';
import { User } from '../store/slices/authSlice';

export interface UseAuthReturn {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  
  // Permission helpers
  hasAdminAccess: boolean;
  hasOperatorAccess: boolean;
  canAccessSapData: boolean;
  canAccessIfsData: boolean;
  canAccessDashboard: boolean;
  canManageUsers: boolean;
  canAccessConfiguration: boolean;
  
  // Role checks
  isAdmin: boolean;
  isOperator: boolean;
  hasPermission: (permission: string) => boolean;
}

// Helpers pour les permissions
export const hasAdminAccess = (user: User | null): boolean => {
  return user?.role === 'admin';
};

export const hasOperatorAccess = (user: User | null): boolean => {
  return user?.role === 'operator' || user?.role === 'admin';
};

export const canAccessSapData = (user: User | null): boolean => {
  return user?.role === 'admin' || user?.role === 'operator';
};

export const canAccessIfsData = (user: User | null): boolean => {
  return user?.role === 'admin' || user?.role === 'operator';
};

export const canAccessDashboard = (user: User | null): boolean => {
  return user?.role === 'admin' || user?.role === 'operator';
};

export const canManageUsers = (user: User | null): boolean => {
  return user?.role === 'admin';
};

export const canAccessConfiguration = (user: User | null): boolean => {
  return user?.role === 'admin';
};

export const useAuth = (): UseAuthReturn => {
  const { user, isAuthenticated, status, error } = useSelector((state: RootState) => state.auth);
  
  return {
    user,
    isAuthenticated,
    isLoading: status === 'loading',
    error,
    
    // Permission helpers
    hasAdminAccess: hasAdminAccess(user),
    hasOperatorAccess: hasOperatorAccess(user),
    canAccessSapData: canAccessSapData(user),
    canAccessIfsData: canAccessIfsData(user),
    canAccessDashboard: canAccessDashboard(user),
    canManageUsers: canManageUsers(user),
    canAccessConfiguration: canAccessConfiguration(user),
    
    // Role checks
    isAdmin: user?.role === 'admin',
    isOperator: user?.role === 'operator',
    
    // Generic permission check
    hasPermission: (permission: string) => {
      switch (permission) {
        case 'manage_users':
          return canManageUsers(user);
        case 'view_sap_data':
          return canAccessSapData(user);
        case 'view_ifs_data':
          return canAccessIfsData(user);
        case 'configure_system':
          return canAccessConfiguration(user);
        default:
          return false;
      }
    }
  };
}; 