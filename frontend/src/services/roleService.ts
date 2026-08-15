import axios from 'axios';
import { API_V1 } from '../basePath';

// Types
export interface Role {
  id: string;
  name: string;
  permissions: string[];
  description: string;
}

export interface RoleCreateData {
  name: string;
  permissions: string[];
  description: string;
}

export interface RoleUpdateData {
  name?: string;
  permissions?: string[];
  description?: string;
}

// API base URL
const API_URL = `${API_V1}/roles`;

// Service methods
const roleService = {
  // Get all roles
  getRoles: async (): Promise<Role[]> => {
    try {
      const response = await axios.get(API_URL);
      return response.data;
    } catch (error) {
      // For development, if API isn't ready, return mock data
      if (process.env.NODE_ENV === 'development') {
        return getMockRoles();
      }
      throw error;
    }
  },

  // Get role by ID
  getRoleById: async (id: string): Promise<Role> => {
    try {
      const response = await axios.get(`${API_URL}/${id}`);
      return response.data;
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        const mockRoles = getMockRoles();
        const role = mockRoles.find(r => r.id === id);
        if (role) return role;
      }
      throw error;
    }
  },

  // Create new role
  createRole: async (roleData: RoleCreateData): Promise<Role> => {
    try {
      const response = await axios.post(API_URL, roleData);
      return response.data;
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        // Simulate API response
        return {
          id: `role-${Date.now()}`,
          name: roleData.name,
          permissions: roleData.permissions,
          description: roleData.description
        };
      }
      throw error;
    }
  },

  // Update role
  updateRole: async (id: string, roleData: RoleUpdateData): Promise<Role> => {
    try {
      const response = await axios.put(`${API_URL}/${id}`, roleData);
      return response.data;
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        // Simulate API response with mock data
        return {
          id,
          name: roleData.name || 'Role Name',
          permissions: roleData.permissions || [],
          description: roleData.description || 'Role Description'
        };
      }
      throw error;
    }
  },

  // Delete role
  deleteRole: async (id: string): Promise<void> => {
    try {
      await axios.delete(`${API_URL}/${id}`);
    } catch (error) {
      if (process.env.NODE_ENV !== 'development') {
        throw error;
      }
      // In development, just pretend it worked
    }
  },
};

// Mock data for development
function getMockRoles(): Role[] {
  return [
    {
      id: '1',
      name: 'admin',
      permissions: [
        'utilisateurs:lecture',
        'utilisateurs:ecriture',
        'utilisateurs:suppression',
        'roles:lecture',
        'roles:ecriture',
        'roles:suppression',
        'parametres:lecture',
        'parametres:ecriture',
        'rapports:lecture',
        'rapports:export'
      ],
      description: 'Administrateur système avec tous les droits'
    },
    {
      id: '2',
      name: 'utilisateur',
      permissions: [
        'utilisateurs:lecture',
        'parametres:lecture',
        'rapports:lecture'
      ],
      description: 'Utilisateur standard avec droits limités'
    },
    {
      id: '3',
      name: 'superviseur',
      permissions: [
        'utilisateurs:lecture',
        'parametres:lecture',
        'parametres:ecriture',
        'rapports:lecture',
        'rapports:export'
      ],
      description: 'Superviseur avec droits de rapports étendus'
    }
  ];
}

export default roleService; 