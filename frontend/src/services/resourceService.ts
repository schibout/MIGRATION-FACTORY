import api from './api';

export interface SharePointResource {
    id: number;
    sharepoint_item_id: number;
    resource_type_id: number;
    generic: boolean;
    max_unit: number;
    windows_account_id: string;
    security_group: string;
    modified: string;
    created: string;
    author_id: number;
    editor_id: number;
    content_type_id: string;
    ui_version_string: string;
    attachments: boolean;
    file_system_object_type: number;
    imported_at: string;
    title?: string;
    etag?: string;
    guid?: string;
}

export interface ResourcesResponse {
    success: boolean;
    data: SharePointResource[];
    total: number;
    page: number;
    per_page: number;
    message?: string;
}

export interface ImportResourcesRequest {
    limit?: number;
    filters?: Record<string, any>;
}

export interface ImportResourcesResponse {
    success: boolean;
    message: string;
    imported_count: number;
    errors: string[];
}

export interface ResourcesStatusResponse {
    total_resources: number;
    derniere_sync: string;
    sync_recente: number;
    premiere_import: string;
    dernier_import: string;
    status: string;
}

class ResourceService {
    private readonly baseUrl = '/import/ressources';

    /**
     * Récupérer la liste des ressources importées
     */
    async getResources(page: number = 1, perPage: number = 50, search?: string): Promise<ResourcesResponse> {
        try {
            const params: any = {
                page,
                per_page: perPage
            };
            
            if (search) {
                params.search = search;
            }
            
            const response = await api.get('/data/sharepoint-ressources', { params });
            return {
                success: true,
                data: response.data.data || [],
                total: response.data.total || 0,
                page: response.data.page || 1,
                per_page: response.data.per_page || perPage
            };
        } catch (error: any) {
            console.error('Erreur récupération ressources:', error);
            return {
                success: false,
                data: [],
                total: 0,
                page: 1,
                per_page: perPage,
                message: error.response?.data?.message || 'Erreur lors du chargement des ressources'
            };
        }
    }

    /**
     * Récupérer les détails d'une ressource spécifique
     */
    async getResourceDetail(resourceId: number): Promise<any> {
        try {
            const response = await api.get(`/data/sharepoint-ressources/${resourceId}`);
            return response.data;
        } catch (error: any) {
            console.error(`Erreur récupération ressource ${resourceId}:`, error);
            throw error;
        }
    }

    /**
     * Importer les ressources depuis SharePoint
     */
    async importResources(request: ImportResourcesRequest = {}): Promise<ImportResourcesResponse> {
        try {
            const response = await api.post(this.baseUrl, request);
            return response.data;
        } catch (error: any) {
            console.error('Erreur import ressources:', error);
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
     * Récupérer le statut de l'import des ressources
     */
    async getStatus(): Promise<ResourcesStatusResponse | null> {
        try {
            const response = await api.get(`${this.baseUrl}/status`);
            return response.data;
        } catch (error: any) {
            console.error('Erreur statut ressources:', error);
            return null;
        }
    }
}

// Instance singleton du service
export const resourceService = new ResourceService();
export default resourceService;

