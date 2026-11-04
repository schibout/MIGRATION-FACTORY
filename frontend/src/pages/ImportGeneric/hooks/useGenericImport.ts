import { useCallback, useState } from 'react';
import api from '../../../services/api';
import {
    ImportOptions,
    ImportState
} from '../types';

const initialState: ImportState = {
    step: 0,
    file: null,
    fileId: null,
    fileColumns: [],
    rowCount: 0,
    availableSchemas: [],
    tables: [],
    selectedTable: null,
    selectedSchema: 'raw_data',
    targetColumns: [],
    mappings: [],
    validationErrors: [],
    validationWarnings: [],
    previewData: [],
    importOptions: {
        mode: 'insert',
        conflictColumns: [],
        updateColumns: [],
        commitOnSuccess: true,
        commitPartial: false,
        truncate: false
    },
    importing: false,
    importResult: null
};

export interface UseGenericImportReturn {
    state: ImportState;
    loading: boolean;
    error: string | null;
    // Actions
    analyzeFile: (file: File) => Promise<void>;
    loadSchemas: () => Promise<void>;
    setSchema: (schema: string) => void;
    loadTables: (search?: string) => Promise<void>;
    selectTable: (tableName: string) => Promise<void>;
    generateMapping: () => Promise<void>;
    updateMapping: (sourceCol: string, targetCol: string | null) => void;
    toggleIgnore: (sourceCol: string) => void;
    validateMapping: () => Promise<void>;
    setImportOptions: (options: Partial<ImportOptions>) => void;
    executeImport: () => Promise<void>;
    goToStep: (step: number) => void;
    reset: () => void;
    setError: (error: string | null) => void;
}

// Ecran d'import a cible imposee (ex. Finance > Articles) : memes etapes, mais les
// routes suggest-mapping / validate-mapping / execute sont celles de baseUrl, la
// table est fixe et `extra` est ajoute au corps de l'execution.
export interface GenericImportConfig {
    baseUrl?: string;
    fixedTable?: string;
    extra?: Record<string, unknown>;
}

export function useGenericImport(config: GenericImportConfig = {}): UseGenericImportReturn {
    const { baseUrl = '/import-generic', fixedTable, extra } = config;
    const depart: ImportState = fixedTable ? { ...initialState, selectedTable: fixedTable } : initialState;
    const [state, setState] = useState<ImportState>(depart);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Analyze uploaded file
    const analyzeFile = useCallback(async (file: File) => {
        setLoading(true);
        setError(null);

        try {
            const formData = new FormData();
            formData.append('file', file);

            const response = await api.post('/import-generic/analyze-file', formData, {
                headers: { 'Content-Type': 'multipart/form-data' }
            });

            setState(prev => ({
                ...prev,
                file,
                fileId: response.data.fileId,
                fileColumns: response.data.columns,
                rowCount: response.data.rowCount,
                step: 1
            }));
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors de l\'analyse du fichier');
            throw err;
        } finally {
            setLoading(false);
        }
    }, []);

    // Load available schemas
    const loadSchemas = useCallback(async () => {
        try {
            const response = await api.get('/import-generic/schemas');
            const schemas = response.data.schemas || [];
            setState(prev => ({ 
                ...prev, 
                availableSchemas: schemas,
                // Keep current selection or auto-select raw_data if available
                selectedSchema: prev.selectedSchema || 
                    schemas.find((s: any) => s.schema_name === 'raw_data')?.schema_name ||
                    schemas.find((s: any) => s.table_count > 0)?.schema_name ||
                    'raw_data'
            }));
        } catch (err: any) {
            console.error('Erreur chargement schémas:', err);
        }
    }, []);

    // Set selected schema
    const setSchema = useCallback((schema: string) => {
        setState(prev => ({ 
            ...prev, 
            selectedSchema: schema, 
            selectedTable: null,
            tables: [],
            targetColumns: []
        }));
    }, []);

    // Load available tables
    const loadTables = useCallback(async (search: string = '') => {
        try {
            const response = await api.get(
                `/import-generic/tables?schema=${state.selectedSchema}&search=${search}`
            );
            setState(prev => ({ ...prev, tables: response.data.tables || [] }));
        } catch (err: any) {
            console.error('Erreur chargement tables:', err);
        }
    }, [state.selectedSchema]);

    // Load target table columns
    const loadTargetColumns = useCallback(async (tableName: string) => {
        try {
            const response = await api.get(
                `/import-generic/tables/${tableName}/columns?schema=${state.selectedSchema}`
            );
            setState(prev => ({ ...prev, targetColumns: response.data.columns || [] }));
        } catch (err: any) {
            console.error('Erreur chargement colonnes:', err);
        }
    }, [state.selectedSchema]);

    // Select target table
    const selectTable = useCallback(async (tableName: string) => {
        setState(prev => ({ ...prev, selectedTable: tableName }));
        await loadTargetColumns(tableName);
    }, [loadTargetColumns]);

    // Generate automatic mapping
    const generateMapping = useCallback(async () => {
        if (!state.fileId || !state.selectedTable) return;

        setLoading(true);
        setError(null);

        try {
            const response = await api.post(`${baseUrl}/suggest-mapping`, {
                fileId: state.fileId,
                targetTable: state.selectedTable,
                schema: state.selectedSchema
            });

            setState(prev => ({
                ...prev,
                mappings: response.data.mappings,
                targetColumns: response.data.targetColumns,
                step: 2
            }));
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors de la génération du mapping');
            throw err;
        } finally {
            setLoading(false);
        }
    }, [baseUrl, state.fileId, state.selectedTable, state.selectedSchema]);

    // Update a single mapping
    const updateMapping = useCallback((sourceCol: string, targetCol: string | null) => {
        setState(prev => ({
            ...prev,
            mappings: prev.mappings.map(m =>
                m.source === sourceCol
                    ? { ...m, target: targetCol, autoMapped: false, ignored: targetCol === null }
                    : m
            )
        }));
    }, []);

    // Toggle ignore flag for a column
    const toggleIgnore = useCallback((sourceCol: string) => {
        setState(prev => ({
            ...prev,
            mappings: prev.mappings.map(m =>
                m.source === sourceCol
                    ? { ...m, ignored: !m.ignored, target: m.ignored ? m.target : null }
                    : m
            )
        }));
    }, []);

    // Validate the mapping
    const validateMapping = useCallback(async () => {
        if (!state.fileId || !state.selectedTable) return;

        setLoading(true);
        setError(null);

        try {
            const response = await api.post(`${baseUrl}/validate-mapping`, {
                fileId: state.fileId,
                targetTable: state.selectedTable,
                mappings: state.mappings,
                schema: state.selectedSchema,
                previewRows: 10
            });

            setState(prev => ({
                ...prev,
                validationErrors: response.data.errors,
                validationWarnings: response.data.warnings,
                previewData: response.data.previewData,
                step: 3
            }));
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors de la validation');
            throw err;
        } finally {
            setLoading(false);
        }
    }, [baseUrl, state.fileId, state.selectedTable, state.mappings, state.selectedSchema]);

    // Set import options
    const setImportOptions = useCallback((options: Partial<ImportOptions>) => {
        setState(prev => ({
            ...prev,
            importOptions: { ...prev.importOptions, ...options }
        }));
    }, []);

    // Execute the import
    const executeImport = useCallback(async () => {
        if (!state.fileId || !state.selectedTable) return;

        setState(prev => ({ ...prev, importing: true, step: 4 }));
        setError(null);

        try {
            const response = await api.post(`${baseUrl}/execute`, {
                ...extra,
                fileId: state.fileId,
                targetTable: state.selectedTable,
                mappings: state.mappings,
                schema: state.selectedSchema,
                options: {
                    mode: state.importOptions.mode,
                    conflictColumns: state.importOptions.conflictColumns,
                    updateColumns: state.importOptions.updateColumns,
                    commitOnSuccess: state.importOptions.commitOnSuccess,
                    commitPartial: state.importOptions.commitPartial,
                    truncate: state.importOptions.truncate && state.importOptions.mode !== 'update_only'
                }
            });

            setState(prev => ({
                ...prev,
                importing: false,
                importResult: response.data
            }));
        } catch (err: any) {
            // 400 de /execute : { message, errorCount, errors: [{ row, error }] }, sans champ error
            const data = err.response?.data;
            const premiere = data?.errors?.[0];
            setError(data?.error || (premiere
                ? `${data.message} : ${data.errorCount} ligne(s) en erreur. Ligne ${premiere.row} : ${premiere.error}`
                : data?.message || 'Erreur lors de l\'import'));
            setState(prev => ({ ...prev, importing: false }));
            throw err;
        }
    }, [baseUrl, extra, state.fileId, state.selectedTable, state.mappings, state.selectedSchema, state.importOptions]);

    // Navigate to a specific step
    const goToStep = useCallback((step: number) => {
        setState(prev => ({ ...prev, step }));
    }, []);

    // Reset the wizard
    const reset = useCallback(() => {
        setState(fixedTable ? { ...initialState, selectedTable: fixedTable } : initialState);
        setError(null);
    }, [fixedTable]);

    return {
        state,
        loading,
        error,
        analyzeFile,
        loadSchemas,
        setSchema,
        loadTables,
        selectTable,
        generateMapping,
        updateMapping,
        toggleIgnore,
        validateMapping,
        setImportOptions,
        executeImport,
        goToStep,
        reset,
        setError
    };
}

export default useGenericImport;
