import {
    FileTypeConfigsResponse,
    ImportDetailsResponse,
    ImportFilters,
    ImportJob,
    ImportJobsResponse,
    ImportLog,
    ImportStatsResponse,
    PaginationParams,
    UploadResponse
} from '../types/import.types';
import api from './api';

class ImportService {
    // Base URL pour les endpoints d'import (sans /api car déjà dans api.baseURL)
    private readonly baseUrl = '/import';

    /**
     * Upload d'un fichier pour import
     */
    async uploadFile(file: File, fileType: string): Promise<UploadResponse> {
        try {
            const formData = new FormData();
            formData.append('file', file);
            formData.append('file_type', fileType);

            const response = await api.post(`${this.baseUrl}/upload`, formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
                // Timeout plus long pour les gros fichiers
                timeout: 300000, // 5 minutes
            });

            return response.data;
        } catch (error: any) {
            console.error('Erreur upload fichier:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors de l\'upload du fichier',
                errors: error.response?.data?.errors || []
            };
        }
    }

    /**
     * Récupérer la liste des jobs d'import
     */
    async getJobs(filters?: ImportFilters, pagination?: PaginationParams): Promise<ImportJobsResponse> {
        try {
            const params = new URLSearchParams();

            // Ajouter les filtres
            if (filters) {
                if (filters.status) {
                    if (Array.isArray(filters.status)) {
                        filters.status.forEach(status => params.append('status', status));
                    } else {
                        params.append('status', filters.status);
                    }
                }
                if (filters.file_type) {
                    if (Array.isArray(filters.file_type)) {
                        filters.file_type.forEach(type => params.append('file_type', type));
                    } else {
                        params.append('file_type', filters.file_type);
                    }
                }
                if (filters.date_from) params.append('date_from', filters.date_from);
                if (filters.date_to) params.append('date_to', filters.date_to);
                if (filters.user_id) params.append('user_id', filters.user_id.toString());
                if (filters.search) params.append('search', filters.search);
            }

            // Ajouter la pagination
            if (pagination) {
                if (pagination.page) params.append('page', pagination.page.toString());
                if (pagination.per_page) params.append('per_page', pagination.per_page.toString());
                if (pagination.sort_by) params.append('sort_by', pagination.sort_by);
                if (pagination.sort_order) params.append('sort_order', pagination.sort_order);
            }

            const response = await api.get(`${this.baseUrl}/jobs?${params.toString()}`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur récupération jobs:', error);
            // Retourner une structure vide mais valide en cas d'erreur
            return {
                success: true, // Marquer comme succès avec données vides plutôt qu'erreur
                data: [],
                total: 0,
                page: 1,
                per_page: 10,
                message: 'Aucun import trouvé'
            };
        }
    }

    /**
     * Récupérer les détails d'un job spécifique
     */
    async getJobDetails(jobUuid: string): Promise<{ success: boolean; data?: ImportJob; message?: string }> {
        try {
            const response = await api.get(`${this.baseUrl}/jobs/${jobUuid}`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur détails job:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors du chargement des détails'
            };
        }
    }

    /**
     * Récupérer les détails ligne par ligne d'un import
     */
    async getJobLineDetails(
        jobUuid: string, 
        pagination?: PaginationParams
    ): Promise<ImportDetailsResponse> {
        try {
            const params = new URLSearchParams();
            if (pagination) {
                if (pagination.page) params.append('page', pagination.page.toString());
                if (pagination.per_page) params.append('per_page', pagination.per_page.toString());
                if (pagination.sort_by) params.append('sort_by', pagination.sort_by);
                if (pagination.sort_order) params.append('sort_order', pagination.sort_order);
            }

            const response = await api.get(`${this.baseUrl}/jobs/${jobUuid}/details?${params.toString()}`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur détails lignes:', error);
            return {
                success: false,
                data: [],
                total: 0,
                page: 1,
                per_page: 10,
                message: error.response?.data?.message || 'Erreur lors du chargement des détails'
            };
        }
    }

    /**
     * Récupérer les logs d'un job
     */
    async getJobLogs(jobUuid: string): Promise<{ success: boolean; data?: ImportLog[]; message?: string }> {
        try {
            const response = await api.get(`${this.baseUrl}/jobs/${jobUuid}/logs`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur logs job:', error);
            return {
                success: false,
                data: [],
                message: error.response?.data?.message || 'Erreur lors du chargement des logs'
            };
        }
    }

    /**
     * Annuler un job d'import
     */
    async cancelJob(jobUuid: string): Promise<{ success: boolean; message?: string }> {
        try {
            const response = await api.post(`${this.baseUrl}/jobs/${jobUuid}/cancel`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur annulation job:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors de l\'annulation'
            };
        }
    }

    /**
     * Relancer un job d'import
     */
    async retryJob(jobUuid: string): Promise<{ success: boolean; job_uuid?: string; message?: string }> {
        try {
            const response = await api.post(`${this.baseUrl}/jobs/${jobUuid}/retry`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur relance job:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors de la relance'
            };
        }
    }

    /**
     * Exporter les erreurs d'un job
     */
    async exportJobErrors(jobUuid: string, format: 'csv' | 'excel' = 'csv'): Promise<Blob | null> {
        try {
            const response = await api.get(`${this.baseUrl}/jobs/${jobUuid}/export-errors`, {
                params: { format },
                responseType: 'blob'
            });

            return new Blob([response.data], { 
                type: format === 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            });
        } catch (error: any) {
            console.error('Erreur export erreurs:', error);
            return null;
        }
    }

    /**
     * Récupérer les statistiques globales d'import
     */
    async getStats(): Promise<ImportStatsResponse> {
        try {
            const response = await api.get(`${this.baseUrl}/stats`);
            // Adapter la réponse de l'API au format attendu par TypeScript
            return {
                success: true,
                data: response.data.statistics || response.data,
                message: 'Statistiques récupérées avec succès'
            };
        } catch (error: any) {
            console.error('Erreur statistiques:', error);
            // Retourner des statistiques vides mais valides en cas d'erreur
            return {
                success: true, // Marquer comme succès avec données vides
                data: {
                    total_imports: 0,
                    successful_imports: 0,
                    failed_imports: 0,
                    pending_imports: 0,
                    total_rows_processed: 0,
                    success_rate: 0,
                    avg_processing_time: 0,
                    imports_today: 0,
                    imports_this_week: 0,
                    imports_this_month: 0
                },
                message: 'Aucune donnée d\'import disponible'
            };
        }
    }

    /**
     * Récupérer les configurations des types de fichiers
     */
    async getFileTypeConfigs(): Promise<FileTypeConfigsResponse> {
        try {
            // Utiliser l'endpoint de configuration général
            const response = await api.get('/api/config/file-types');
            return response.data;
        } catch (error: any) {
            console.error('Erreur configurations types:', error);
            // Retourner des configurations par défaut en cas d'erreur
            return {
                success: true,
                data: [
                    {
                        type: 'customers',
                        name: 'Clients IFS',
                        description: 'Import de données clients vers IFS',
                        required_columns: ['customer_id', 'name'],
                        optional_columns: ['email', 'phone', 'address'],
                        target_table: 'clean_data.customer_info',
                        max_file_size: 50 * 1024 * 1024, // 50MB
                        allowed_formats: ['csv', 'xlsx', 'xls']
                    },
                    {
                        type: 'products',
                        name: 'Articles IFS',
                        description: 'Import d\'articles vers le catalogue IFS',
                        required_columns: ['part_no', 'description', 'unit_code'],
                        optional_columns: ['weight_net', 'volume_net', 'info_text'],
                        target_table: 'clean_data.part_catalog',
                        max_file_size: 50 * 1024 * 1024, // 50MB
                        allowed_formats: ['csv', 'xlsx', 'xls']
                    }
                ],
                message: 'Configurations types par défaut'
            };
        }
    }

    /**
     * Vérifier l'état du service d'import
     */
    async getHealthCheck(): Promise<{ success: boolean; status?: string; message?: string }> {
        try {
            const response = await api.get(`${this.baseUrl}/health`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur health check:', error);
            return {
                success: false,
                message: 'Service d\'import indisponible'
            };
        }
    }

    /**
     * Télécharger un rapport complet d'un job
     */
    async downloadJobReport(jobUuid: string, format: 'pdf' | 'excel' = 'excel'): Promise<Blob | null> {
        try {
            const response = await api.get(`${this.baseUrl}/jobs/${jobUuid}/report`, {
                params: { format },
                responseType: 'blob'
            });

            return new Blob([response.data], { 
                type: format === 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            });
        } catch (error: any) {
            console.error('Erreur téléchargement rapport:', error);
            return null;
        }
    }

    /**
     * Valider un fichier avant import (preview)
     */
    async validateFile(file: File, fileType: string): Promise<{
        success: boolean;
        preview?: any[];
        errors?: string[];
        warnings?: string[];
        column_mapping?: Record<string, string>;
        message?: string;
    }> {
        try {
            const formData = new FormData();
            formData.append('file', file);
            formData.append('file_type', fileType);

            const response = await api.post(`${this.baseUrl}/validate`, formData, {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
            });

            return response.data;
        } catch (error: any) {
            console.error('Erreur validation fichier:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors de la validation du fichier',
                errors: error.response?.data?.errors || []
            };
        }
    }
}

// Instance singleton du service
export const importService = new ImportService();
export default importService; 