import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import api from '../../services/api';

export interface TableField {
  name: string;
  type: string;
  description: string;
}

export interface TableData {
  [key: string]: any;
}

export interface Filter {
  field: string;
  operator: string;
  value: any;
}

interface DataState {
  tables: string[];
  selectedTable: string | null;
  tableFields: TableField[];
  tableData: TableData[];
  totalRows: number;
  page: number;
  pageSize: number;
  filters: Filter[];
  conjunction: 'AND' | 'OR';
  selectedRows: string[];
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
}

const initialState: DataState = {
  tables: [],
  selectedTable: null,
  tableFields: [],
  tableData: [],
  totalRows: 0,
  page: 1,
  pageSize: 20,
  filters: [],
  conjunction: 'AND',
  selectedRows: [],
  status: 'idle',
  error: null,
};

// Async thunks
export const fetchTables = createAsyncThunk('data/fetchTables', async () => {
  const response = await api.get('/data/tables');
  return response.data;
});

export const fetchSapTables = createAsyncThunk(
  'data/fetchSapTables', 
  async ({ page, limit, search }: { page: number, limit: number, search?: string }) => {
    const response = await api.get('/data/sap-tables', {
      params: { page, limit, search }
    });
    return response.data;
  }
);

export const fetchTableFields = createAsyncThunk(
  'data/fetchTableFields',
  async (tableName: string) => {
    const response = await api.get(`/data/${tableName}/fields`);
    return response.data;
  }
);

export const fetchTableData = createAsyncThunk(
  'data/fetchTableData',
  async (
    {
      tableName,
      page,
      pageSize,
      filters,
      conjunction,
    }: {
      tableName: string;
      page: number;
      pageSize: number;
      filters: Filter[];
      conjunction: 'AND' | 'OR';
    },
    { rejectWithValue }
  ) => {
    try {
      const response = await api.post(`/data/${tableName}/filter`, {
        page,
        page_size: pageSize,
        filters,
        conjunction,
      });
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data || 'An error occurred');
    }
  }
);

export const fetchTablePreview = createAsyncThunk(
  'data/fetchTablePreview',
  async (
    {
      tableName,
      limit = 50
    }: {
      tableName: string;
      limit?: number;
    }
  ) => {
    const response = await api.get(`/data/${tableName}/preview`, {
      params: { limit }
    });
    return response.data;
  }
);

export const updateTableData = createAsyncThunk(
  'data/updateTableData',
  async (
    {
      tableName,
      rowsToUpdate,
    }: {
      tableName: string;
      rowsToUpdate: { [key: string]: any }[];
    },
    { rejectWithValue }
  ) => {
    try {
      const response = await api.put(
        `/data/${tableName}/data`,
        rowsToUpdate
      );
      return response.data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data || 'An error occurred');
    }
  }
);

const dataSlice = createSlice({
  name: 'data',
  initialState,
  reducers: {
    setSelectedTable(state, action: PayloadAction<string | null>) {
      state.selectedTable = action.payload;
      if (action.payload === null) {
        state.tableFields = [];
        state.tableData = [];
        state.totalRows = 0;
      }
    },
    setPage(state, action: PayloadAction<number>) {
      state.page = action.payload;
    },
    setPageSize(state, action: PayloadAction<number>) {
      state.pageSize = action.payload;
      state.page = 1; // Reset to first page when changing page size
    },
    addFilter(state, action: PayloadAction<Filter>) {
      state.filters.push(action.payload);
      state.page = 1; // Reset to first page when adding a filter
    },
    removeFilter(state, action: PayloadAction<number>) {
      state.filters.splice(action.payload, 1);
      state.page = 1; // Reset to first page when removing a filter
    },
    clearFilters(state) {
      state.filters = [];
      state.page = 1; // Reset to first page when clearing filters
    },
    setConjunction(state, action: PayloadAction<'AND' | 'OR'>) {
      state.conjunction = action.payload;
      state.page = 1; // Reset to first page when changing conjunction
    },
    setSelectedRows(state, action: PayloadAction<string[]>) {
      state.selectedRows = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchTables.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchTables.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.tables = action.payload;
      })
      .addCase(fetchTables.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Failed to fetch tables';
      })
      .addCase(fetchTableFields.fulfilled, (state, action) => {
        state.tableFields = action.payload;
      })
      .addCase(fetchTableData.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchTableData.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.tableData = action.payload.data;
        state.totalRows = action.payload.total;
      })
      .addCase(fetchTableData.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string || 'Failed to fetch data';
      })
      .addCase(updateTableData.fulfilled, (state) => {
        state.selectedRows = []; // Clear selection after update
      });
  },
});

export const {
  setSelectedTable,
  setPage,
  setPageSize,
  addFilter,
  removeFilter,
  clearFilters,
  setConjunction,
  setSelectedRows,
} = dataSlice.actions;

export default dataSlice.reducer;