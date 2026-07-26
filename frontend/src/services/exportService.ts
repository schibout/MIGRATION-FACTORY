import api from './api';

export interface ExportConfig {
  selectedTables: string[];
  includeHeaders: boolean;
  includeInactive: boolean;
}

export interface ExportQuery {
  id: number;
  table_name: string;
  table_schema: string;
  display_name: string;
  column_list: string;
  sql_query: string;
  description: string;
  category: string;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string;
  updated_by?: string;
}

export interface ExportQueriesResponse {
  queries: ExportQuery[];
  grouped_queries: Record<string, ExportQuery[]>;
  total: number;
}

// Cache des requêtes pour éviter les appels répétés
let queriesCache: Record<string, ExportQuery> = {};
let cacheTimestamp: number = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

// Fonction pour charger les requêtes d'export depuis l'API
export const loadExportQueries = async (category?: string, forceRefresh = false): Promise<ExportQueriesResponse> => {
  try {
    const now = Date.now();
    
    // Vérifier si le cache est encore valide et si on ne force pas le refresh
    if (!forceRefresh && cacheTimestamp > 0 && (now - cacheTimestamp) < CACHE_DURATION && Object.keys(queriesCache).length > 0) {
      const cachedQueries = Object.values(queriesCache);
      const filteredQueries = category ? cachedQueries.filter(q => q.category === category) : cachedQueries;
      
      // Grouper par catégorie
      const grouped_queries: Record<string, ExportQuery[]> = {};
      filteredQueries.forEach(query => {
        if (!grouped_queries[query.category]) {
          grouped_queries[query.category] = [];
        }
        grouped_queries[query.category].push(query);
      });
      
      return {
        queries: filteredQueries,
        grouped_queries,
        total: filteredQueries.length
      };
    }

    console.log('🔄 Chargement des requêtes d\'export depuis l\'API...');
    
    const params: Record<string, string> = {};
    if (category) {
      params.category = category;
    }
    
    const response = await api.get('/export/queries', { params });
    const data: ExportQueriesResponse = response.data;
    
    // Mettre à jour le cache
    queriesCache = {};
    data.queries.forEach(query => {
      queriesCache[query.table_name] = query;
    });
    cacheTimestamp = now;
    
    console.log(`✅ ${data.total} requêtes d'export chargées avec succès`);
    return data;
    
  } catch (error) {
    console.error('❌ Erreur lors du chargement des requêtes d\'export:', error);
    throw new Error('Impossible de charger les requêtes d\'export');
  }
};

// Fonction pour récupérer une requête spécifique
export const getExportQuery = async (tableName: string): Promise<ExportQuery> => {
  try {
    // Vérifier d'abord le cache
    if (queriesCache[tableName]) {
      return queriesCache[tableName];
    }
    
    console.log(`🔄 Récupération de la requête pour: ${tableName}`);
    const response = await api.get(`/export/queries/${tableName}`);
    const query: ExportQuery = response.data;
    
    // Mettre à jour le cache
    queriesCache[tableName] = query;
    
    return query;
    
  } catch (error) {
    console.error(`❌ Erreur lors de la récupération de la requête ${tableName}:`, error);
    throw new Error(`Requête pour la table '${tableName}' non trouvée`);
  }
};

// Fonction pour exécuter une requête SQL - maintenant dynamique
export const executeQuery = async (tableName: string): Promise<any[]> => {
  try {
    console.log(`🔄 Extraction des données pour: ${tableName}`);
    
    // Utiliser le nouvel endpoint qui exécute directement la requête
    const response = await api.post(`/export/queries/${tableName}/execute`);

    // L'endpoint retourne directement un array de données
    return response.data || [];
  } catch (error: any) {
    console.error(`❌ Erreur pour ${tableName}:`, error);
    
    // Améliorer les messages d'erreur
    if (error.response?.status === 404) {
      throw new Error(`Table '${tableName}' non configurée pour l'export`);
    } else if (error.response?.status === 403) {
      throw new Error(`Export de la table '${tableName}' désactivé`);
    } else if (error.response?.data?.error) {
      throw new Error(error.response.data.error);
    } else {
      throw new Error(`Erreur lors de l'extraction de ${tableName}`);
    }
  }
};

// Fonction pour exporter toutes les tables - utilise directement l'API backend
export const exportSupplierData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export ZIP via l\'API backend');
    console.log('📋 Configuration:', config);
    
    const separatorToSend = config.csvSeparator || ';';
    console.log('🔧 Séparateur CSV à envoyer:', `"${separatorToSend}"`, 'Type:', typeof separatorToSend);

    // Appeler l'API backend pour générer le fichier ZIP
    const response = await api.post('/export/suppliers', {
      selectedTables: config.selectedTables,
      format: 'zip', // Format fixe
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'  // Utiliser le point-virgule par défaut
    }, {
      responseType: 'blob' // Important pour télécharger le fichier binaire
    });

    return handleExportResponse(response, 'suppliers');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export des fournisseurs:', error);
    throw error;
  }
};

// Fonction pour exporter les données des articles
export const exportArticlesData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export articles ZIP via l\'API backend');
    console.log('📋 Configuration:', config);

    // Appeler l'API backend pour générer le fichier ZIP
    const response = await api.post('/export/articles', {
      selectedTables: config.selectedTables,
      format: 'zip', // Format fixe
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'  // Toujours utiliser le point-virgule
    }, {
      responseType: 'blob' // Important pour télécharger le fichier binaire
    });

    return handleExportResponse(response, 'articles');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export des articles:', error);
    throw error;
  }
};

// Fonction pour exporter les données de maintenance
export const exportMaintenanceData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export maintenance via l\'API backend');
    console.log('📋 Configuration:', config);

    // Appeler l'API backend pour générer le fichier ZIP
    const response = await api.post('/export/maintenance', {
      selectedTables: config.selectedTables,
      format: 'zip', // Format fixe
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'  // Toujours utiliser le point-virgule
    }, {
      responseType: 'blob' // Important pour télécharger le fichier binaire
    });

    return handleExportResponse(response, 'maintenance');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export de maintenance:', error);
    throw error;
  }
};

// Fonction pour exporter les données de structure maintenance
export const exportStructureMaintenanceData = async (config: ExportConfig) => {
  try {
    const response = await api.post('/export/maintenance', {
      selectedTables: config.selectedTables,
      format: 'zip',
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'
    }, {
      responseType: 'blob'
    });

    return handleExportResponse(response, 'structure_maintenance');
  } catch (error) {
    console.error('Erreur lors de l\'export structure maintenance:', error);
    throw error;
  }
};

// Fonction pour exporter les données PM Action
export const exportPmActionData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export PM Action via l\'API backend');
    console.log('📋 Configuration:', config);

    const response = await api.post('/export/maintenance', {
      selectedTables: config.selectedTables,
      format: 'zip',
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'
    }, {
      responseType: 'blob'
    });

    return handleExportResponse(response, 'pm_action');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export PM Action:', error);
    throw error;
  }
};

// Fonction pour exporter les données Opérations de maintenance (JT Task)
export const exportOperationData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export Opérations via l\'API backend');
    console.log('📋 Configuration:', config);

    const response = await api.post('/export/maintenance', {
      selectedTables: config.selectedTables,
      format: 'zip',
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'
    }, {
      responseType: 'blob'
    });

    return handleExportResponse(response, 'operation');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export Opérations:', error);
    throw error;
  }
};

// Fonction pour exporter les données des clients
export const exportClientsData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export clients via l\'API backend');
    console.log('📋 Configuration:', config);

    // Appeler l'API backend pour générer le fichier ZIP
    const response = await api.post('/export/clients', {
      selectedTables: config.selectedTables,
      format: 'zip', // Format fixe
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'  // Toujours utiliser le point-virgule
    }, {
      responseType: 'blob' // Important pour télécharger le fichier binaire
    });

    return handleExportResponse(response, 'clients');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export des clients:', error);
    throw error;
  }
};

// Fonction pour exporter les données des projets
export const exportProjectsData = async (config: ExportConfig) => {
  try {
    console.log('🚀 Démarrage de l\'export projets ZIP via l\'API backend');
    console.log('📋 Configuration:', config);

    // Appeler l'API backend pour générer le fichier ZIP
    const response = await api.post('/export/projects', {
      selectedTables: config.selectedTables,
      format: 'zip', // Format fixe
      includeHeaders: config.includeHeaders,
      includeInactive: config.includeInactive,
      csvSeparator: ';'  // Toujours utiliser le point-virgule
    }, {
      responseType: 'blob' // Important pour télécharger le fichier binaire
    });

    return handleExportResponse(response, 'projects');
  } catch (error) {
    console.error('❌ Erreur lors de l\'export des projets:', error);
    throw error;
  }
};

// Fonction commune pour gérer les réponses d'export
const handleExportResponse = (response: any, type: string) => {
  // Récupérer les métadonnées depuis les headers
  const exportSummary = response.headers['x-export-summary'];
  const exportCategory = response.headers['x-export-category'];
  const exportTablesCount = response.headers['x-export-tables-count'];
  const exportSizeBytes = response.headers['x-export-size-bytes'];

  // Créer l'URL de téléchargement
  const blob = new Blob([response.data], { type: 'application/zip' });
  const downloadUrl = window.URL.createObjectURL(blob);

  // Extraire le nom de fichier du header Content-Disposition
  const contentDisposition = response.headers['content-disposition'];
  let filename = `export_${type}_${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.zip`;
  
  if (contentDisposition) {
    const filenameMatch = contentDisposition.match(/filename="(.+)"/);
    if (filenameMatch) {
      filename = filenameMatch[1];
    }
  }

  // Déclencher le téléchargement automatique
  const link = document.createElement('a');
  link.href = downloadUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  // Libérer l'URL
  window.URL.revokeObjectURL(downloadUrl);

  console.log(`✅ Export ${type} ZIP téléchargé: ${filename}`);
  console.log(`📊 Résumé: ${exportSummary}`);
  console.log(`📂 Catégorie: ${exportCategory}`);
  console.log(`📋 Tables: ${exportTablesCount}`);
  console.log(`📏 Taille: ${exportSizeBytes} bytes`);

  // Parser le résumé et les erreurs de manière sécurisée
  let parsedSummary = {};
  let parsedErrors = {};
  
  try {
    if (exportSummary) {
      parsedSummary = JSON.parse(exportSummary);
    }
  } catch (e) {
    console.warn('⚠️ Impossible de parser le résumé d\'export:', exportSummary);
  }

  return {
    success: true,
    filename,
    summary: parsedSummary,
    errors: parsedErrors,
    category: exportCategory,
    tablesCount: exportTablesCount,
    sizeBytes: exportSizeBytes
  };
};

// Fonction pour convertir en CSV
export const convertToCSV = (data: any[], headers: string[], includeHeaders: boolean): string => {
  let csv = '';
  
  if (includeHeaders && headers.length > 0) {
    csv += headers.join(',') + '\n';
  }
  
  data.forEach(row => {
    const values = headers.map(header => {
      const value = row[header];
      if (value === null || value === undefined) return '';
      const stringValue = String(value);
      if (stringValue.includes(',') || stringValue.includes('"')) {
        return `"${stringValue.replace(/"/g, '""')}"`;
      }
      return stringValue;
    });
    csv += values.join(',') + '\n';
  });
  
  return csv;
};

// Nouvelle fonction pour récupérer les catégories disponibles
export const getExportCategories = async (): Promise<{name: string, count: number}[]> => {
  try {
    const response = await api.get('/export/categories');
    return response.data.categories;
  } catch (error) {
    console.error('❌ Erreur lors de la récupération des catégories:', error);
    return [];
  }
};

// Fonction pour rafraîchir le cache
export const refreshQueriesCache = async (): Promise<void> => {
  try {
    await loadExportQueries(undefined, true);
    console.log('✅ Cache des requêtes rafraîchi');
  } catch (error) {
    console.error('❌ Erreur lors du rafraîchissement du cache:', error);
    throw error;
  }
};

// Fonction utilitaire pour vérifier si une table est disponible
export const isTableAvailable = (tableName: string): boolean => {
  return queriesCache[tableName]?.is_active || false;
};

// Fonction pour obtenir la liste des tables disponibles
export const getAvailableTables = async (category?: string): Promise<string[]> => {
  try {
    const data = await loadExportQueries(category);
    return data.queries
      .filter(query => query.is_active)
      .map(query => query.table_name);
  } catch (error) {
    console.error('❌ Erreur lors de la récupération des tables disponibles:', error);
    return [];
  }
};

// Fonctions d'administration (pour les interfaces d'admin)

// Récupérer toutes les requêtes d'export (pour l'administration)
export const getAllExportQueries = async (): Promise<ExportQuery[]> => {
  try {
    console.log('🔄 Chargement de toutes les requêtes d\'export...');
    const response = await api.get('/export/queries');
    return response.data.queries || [];
  } catch (error) {
    console.error('❌ Erreur lors du chargement des requêtes:', error);
    throw error;
  }
};

export const createExportQuery = async (query: Partial<ExportQuery>): Promise<ExportQuery> => {
  try {
    console.log('➕ Création d\'une nouvelle requête d\'export');
    const response = await api.post('/export/queries', query);
    
    // Invalider le cache
    cacheTimestamp = 0;
    queriesCache = {};
    
    return response.data;
  } catch (error) {
    console.error('❌ Erreur lors de la création de la requête:', error);
    throw error;
  }
};

export const updateExportQuery = async (tableName: string, updates: Partial<ExportQuery>): Promise<void> => {
  try {
    console.log(`🔄 Mise à jour de la requête: ${tableName}`);
    console.log('📋 Données envoyées:', updates);
    
    // ✅ CORRECTION: S'assurer que category est présent
    if (!updates.category) {
      console.error('❌ ERREUR: Le champ category est manquant dans les données');
      throw new Error('Le champ category est requis pour la mise à jour');
    }
    
    await api.put(`/export/queries/${tableName}`, updates);
    
    // Invalider le cache
    cacheTimestamp = 0;
    queriesCache = {};
    
  } catch (error) {
    console.error('❌ Erreur lors de la mise à jour de la requête:', error);
    throw error;
  }
};

export const deleteExportQuery = async (tableName: string): Promise<void> => {
  try {
    console.log(`🗑️ Suppression de la requête: ${tableName}`);
    await api.delete(`/export/queries/${tableName}`);
    
    // Invalider le cache
    cacheTimestamp = 0;
    queriesCache = {};
    
  } catch (error) {
    console.error('❌ Erreur lors de la suppression de la requête:', error);
    throw error;
  }
};

// Tester une requête SQL
export const testQuery = async (columnList: string, schema: string = 'public', tableName: string): Promise<any[]> => {
  try {
    console.log('🧪 Test de la requête avec column_list...');
    const response = await api.post('/export/queries/test', {
      column_list: columnList,
      table_schema: schema,
      table_name: tableName
    });
    
    if (response.data.success) {
      console.log(`✅ Test réussi: ${response.data.sample_data?.length || 0} lignes d'aperçu sur ${response.data.total_rows} total`);
      return response.data.sample_data || [];
    } else {
      throw new Error(response.data.error || 'Erreur lors du test de la requête');
    }
  } catch (error: any) {
    console.error('❌ Erreur lors du test de la requête:', error);
    if (error.response?.data?.error) {
      throw new Error(error.response.data.error);
    }
    throw error;
  }
};

export default {
  executeQuery,
  exportSupplierData,
  exportArticlesData,
  exportMaintenanceData,
  exportStructureMaintenanceData,
  exportClientsData,
  exportProjectsData,
  convertToCSV,
  loadExportQueries,
  getExportQuery,
  getExportCategories,
  refreshQueriesCache,
  isTableAvailable,
  getAvailableTables,
  createExportQuery,
  updateExportQuery,
  deleteExportQuery
}; 