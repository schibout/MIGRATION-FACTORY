import { AxiosError } from 'axios';
import { withBase } from '../basePath';

export interface AuthErrorHandlerOptions {
  setError?: (error: string) => void;
  redirectToLogin?: boolean;
}

export const handleAuthError = (
  error: AxiosError,
  options: AuthErrorHandlerOptions = {}
): boolean => {
  const { setError, redirectToLogin = true } = options;
  
  // 401 = token expiré/invalide → déconnexion.
  // NB : le refresh silencieux est géré en amont par l'intercepteur axios (api.ts).
  // Si un 401 arrive jusqu'ici, c'est que le refresh a déjà échoué → déconnexion réelle.
  if (error.response?.status === 401) {
    console.error(`❌ Erreur d'authentification 401:`, error.message);

    if (setError) {
      setError('Session expirée. Veuillez vous reconnecter.');
    }

    // Nettoyer le localStorage
    localStorage.removeItem('token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user');

    // Rediriger vers la page de connexion si demandé
    if (redirectToLogin) {
      window.location.href = withBase('/login');
    }

    return true; // Erreur d'auth gérée
  }

  // 422 = token malformé OU permissions insuffisantes : on affiche un message
  // mais on NE déconnecte PAS automatiquement (évite les logouts intempestifs).
  if (error.response?.status === 422) {
    console.error('❌ Erreur 422 (token/permissions):', error.message);

    if (setError) {
      setError('Permissions insuffisantes ou requête invalide.');
    }

    return true; // Erreur gérée
  }
  
  if (error.response?.status === 403) {
    console.error('❌ Erreur de permissions 403:', error.message);
    
    if (setError) {
      setError('Vous n\'avez pas les permissions nécessaires pour effectuer cette action.');
    }
    
    return true; // Erreur de permissions gérée
  }
  
  return false; // Erreur non gérée
};

export const tryMultipleEndpoints = async <T>(
  primaryCall: () => Promise<T>,
  fallbackCall: () => Promise<T>,
  options: AuthErrorHandlerOptions = {}
): Promise<T> => {
  try {
    return await primaryCall();
  } catch (firstError) {
    const error = firstError as AxiosError;
    
    // Si c'est une erreur d'auth, la gérer immédiatement
    if (handleAuthError(error, options)) {
      throw error;
    }
    
    // Sinon, essayer l'endpoint de fallback
    console.warn('⚠️ Échec du premier endpoint, tentative avec le fallback...', error.response?.status);
    
    try {
      return await fallbackCall();
    } catch (secondError) {
      const fallbackError = secondError as AxiosError;
      
      // Gérer les erreurs d'auth du fallback
      if (handleAuthError(fallbackError, options)) {
        throw fallbackError;
      }
      
      // Si aucun des deux n'a fonctionné, renvoyer la dernière erreur
      throw fallbackError;
    }
  }
};

export const isTokenValid = (): boolean => {
  const token = localStorage.getItem('token');
  
  if (!token) {
    console.error('❌ Aucun token d\'authentification trouvé');
    return false;
  }
  
  try {
    // Décoder le JWT pour vérifier l'expiration (sans validation de signature)
    const payload = JSON.parse(atob(token.split('.')[1]));
    const currentTime = Math.floor(Date.now() / 1000);
    
    if (payload.exp && payload.exp < currentTime) {
      console.error('❌ Token expiré');
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('❌ Token invalide:', error);
    return false;
  }
}; 