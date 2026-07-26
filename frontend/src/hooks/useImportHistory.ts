import { useCallback, useEffect, useMemo, useState } from 'react';
import { importService } from '../services/importService';
import {
    ImportFilters,
    ImportJob,
    ImportJobsResponse,
    PaginationParams
} from '../types/import.types';

export interface UseImportHistoryOptions {
    autoRefresh?: boolean;
    refreshInterval?: number;
    initialFilters?: ImportFilters;
    initialPagination?: PaginationParams;
}

export interface UseImportHistoryResult {
    jobs: ImportJob[];
    filteredJobs: ImportJob[];
    totalCount: number;
    loading: boolean;
    error: string | null;
    filters: ImportFilters;
    pagination: PaginationParams;
    
    // Actions
    setFilters: (filters: ImportFilters) => void;
    setPagination: (pagination: PaginationParams) => void;
    refresh: () => Promise<void>;
    clearFilters: () => void;
    applyQuickFilter: (status: string) => void;
    searchJobs: (query: string) => void;
    
    // Statistiques calculées
    stats: {
        total: number;
        pending: number;
        processing: number;
        completed: number;
        failed: number;
        cancelled: number;
    };
}

export const useImportHistory = (options: UseImportHistoryOptions = {}): UseImportHistoryResult => {
    const {
        autoRefresh = false,
        refreshInterval = 30000,
        initialFilters = {},
        initialPagination = { page: 0, per_page: 25, sort_by: 'created_at', sort_order: 'desc' }
    } = options;

    // États
    const [jobs, setJobs] = useState<ImportJob[]>([]);
    const [totalCount, setTotalCount] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [filters, setFiltersState] = useState<ImportFilters>(initialFilters);
    const [pagination, setPaginationState] = useState<PaginationParams>(initialPagination);

    // Fonction de chargement des données
    const loadJobs = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);

            const response: ImportJobsResponse = await importService.getJobs(filters, pagination);
            
            if (response.success) {
                setJobs(response.data);
                setTotalCount(response.total);
            } else {
                setError(response.message || 'Erreur lors du chargement des imports');
                setJobs([]);
                setTotalCount(0);
            }
        } catch (err) {
            setError('Erreur réseau lors du chargement des imports');
            setJobs([]);
            setTotalCount(0);
            console.error('Erreur loadJobs:', err);
        } finally {
            setLoading(false);
        }
    }, [filters, pagination]);

    // Fonction de rafraîchissement
    const refresh = useCallback(async () => {
        await loadJobs();
    }, [loadJobs]);

    // Gestion des filtres
    const setFilters = useCallback((newFilters: ImportFilters) => {
        setFiltersState(newFilters);
        // Reset à la première page lors d'un changement de filtre
        setPaginationState(prev => ({ ...prev, page: 0 }));
    }, []);

    // Gestion de la pagination
    const setPagination = useCallback((newPagination: PaginationParams) => {
        setPaginationState(prev => ({ ...prev, ...newPagination }));
    }, []);

    // Effacer les filtres
    const clearFilters = useCallback(() => {
        setFilters({});
    }, [setFilters]);

    // Filtre rapide par statut
    const applyQuickFilter = useCallback((status: string) => {
        setFilters(status === 'all' ? {} : { status });
    }, [setFilters]);

    // Recherche dans les jobs
    const searchJobs = useCallback((query: string) => {
        setFilters(prev => ({
            ...prev,
            search: query || undefined
        }));
    }, [setFilters]);

    // Calcul des jobs filtrés côté client (pour les filtres non supportés par le backend)
    const filteredJobs = useMemo(() => {
        let filtered = [...jobs];

        // Filtres côté client si nécessaire (backup)
        if (filters.search && typeof filters.search === 'string') {
            const searchLower = filters.search.toLowerCase();
            filtered = filtered.filter(job => 
                job.file_name.toLowerCase().includes(searchLower) ||
                job.file_type.toLowerCase().includes(searchLower) ||
                (job.user_name && job.user_name.toLowerCase().includes(searchLower))
            );
        }

        return filtered;
    }, [jobs, filters]);

    // Calcul des statistiques
    const stats = useMemo(() => {
        const total = jobs.length;
        const pending = jobs.filter(job => job.status === 'pending').length;
        const processing = jobs.filter(job => job.status === 'processing').length;
        const completed = jobs.filter(job => ['completed', 'completed_with_errors'].includes(job.status)).length;
        const failed = jobs.filter(job => job.status === 'failed').length;
        const cancelled = jobs.filter(job => job.status === 'cancelled').length;

        return {
            total,
            pending,
            processing,
            completed,
            failed,
            cancelled
        };
    }, [jobs]);

    // Chargement initial
    useEffect(() => {
        loadJobs();
    }, [loadJobs]);

    // Auto-refresh
    useEffect(() => {
        if (!autoRefresh) return;

        const interval = setInterval(() => {
            // Refresh uniquement s'il y a des jobs en cours ou en attente
            const hasActiveJobs = jobs.some(job => 
                ['pending', 'processing'].includes(job.status)
            );

            if (hasActiveJobs || jobs.length === 0) {
                loadJobs();
            }
        }, refreshInterval);

        return () => clearInterval(interval);
    }, [autoRefresh, refreshInterval, jobs, loadJobs]);

    // Polling spécial pour les jobs en cours (plus fréquent)
    useEffect(() => {
        const activeJobs = jobs.filter(job => job.status === 'processing');
        
        if (activeJobs.length === 0) return;

        const interval = setInterval(() => {
            // Actualiser uniquement si on est sur la première page
            if (pagination.page === 0) {
                loadJobs();
            }
        }, 5000); // Poll toutes les 5 secondes pour jobs actifs

        return () => clearInterval(interval);
    }, [jobs, pagination.page, loadJobs]);

    return {
        jobs,
        filteredJobs,
        totalCount,
        loading,
        error,
        filters,
        pagination,
        setFilters,
        setPagination,
        refresh,
        clearFilters,
        applyQuickFilter,
        searchJobs,
        stats
    };
}; 