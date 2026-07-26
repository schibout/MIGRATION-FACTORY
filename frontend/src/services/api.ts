import axios from 'axios';

// Configuration de base - Utilise l'URL relative pour la production
const API_PATH = '/api/v1';

// Création d'une instance axios avec la configuration de base
const api = axios.create({
  baseURL: API_PATH,
  timeout: 600000, // 10 minutes pour les exports volumineux
  headers: {
    'Content-Type': 'application/json',
  }
});

// Configuration des logs (desactive par defaut : evite de logger les corps de requete,
// y compris le mot de passe au login)
const enableDetailedLogs = false;

// Fonction pour récupérer le token JWT stocké
const getStoredToken = (): string | null => {
  return localStorage.getItem('token');
};

// Intercepteur de requêtes
api.interceptors.request.use(
  (config) => {
    // Vérifier si un token JWT est disponible
    const token = getStoredToken();
    
    if (token) {
      // Utiliser le token JWT pour l'authentification Bearer
      config.headers['Authorization'] = `Bearer ${token}`;
      
      if (enableDetailedLogs) {
        console.log('JWT Token ajouté');
      }
    } else if (enableDetailedLogs) {
      console.log('Aucun token JWT disponible');
    }
    
    // Logs des requêtes améliorés
    if (enableDetailedLogs) {
      console.group(`🚀 API Request: ${config.method?.toUpperCase()} ${config.url}`);
      
      // Log détaillé des paramètres de requête
      if (config.params) {
        console.log('Params:', config.params);
        
        // Log spécifique pour les filtres si présents
        if (config.params.filters) {
          try {
            console.log('Filtres (détail):', 
              typeof config.params.filters === 'string' 
                ? JSON.parse(config.params.filters) 
                : config.params.filters
            );
          } catch (e) {
            console.log('Erreur lors du parsing des filtres:', config.params.filters);
          }
        }
      } else {
        console.log('Params: aucun');
      }
      
      // Log du corps de la requête
      if (config.data) {
        console.log('Data:', config.data);
      } else {
        console.log('Data: aucune');
      }
      
      console.groupEnd();
    }
    
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Déconnexion effective : purge du localStorage + redirection vers /login
const forceLogout = (): void => {
  localStorage.removeItem('token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('user');
  if (window.location.pathname !== '/login') {
    window.location.href = '/login';
  }
};

// Rafraîchissement silencieux : sur un 401, on tente une fois /auth/refresh avec le
// refresh_token, puis on rejoue la requête d'origine. On ne déconnecte l'utilisateur
// QUE si le refresh échoue. Les requêtes 401 concurrentes sont mises en file d'attente
// pour ne déclencher qu'un seul refresh.
let isRefreshing = false;
let pendingQueue: Array<(token: string | null) => void> = [];

const flushQueue = (token: string | null): void => {
  pendingQueue.forEach((cb) => cb(token));
  pendingQueue = [];
};

// Intercepteur de réponses
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const status = error.response?.status;

    // Ne pas tenter de refresh pour les appels d'authentification eux-mêmes
    const isAuthCall =
      originalRequest?.url?.includes('/auth/login') ||
      originalRequest?.url?.includes('/auth/refresh');

    if (status === 401 && originalRequest && !originalRequest._retry && !isAuthCall) {
      const refreshToken = localStorage.getItem('refresh_token');
      if (!refreshToken) {
        forceLogout();
        return Promise.reject(error);
      }

      originalRequest._retry = true;

      // Un refresh est déjà en cours : mettre la requête en attente du nouveau token
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          pendingQueue.push((token) => {
            if (token) {
              originalRequest.headers['Authorization'] = `Bearer ${token}`;
              resolve(api(originalRequest));
            } else {
              reject(error);
            }
          });
        });
      }

      isRefreshing = true;
      try {
        // axios brut (pas l'instance `api`) pour envoyer le refresh_token et non le token expiré
        const { data } = await axios.post(
          `${API_PATH}/auth/refresh`,
          {},
          { headers: { Authorization: `Bearer ${refreshToken}` } }
        );
        const newToken = data.access_token as string;
        localStorage.setItem('token', newToken);
        flushQueue(newToken);
        originalRequest.headers['Authorization'] = `Bearer ${newToken}`;
        return api(originalRequest);
      } catch (refreshError) {
        // Le refresh_token est lui-même expiré/invalide : déconnexion réelle
        flushQueue(null);
        forceLogout();
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

// Fonctions utilitaires pour l'authentification
export const isAuthenticated = (): boolean => {
  return !!localStorage.getItem('token');
};

export const logout = (): void => {
  localStorage.removeItem('token');
  localStorage.removeItem('refresh_token');
};

export const getCurrentUser = (): string | null => {
  // Récupérer depuis le state Redux ou localStorage selon votre implémentation
  return localStorage.getItem('currentUser');
};

// Export par défaut de l'instance API
export default api;