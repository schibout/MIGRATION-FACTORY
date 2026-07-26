import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import axios from 'axios';

export interface Connection {
  id: string;
  name: string;
  type: 'sap' | 'postgresql';
  host: string;
  port: number;
  username: string;
  database?: string;
  client?: string;
  isActive: boolean;
}

export interface TableMapping {
  id: string;
  sourceTable: string;
  sourceDescription: string;
  targetTable: string;
  isActive: boolean;
  fields: FieldMapping[];
}

export interface FieldMapping {
  id: string;
  sourceField: string;
  sourceType: string;
  targetField: string;
  targetType: string;
  transformation?: string;
  isKey: boolean;
}

interface ConfigState {
  connections: Connection[];
  tableMapping: TableMapping[];
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
}

const initialState: ConfigState = {
  connections: [],
  tableMapping: [],
  status: 'idle',
  error: null,
};

// Async thunks
export const fetchConnections = createAsyncThunk(
  'config/fetchConnections',
  async () => {
    const response = await axios.get('/api/config/connections');
    return response.data;
  }
);

export const saveConnection = createAsyncThunk(
  'config/saveConnection',
  async (connection: Partial<Connection>, { rejectWithValue }) => {
    try {
      let response;
      if (connection.id) {
        // Update existing connection
        response = await axios.put(
          `/api/config/connections/${connection.id}`,
          connection
        );
      } else {
        // Create new connection
        response = await axios.post('/api/config/connections', connection);
      }
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data || 'Failed to save connection');
    }
  }
);

export const fetchTableMappings = createAsyncThunk(
  'config/fetchTableMappings',
  async () => {
    const response = await axios.get('/api/config/mapping');
    return response.data;
  }
);

export const saveTableMapping = createAsyncThunk(
  'config/saveTableMapping',
  async (mapping: Partial<TableMapping>, { rejectWithValue }) => {
    try {
      let response;
      if (mapping.id) {
        // Update existing mapping
        response = await axios.put(
          `/api/config/mapping/${mapping.id}`,
          mapping
        );
      } else {
        // Create new mapping
        response = await axios.post('/api/config/mapping', mapping);
      }
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data || 'Failed to save mapping');
    }
  }
);

const configSlice = createSlice({
  name: 'config',
  initialState,
  reducers: {
    resetConfigStatus(state) {
      state.status = 'idle';
      state.error = null;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchConnections.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchConnections.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.connections = action.payload;
      })
      .addCase(fetchConnections.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Failed to fetch connections';
      })
      .addCase(saveConnection.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(saveConnection.fulfilled, (state, action) => {
        state.status = 'succeeded';
        const index = state.connections.findIndex(
          (conn) => conn.id === action.payload.id
        );
        if (index >= 0) {
          // Update existing connection
          state.connections[index] = action.payload;
        } else {
          // Add new connection
          state.connections.push(action.payload);
        }
      })
      .addCase(saveConnection.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      })
      .addCase(fetchTableMappings.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchTableMappings.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.tableMapping = action.payload;
      })
      .addCase(fetchTableMappings.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Failed to fetch table mappings';
      })
      .addCase(saveTableMapping.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(saveTableMapping.fulfilled, (state, action) => {
        state.status = 'succeeded';
        const index = state.tableMapping.findIndex(
          (mapping) => mapping.id === action.payload.id
        );
        if (index >= 0) {
          // Update existing mapping
          state.tableMapping[index] = action.payload;
        } else {
          // Add new mapping
          state.tableMapping.push(action.payload);
        }
      })
      .addCase(saveTableMapping.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      });
  },
});

export const { resetConfigStatus } = configSlice.actions;

export default configSlice.reducer; 