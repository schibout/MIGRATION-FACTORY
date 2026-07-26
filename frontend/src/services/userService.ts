import api from './api';

// Types
export interface User {
  id: string;
  username: string;
  email: string;
  is_active: boolean;
  created_at: string | null;
  last_login: string | null;
  role?: string;
}

export interface UserCreateData {
  username: string;
  email: string;
  password: string;
  role?: string;
}

export interface UserUpdateData {
  username?: string;
  email?: string;
  is_active?: boolean;
  role?: string;
}

export interface PasswordChangeData {
  userId: string;
  newPassword: string;
}

// API base URL
const API_URL = '/users';

// Mode développement - utiliser les données réelles du backend
// Mettre à true pour utiliser des données fictives
const ALWAYS_USE_MOCK = false;

// Service methods
const userService = {
  // Get all users
  getUsers: async (): Promise<User[]> => {
    // En mode développement, utiliser directement les données fictives
    if (ALWAYS_USE_MOCK) {
      console.log('Mode développement: utilisation des données fictives pour getUsers');
      return getMockUsers();
    }

    try {
      const response = await api.get(API_URL);
      console.log('Données réelles récupérées du backend:', response.data);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des utilisateurs:', error);
      // Fallback aux données fictives en cas d'erreur
      console.log('Utilisation des données fictives suite à une erreur');
      return getMockUsers();
    }
  },

  // Get user by ID
  getUserById: async (id: string): Promise<User> => {
    // En mode développement, utiliser directement les données fictives
    if (ALWAYS_USE_MOCK) {
      console.log(`Mode développement: utilisation des données fictives pour getUserById(${id})`);
      const mockUsers = getMockUsers();
      const user = mockUsers.find(u => u.id === id);
      if (user) return user;
      throw new Error('Utilisateur non trouvé');
    }
    
    try {
      const response = await api.get(`${API_URL}/${id}`);
      console.log(`Données de l'utilisateur ${id} récupérées du backend:`, response.data);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération de l'utilisateur ${id}:`, error);
      // Fallback aux données fictives en cas d'erreur
      console.log('Utilisation des données fictives suite à une erreur');
      const mockUsers = getMockUsers();
      const user = mockUsers.find(u => u.id === id);
      if (user) return user;
      throw error;
    }
  },

  // Create new user
  createUser: async (userData: UserCreateData): Promise<User> => {
    // En mode développement, simuler la création
    if (ALWAYS_USE_MOCK) {
      console.log('Mode développement: simulation de création d\'utilisateur');
      const newUser = {
        id: `user-${Date.now()}`,
        username: userData.username,
        email: userData.email,
        is_active: true,
        created_at: new Date().toISOString(),
        last_login: null,
        role: userData.role || 'user'
      };
      
      // Ajouter l'utilisateur aux données de session pour la persistance temporaire
      const mockUsers = JSON.parse(sessionStorage.getItem('mockUsers') || JSON.stringify(getMockUsers()));
      mockUsers.push(newUser);
      sessionStorage.setItem('mockUsers', JSON.stringify(mockUsers));
      
      return newUser;
    }
    
    try {
      console.log('Envoi des données pour création d\'utilisateur:', userData);
      const response = await api.post(API_URL, userData);
      console.log('Utilisateur créé avec succès:', response.data);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la création de l\'utilisateur:', error);
      
      // Notifier l'erreur mais quand même simuler une réponse pour le développement
      alert(`Erreur lors de la création de l'utilisateur: ${error}`);
      
      // Simulate API response
      return {
        id: `user-${Date.now()}`,
        username: userData.username,
        email: userData.email,
        is_active: true,
        created_at: new Date().toISOString(),
        last_login: null,
        role: userData.role || 'user'
      };
    }
  },

  // Update user
  updateUser: async (id: string, userData: UserUpdateData): Promise<User> => {
    // En mode développement, simuler la mise à jour
    if (ALWAYS_USE_MOCK) {
      console.log(`Mode développement: simulation de mise à jour d'utilisateur ${id}`);
      
      // Récupérer les utilisateurs du stockage de session ou utiliser les valeurs par défaut
      const mockUsers = JSON.parse(sessionStorage.getItem('mockUsers') || JSON.stringify(getMockUsers()));
      const userIndex = mockUsers.findIndex((u: User) => u.id === id);
      
      if (userIndex === -1) {
        throw new Error('Utilisateur non trouvé');
      }
      
      // Mettre à jour les propriétés de l'utilisateur
      mockUsers[userIndex] = {
        ...mockUsers[userIndex],
        ...userData,
      };
      
      // Sauvegarder les modifications
      sessionStorage.setItem('mockUsers', JSON.stringify(mockUsers));
      
      return mockUsers[userIndex];
    }
    
    try {
      console.log(`Envoi des données pour mise à jour de l'utilisateur ${id}:`, userData);
      const response = await api.put(`${API_URL}/${id}`, userData);
      console.log('Utilisateur mis à jour avec succès:', response.data);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour de l'utilisateur ${id}:`, error);
      
      // Notifier l'erreur mais quand même simuler une réponse pour le développement
      alert(`Erreur lors de la mise à jour de l'utilisateur: ${error}`);
      
      // Simulate API response with mock data
      return {
        id,
        username: userData.username || 'user.name',
        email: userData.email || 'user@example.com',
        is_active: userData.is_active !== undefined ? userData.is_active : true,
        created_at: new Date().toISOString(),
        last_login: null,
        role: userData.role || 'user'
      };
    }
  },

  // Delete user
  deleteUser: async (id: string): Promise<void> => {
    // En mode développement, simuler la suppression
    if (ALWAYS_USE_MOCK) {
      console.log(`Mode développement: simulation de suppression d'utilisateur ${id}`);
      
      // Récupérer les utilisateurs du stockage de session ou utiliser les valeurs par défaut
      const mockUsers = JSON.parse(sessionStorage.getItem('mockUsers') || JSON.stringify(getMockUsers()));
      const updatedUsers = mockUsers.filter((u: User) => u.id !== id);
      
      // Sauvegarder les modifications
      sessionStorage.setItem('mockUsers', JSON.stringify(updatedUsers));
      
      return;
    }
    
    try {
      console.log(`Suppression de l'utilisateur ${id}`);
      await api.delete(`${API_URL}/${id}`);
      console.log(`Utilisateur ${id} supprimé avec succès`);
    } catch (error) {
      console.error(`Erreur lors de la suppression de l'utilisateur ${id}:`, error);
      // Notifier l'erreur
      alert(`Erreur lors de la suppression de l'utilisateur: ${error}`);
    }
  },

  // Reset user password
  resetPassword: async (data: PasswordChangeData): Promise<void> => {
    // En mode développement, simuler la réinitialisation
    if (ALWAYS_USE_MOCK) {
      console.log(`Mode développement: simulation de réinitialisation de mot de passe pour ${data.userId}`);
      return;
    }
    
    try {
      console.log(`Réinitialisation du mot de passe pour l'utilisateur ${data.userId}`);
      await api.post(`${API_URL}/${data.userId}/reset-password`, { 
        newPassword: data.newPassword 
      });
      console.log(`Mot de passe réinitialisé avec succès pour l'utilisateur ${data.userId}`);
    } catch (error) {
      console.error(`Erreur lors de la réinitialisation du mot de passe pour l'utilisateur ${data.userId}:`, error);
      // Notifier l'erreur
      alert(`Erreur lors de la réinitialisation du mot de passe: ${error}`);
    }
  },

  // Change user active status
  toggleActive: async (id: string, isActive: boolean): Promise<User> => {
    // En mode développement, simuler le changement de statut
    if (ALWAYS_USE_MOCK) {
      console.log(`Mode développement: simulation de changement de statut pour l'utilisateur ${id}`);
      
      // Récupérer les utilisateurs du stockage de session ou utiliser les valeurs par défaut
      const mockUsers = JSON.parse(sessionStorage.getItem('mockUsers') || JSON.stringify(getMockUsers()));
      const userIndex = mockUsers.findIndex((u: User) => u.id === id);
      
      if (userIndex === -1) {
        throw new Error('Utilisateur non trouvé');
      }
      
      // Mettre à jour le statut
      mockUsers[userIndex].is_active = isActive;
      
      // Sauvegarder les modifications
      sessionStorage.setItem('mockUsers', JSON.stringify(mockUsers));
      
      return mockUsers[userIndex];
    }
    
    try {
      console.log(`Changement de statut pour l'utilisateur ${id} à ${isActive ? 'actif' : 'inactif'}`);
      const response = await api.patch(`${API_URL}/${id}/status`, { is_active: isActive });
      console.log(`Statut modifié avec succès pour l'utilisateur ${id}:`, response.data);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors du changement de statut de l'utilisateur ${id}:`, error);
      
      // Notifier l'erreur
      alert(`Erreur lors du changement de statut de l'utilisateur: ${error}`);
      
      // Simulate API response with mock data
      return {
        id,
        username: 'user.name',
        email: 'user@example.com',
        is_active: isActive,
        created_at: new Date().toISOString(),
        last_login: null,
        role: 'user'
      };
    }
  },
};

// Mock data for development
function getMockUsers(): User[] {
  // Récupérer les utilisateurs du stockage de session si disponible
  const storedUsers = sessionStorage.getItem('mockUsers');
  if (storedUsers) {
    return JSON.parse(storedUsers);
  }
  
  // Sinon, retourner les utilisateurs par défaut
  const defaultUsers = [
    {
      id: '1',
      username: 'admin',
      email: 'admin@example.com',
      is_active: true,
      created_at: '2023-01-01T00:00:00Z',
      last_login: '2023-06-15T08:30:00Z',
      role: 'admin'
    },
    {
      id: '2',
      username: 'user1',
      email: 'user1@example.com',
      is_active: true,
      created_at: '2023-02-15T00:00:00Z',
      last_login: '2023-06-10T14:20:00Z',
      role: 'user'
    },
    {
      id: '3',
      username: 'user2',
      email: 'user2@example.com',
      is_active: false,
      created_at: '2023-03-20T00:00:00Z',
      last_login: '2023-05-05T11:45:00Z',
      role: 'user'
    }
  ];
  
  // Stocker les utilisateurs par défaut dans la session
  sessionStorage.setItem('mockUsers', JSON.stringify(defaultUsers));
  
  return defaultUsers;
}

export default userService;
