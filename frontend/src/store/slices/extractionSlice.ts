import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import api from '../../services/api';
import extractionService, { 
  ExtractionOptions, 
  ExtractionHistory, 
  ExtractionStatus 
} from '../../services/extractionService';

// Types
export interface ExtractionJob {
  id: string;
  user: string;
  userId?: string;
  userName?: string;
  userEmail?: string;
  userRole?: string;
  startedAt: string;
  completedAt?: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  tables: string[];
  rowsExtracted?: number;
  progress?: number;
  mode?: string;
  batchSize?: number;
  duration?: number;
  error?: string;
  tablesDetails?: {
    name: string;
    rows?: number;
    startTime?: string;
    endTime?: string;
    status: string;
    error?: string;
  }[];
}

export interface ExtractionJobDetails extends ExtractionJob {
  progress: number;
  tablesDetails: {
    name: string;
    rows?: number;
    startTime: string;
    endTime?: string;
    status: string;
    error?: string;
  }[];
  batchSize?: number;
  error?: string;
}

export interface TableInfo {
  name: string;
  description: string;
  tableClass?: string;
  clientDependent?: boolean;
  availableForMapping?: boolean;
  disabled?: boolean;
}

interface ExtractionState {
  availableTables: TableInfo[];
  selectedTables: string[];
  batchSize: number;
  limit: number | null;
  mode: 'standard' | 'debug' | 'complet';
  workers: number;
  pageSize: number;
  clean: boolean;
  extractionJobs: ExtractionJob[];
  activeExtractions: string[];
  selectedJob: ExtractionJobDetails | null;
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
}

const initialState: ExtractionState = {
  availableTables: [],
  selectedTables: [],
  batchSize: 500,
  limit: null,
  mode: 'standard',
  workers: 4,
  pageSize: 5000,
  clean: false,
  extractionJobs: [],
  activeExtractions: [],
  selectedJob: null,
  status: 'idle',
  error: null
};

// Async thunks
export const fetchAvailableTables = createAsyncThunk(
  'extraction/fetchAvailableTables',
  async () => {
    const tables = await extractionService.getAvailableTables();
    return tables as TableInfo[];
  }
);

export const fetchExtractionHistory = createAsyncThunk(
  'extraction/fetchHistory',
  async ({ limit = 20, offset = 0 }: { limit?: number; offset?: number }) => {
    const response = await api.get('/extraction/history', {
      params: { limit, offset }
    });
    return response.data;
  }
);

export const fetchExtractionStatus = createAsyncThunk(
  'extraction/fetchStatus',
  async (extractionId: string) => {
    const response = await api.get(`/extraction/status/${extractionId}`);
    return response.data;
  }
);

// Rafraîchit le statut d'UN job (par jobid) et met à jour sa ligne dans la liste.
// Distinct de fetchExtractionStatus : ne touche ni selectedJob ni le status global
// (évite le clignotement du bouton Actualiser quand on rafraîchit plusieurs lignes).
export const refreshJobStatus = createAsyncThunk(
  'extraction/refreshJobStatus',
  async (extractionId: string) => {
    const response = await api.get(`/extraction/status/${extractionId}`);
    return response.data as ExtractionJobDetails;
  }
);

export const startExtraction = createAsyncThunk(
  'extraction/startExtraction',
  async ({ 
    tables, 
    options 
  }: { 
    tables: string[],
    options: {
      batchSize?: number;
      limit?: number;
      mode?: 'standard' | 'debug' | 'complet';
      workers?: number;
      pageSize?: number;
      clean?: boolean;
    }
  }) => {
    const response = await api.post('/extraction/start', {
      tables,
      options
    });
    return response.data;
  }
);

export const stopExtraction = createAsyncThunk(
  'extraction/stopExtraction',
  async ({ extractionId, reason }: { extractionId: string, reason?: string }) => {
    const response = await api.post(`/extraction/stop/${extractionId}`, { reason });
    return response.data;
  }
);

// Slice
const extractionSlice = createSlice({
  name: 'extraction',
  initialState,
  reducers: {
    setSelectedTables(state, action: PayloadAction<string[]>) {
      state.selectedTables = action.payload;
    },
    setBatchSize(state, action: PayloadAction<number>) {
      state.batchSize = action.payload;
    },
    setLimit(state, action: PayloadAction<number | null>) {
      state.limit = action.payload;
    },
    setMode(state, action: PayloadAction<'standard' | 'debug' | 'complet'>) {
      state.mode = action.payload;
    },
    setWorkers(state, action: PayloadAction<number>) {
      state.workers = action.payload;
    },
    setPageSize(state, action: PayloadAction<number>) {
      state.pageSize = action.payload;
    },
    setClean(state, action: PayloadAction<boolean>) {
      state.clean = action.payload;
    },
    clearExtractionSettings(state) {
      state.selectedTables = [];
      state.batchSize = 500;
      state.limit = null;
      state.mode = 'standard';
      state.workers = 4;
      state.pageSize = 5000;
      state.clean = false;
    },
    clearSelectedJob(state) {
      state.selectedJob = null;
    },
    updateActiveExtractions(state, action: PayloadAction<string[]>) {
      state.activeExtractions = action.payload;
    }
  },
  extraReducers: (builder) => {
    // fetchAvailableTables
    builder
      .addCase(fetchAvailableTables.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchAvailableTables.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.availableTables = action.payload;
      })
      .addCase(fetchAvailableTables.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Une erreur est survenue';
      })
    
    // fetchExtractionHistory
      .addCase(fetchExtractionHistory.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchExtractionHistory.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.extractionJobs = action.payload;
        
        // Mettre à jour la liste des extractions actives
        state.activeExtractions = action.payload
          .filter(job => job.status === 'pending' || job.status === 'running')
          .map(job => job.id);
      })
      .addCase(fetchExtractionHistory.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Erreur lors de la récupération de l\'historique';
      })
      
    // fetchExtractionStatus
      .addCase(fetchExtractionStatus.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(fetchExtractionStatus.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.selectedJob = action.payload;
      })
      .addCase(fetchExtractionStatus.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Erreur lors de la récupération du statut';
      })

    // refreshJobStatus : maj ciblée de la ligne (statut par jobid), sans toucher au status global
      .addCase(refreshJobStatus.fulfilled, (state, action) => {
        const p = action.payload;
        if (!p || !p.id) return;
        const idx = state.extractionJobs.findIndex(j => j.id === p.id);
        if (idx !== -1) {
          const job = state.extractionJobs[idx];
          // Fusion sélective : on ne remonte que les champs de statut, on préserve
          // les infos utilisateur (userName/userEmail…) absentes du endpoint /status.
          job.status = p.status ?? job.status;
          job.startedAt = p.startedAt ?? job.startedAt;
          job.completedAt = p.completedAt ?? job.completedAt;
          job.rowsExtracted = p.rowsExtracted ?? job.rowsExtracted;
          job.progress = p.progress ?? job.progress;
          job.duration = p.duration ?? job.duration;
          job.error = p.error ?? job.error;
          if (p.tablesDetails) job.tablesDetails = p.tablesDetails;
        }
        // Recalcule la liste des extractions actives
        state.activeExtractions = state.extractionJobs
          .filter(j => j.status === 'pending' || j.status === 'running')
          .map(j => j.id);
      })

    // startExtraction
      .addCase(startExtraction.pending, (state) => {
        state.status = 'loading';
      })
      .addCase(startExtraction.fulfilled, (state, action) => {
        state.status = 'succeeded';
        // Ajouter le nouvel ID d'extraction aux extractions actives
        if (action.payload && action.payload.extraction_id) {
          state.activeExtractions = [...state.activeExtractions, action.payload.extraction_id];
        }
      })
      .addCase(startExtraction.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.error.message || 'Erreur lors du démarrage de l\'extraction';
      })
      
    // stopExtraction
      .addCase(stopExtraction.fulfilled, (state, action) => {
        // Mettre à jour le statut après l'arrêt, si nous avons l'ID d'extraction
        if (state.selectedJob && action.meta.arg.extractionId === state.selectedJob.id) {
          state.selectedJob.status = 'cancelled';
        }
        
        // Retirer l'ID des extractions actives
        state.activeExtractions = state.activeExtractions.filter(
          id => id !== action.meta.arg.extractionId
        );
      });
  }
});

export const { 
  setSelectedTables, 
  setBatchSize, 
  setLimit, 
  setMode,
  setWorkers,
  setPageSize,
  setClean,
  clearExtractionSettings,
  clearSelectedJob, 
  updateActiveExtractions 
} = extractionSlice.actions;

export default extractionSlice.reducer;