import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import api from '../../services/api';

// Types pour les rôles utilisateur
export type UserRole = 'admin' | 'operator';

export interface User {
  id: string;
  username: string;
  email: string;
  role: UserRole;
  is_active: boolean;
  created_at: string | null;
  last_login: string | null;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
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

// Helper pour sauvegarder l'utilisateur dans le localStorage
const saveUserToLocalStorage = (user: User) => {
  localStorage.setItem('user', JSON.stringify(user));
};

// Helper pour récupérer l'utilisateur depuis le localStorage
const getUserFromLocalStorage = (): User | null => {
  try {
    const userString = localStorage.getItem('user');
    return userString ? JSON.parse(userString) : null;
  } catch (error) {
    console.error('Erreur lors de la récupération de l\'utilisateur depuis le localStorage:', error);
    return null;
  }
};

const initialState: AuthState = {
  user: getUserFromLocalStorage(),
  token: localStorage.getItem('token'),
  isAuthenticated: !!localStorage.getItem('token'),
  status: 'idle',
  error: null,
};

// Async thunks
export const login = createAsyncThunk(
  'auth/login',
  async (
    { username, password }: { username: string; password: string },
    { rejectWithValue }
  ) => {
    try {
      const response = await api.post('/auth/login', {
        username,
        password,
      });
      
      const { access_token, refresh_token, user } = response.data;
      localStorage.setItem('token', access_token);
      localStorage.setItem('refresh_token', refresh_token);
      saveUserToLocalStorage(user);
      
      return { token: access_token, user };
    } catch (err: any) {
      return rejectWithValue(
        err.response?.data?.error || 'Échec de connexion. Veuillez réessayer.'
      );
    }
  }
);

export const fetchCurrentUser = createAsyncThunk(
  'auth/fetchCurrentUser',
  async (_, { getState, rejectWithValue }) => {
    // @ts-ignore
    const { auth } = getState();
    if (!auth.token) {
      return rejectWithValue('No token available');
    }

    try {
      const response = await api.get('/auth/me', {
        headers: {
          Authorization: `Bearer ${auth.token}`,
        },
      });
      return response.data;
    } catch (err: any) {
      return rejectWithValue(
        err.response?.data?.message || 'Failed to fetch user'
      );
    }
  }
);

export const logout = createAsyncThunk('auth/logout', async () => {
  localStorage.removeItem('token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('user');
  return null;
});

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError(state) {
      state.error = null;
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(login.pending, (state) => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(login.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.token = action.payload.token;
        state.user = action.payload.user;
        state.isAuthenticated = true;
      })
      .addCase(login.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      })
      .addCase(fetchCurrentUser.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchCurrentUser.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.user = action.payload;
        state.isAuthenticated = true;
        saveUserToLocalStorage(action.payload);
      })
      .addCase(fetchCurrentUser.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
        state.isAuthenticated = false;
        state.token = null;
        localStorage.removeItem('token');
      })
      .addCase(logout.fulfilled, (state) => {
        state.user = null;
        state.token = null;
        state.isAuthenticated = false;
        state.status = 'idle';
      });
  },
});

export const { clearError } = authSlice.actions;

export default authSlice.reducer;