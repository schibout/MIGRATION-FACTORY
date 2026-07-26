import api from './api';

export interface SharePointProject {
    id: number;
    sharepoint_id: number;
    title: string;
    code: string;
    project_number: string;
    description: string;
    global_status: string;
    phase_text: string;
    percent_completed: number;
    health: string;
    planning: string;
    cost: string;
    start_date: string;
    estimated_end_date: string;
    budget_initial: number;
    budget_total_sap: number;
    budget_actual: number;
    sector: string;
    group_name: string;
    template: string;
    pm_id: number;
    imported_at: string;
}

export interface ProjectsResponse {
    success: boolean;
    data: SharePointProject[];
    total: number;
    page: number;
    per_page: number;
    message?: string;
}

export interface ImportProjectsRequest {
    limit?: number;
    filters?: Record<string, string>;
}

export interface ImportProjectsResponse {
    success: boolean;
    message: string;
    imported_count: number;
    errors: string[];
}

export interface ProjectsStatusResponse {
    total_projets: number;
    derniere_sync: string;
    sync_recente: number;
    premiere_import: string;
    dernier_import: string;
    status: string;
}

class ProjectService {
    private readonly baseUrl = '/import/projets';

    /**
     * Récupérer la liste des projets importés
     */
    async getProjects(page: number = 1, perPage: number = 50, search?: string): Promise<ProjectsResponse> {
        try {
            const params: any = {
                page,
                per_page: perPage
            };
            
            if (search) {
                params.search = search;
            }
            
            const response = await api.get('/data/sharepoint-projets', { params });
            return {
                success: true,
                data: response.data.data || [],
                total: response.data.total || 0,
                page: response.data.page || 1,
                per_page: response.data.per_page || perPage
            };
        } catch (error: any) {
            console.error('Erreur récupération projets:', error);
            return {
                success: false,
                data: [],
                total: 0,
                page: 1,
                per_page: perPage,
                message: error.response?.data?.message || 'Erreur lors du chargement des projets'
            };
        }
    }

    /**
     * Récupérer les détails d'un projet spécifique
     */
    async getProjectDetail(projectId: number): Promise<any> {
        try {
            const response = await api.get(`/data/sharepoint-projets/${projectId}`);
            return response.data;
        } catch (error: any) {
            console.error(`Erreur récupération projet ${projectId}:`, error);
            throw error;
        }
    }

    /**
     * Importer les projets depuis SharePoint
     */
    async importProjects(request: ImportProjectsRequest = {}): Promise<ImportProjectsResponse> {
        try {
            const response = await api.post(this.baseUrl, request);
            return response.data;
        } catch (error: any) {
            console.error('Erreur import projets:', error);
            return {
                success: false,
                message: error.response?.data?.message || 'Erreur lors de l\'import',
                imported_count: 0,
                errors: [error.response?.data?.error || 'Erreur inconnue']
            };
        }
    }

    /**
     * Tester la connexion SharePoint
     */
    async testConnection(): Promise<{ success: boolean; message?: string; error?: string }> {
        try {
            const response = await api.get(`${this.baseUrl}/test-connection`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur test connexion:', error);
            return {
                success: false,
                error: error.response?.data?.error || 'Erreur lors du test de connexion'
            };
        }
    }

    /**
     * Récupérer le statut de l'import des projets
     */
    async getStatus(): Promise<ProjectsStatusResponse | null> {
        try {
            const response = await api.get(`${this.baseUrl}/status`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur statut projets:', error);
            return null;
        }
    }
}

// Instance singleton du service
export const projectService = new ProjectService();
export default projectService;

