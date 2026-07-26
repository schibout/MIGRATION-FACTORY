import api from './api';

export interface ResourceColumn {
    name: string;
    label: string;
    type: string;
}

export interface ResourceTableData {
    columns: ResourceColumn[];
    rows: any[];
    total: number;
    page: number;
    pageSize: number;
}

export interface ExportOptions {
    format: 'csv' | 'excel';
    filename?: string;
    includeHeaders?: boolean;
    searchTerm?: string;
    filters?: Record<string, { value: string; operator: string }>;
}

class ResourcesService {
    /**
     * Récupère les données d'une table de ressources avec pagination, tri et filtres
     */
    async getTableData(
        endpoint: string,
        page: number = 0,
        pageSize: number = 50,
        sortField: string = '',
        sortDirection: 'asc' | 'desc' = 'asc',
        searchTerm: string = '',
        filters: Record<string, { value: string; operator: string }> = {}
    ): Promise<ResourceTableData> {
        try {
            const params: any = {
                page: page + 1,
                per_page: pageSize,
                search: searchTerm
            };

            if (sortField) {
                params.sortField = sortField;
                params.sortDirection = sortDirection;
            }

            if (Object.keys(filters).length > 0) {
                params.filters = JSON.stringify(filters);
            }

            const response = await api.get(`/resources/${endpoint}`, { params });

            // Extraire les colonnes depuis la première ligne de données
            const columns: ResourceColumn[] = [];
            if (response.data.data && response.data.data.length > 0) {
                const firstRow = response.data.data[0];
                Object.keys(firstRow).forEach(key => {
                    columns.push({
                        name: key,
                        label: this.formatColumnLabel(key),
                        type: typeof firstRow[key]
                    });
                });
            }

            return {
                columns,
                rows: response.data.data || [],
                total: response.data.total || 0,
                page: page,
                pageSize: pageSize
            };
        } catch (error) {
            console.error('Erreur lors du chargement des données:', error);
            throw error;
        }
    }

    /**
     * Formate le nom d'une colonne pour l'affichage
     */
    private formatColumnLabel(columnName: string): string {
        return columnName
            .split('_')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1))
            .join(' ');
    }

    /**
     * Met à jour un enregistrement
     */
    async updateRecord(endpoint: string, recordId: any, data: Record<string, any>): Promise<any> {
        try {
            const response = await api.put(`/resources/${endpoint}/${recordId}`, data);
            return response.data;
        } catch (error) {
            console.error('Erreur lors de la mise à jour:', error);
            throw error;
        }
    }

    /**
     * Supprime un enregistrement
     */
    async deleteRecord(endpoint: string, recordId: any): Promise<any> {
        try {
            const response = await api.delete(`/resources/${endpoint}/${recordId}`);
            return response.data;
        } catch (error) {
            console.error('Erreur lors de la suppression:', error);
            throw error;
        }
    }

    /**
     * Exporte les données au format CSV ou Excel
     */
    async exportTableData(
        endpoint: string,
        fields: string[],
        options: ExportOptions
    ): Promise<Blob> {
        try {
            const params: any = {
                format: options.format,
                fields: fields.join(',')
            };

            if (options.searchTerm) {
                params.search = options.searchTerm;
            }

            if (options.filters && Object.keys(options.filters).length > 0) {
                params.filters = JSON.stringify(options.filters);
            }

            const response = await api.get(`/resources/${endpoint}/export`, {
                params,
                responseType: 'blob'
            });

            return response.data;
        } catch (error) {
            console.error('Erreur lors de l\'export:', error);
            throw error;
        }
    }

    /**
     * Télécharge un blob en tant que fichier
     */
    downloadExport(blob: Blob, filename: string): void {
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    }

    /**
     * Récupère les métadonnées d'une table (colonnes disponibles)
     */
    async getTableMetadata(endpoint: string): Promise<ResourceColumn[]> {
        try {
            const response = await api.get(`/resources/${endpoint}/metadata`);
            return response.data.columns || [];
        } catch (error) {
            console.error('Erreur lors du chargement des métadonnées:', error);
            // Fallback: retourner un tableau vide
            return [];
        }
    }
}

export default new ResourcesService();

