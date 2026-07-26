import { useCallback, useEffect, useState } from 'react';
import { importService } from '../services/importService';
import {
    ImportJob,
    ImportStats,
    UploadResponse,
    UseImportOptions,
    UseImportResult
} from '../types/import.types';

export const useImport = (options: UseImportOptions = {}): UseImportResult => {
    const { autoRefresh = false, refreshInterval = 5000 } = options;

    // États
    const [jobs, setJobs] = useState<ImportJob[]>([]);
    const [stats, setStats] = useState<ImportStats | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Charger les jobs d'import
    const refreshJobs = useCallback(async () => {
        try {
            setLoading(true);
            setError(null);
            
            const response = await importService.getJobs();
            if (response.success) {
                setJobs(response.data);
            } else {
                setError(response.message || 'Erreur lors du chargement des imports');
            }
        } catch (err) {
            setError('Erreur réseau lors du chargement des imports');
            console.error('Erreur refreshJobs:', err);
        } finally {
            setLoading(false);
        }
    }, []);

    // Charger les statistiques
    const refreshStats = useCallback(async () => {
        try {
            const response = await importService.getStats();
            if (response.success) {
                setStats(response.data);
            } else {
                console.error('Erreur stats:', response.message);
            }
        } catch (err) {
            console.error('Erreur refreshStats:', err);
        }
    }, []);

    // Upload d'un fichier
    const uploadFile = useCallback(async (file: File, fileType: string): Promise<UploadResponse> => {
        try {
            setLoading(true);
            setError(null);
            
            const response = await importService.uploadFile(file, fileType);
            
            if (response.success) {
                // Rafraîchir la liste des jobs après un upload réussi
                setTimeout(() => {
                    refreshJobs();
                    refreshStats();
                }, 1000);
            } else {
                setError(response.message || 'Erreur lors de l\'upload');
            }
            
            return response;
        } catch (err) {
            const errorMessage = 'Erreur réseau lors de l\'upload';
            setError(errorMessage);
            console.error('Erreur uploadFile:', err);
            return {
                success: false,
                message: errorMessage,
                errors: [errorMessage]
            };
        } finally {
            setLoading(false);
        }
    }, [refreshJobs, refreshStats]);

    // Annuler un job
    const cancelJob = useCallback(async (jobUuid: string): Promise<void> => {
        try {
            setLoading(true);
            const response = await importService.cancelJob(jobUuid);
            
            if (response.success) {
                // Mettre à jour le job localement
                setJobs(prevJobs => 
                    prevJobs.map(job => 
                        job.job_uuid === jobUuid 
                            ? { ...job, status: 'cancelled' }
                            : job
                    )
                );
                refreshStats();
            } else {
                setError(response.message || 'Erreur lors de l\'annulation');
            }
        } catch (err) {
            setError('Erreur réseau lors de l\'annulation');
            console.error('Erreur cancelJob:', err);
        } finally {
            setLoading(false);
        }
    }, [refreshStats]);

    // Relancer un job
    const retryJob = useCallback(async (jobUuid: string): Promise<void> => {
        try {
            setLoading(true);
            const response = await importService.retryJob(jobUuid);
            
            if (response.success) {
                // Rafraîchir la liste pour voir le nouveau job
                refreshJobs();
                refreshStats();
            } else {
                setError(response.message || 'Erreur lors de la relance');
            }
        } catch (err) {
            setError('Erreur réseau lors de la relance');
            console.error('Erreur retryJob:', err);
        } finally {
            setLoading(false);
        }
    }, [refreshJobs, refreshStats]);

    // Charger les données au montage
    useEffect(() => {
        refreshJobs();
        refreshStats();
    }, [refreshJobs, refreshStats]);

    // Auto-refresh
    useEffect(() => {
        if (!autoRefresh) return;

        const interval = setInterval(() => {
            // Vérifier s'il y a des jobs en cours
            const hasProcessingJobs = jobs.some(job => 
                ['pending', 'processing'].includes(job.status)
            );

            if (hasProcessingJobs || jobs.length === 0) {
                refreshJobs();
                refreshStats();
            }
        }, refreshInterval);

        return () => clearInterval(interval);
    }, [autoRefresh, refreshInterval, jobs, refreshJobs, refreshStats]);

    // Mettre à jour les jobs en cours en temps réel
    useEffect(() => {
        const processingJobs = jobs.filter(job => job.status === 'processing');
        
        if (processingJobs.length > 0) {
            const pollInterval = setInterval(async () => {
                for (const job of processingJobs) {
                    try {
                        const response = await importService.getJobDetails(job.job_uuid);
                        if (response.success) {
                            setJobs(prevJobs => 
                                prevJobs.map(prevJob => 
                                    prevJob.job_uuid === job.job_uuid 
                                        ? { ...prevJob, ...response.data }
                                        : prevJob
                                )
                            );
                        }
                    } catch (err) {
                        console.error(`Erreur poll job ${job.job_uuid}:`, err);
                    }
                }
            }, 2000); // Poll toutes les 2 secondes pour les jobs en cours

            return () => clearInterval(pollInterval);
        }
    }, [jobs]);

    return {
        jobs,
        stats,
        loading,
        error,
        refreshJobs,
        refreshStats,
        uploadFile,
        cancelJob,
        retryJob
    };
}; 