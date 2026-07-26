// Types for the Generic Import Wizard

export interface FileColumn {
    name: string;
    detectedType: string;
    sampleValues: string[];
    nullCount: number;
    uniqueCount: number;
}

export interface TableInfo {
    table_name: string;
    table_schema: string;
    description: string | null;
    column_count: number;
    row_count: number;
}

export interface TargetColumn {
    name: string;
    data_type: string;
    is_nullable: string;
    column_default: string | null;
    character_maximum_length?: number;
    isRequired: boolean;
    isPrimaryKey: boolean;
    constraints: string[];
}

export interface ColumnMapping {
    source: string;
    sourceType: string;
    target: string | null;
    targetType: string | null;
    confidence: number;
    autoMapped: boolean;
    ignored: boolean;
}

export interface ValidationError {
    type: string;
    source?: string;
    target?: string;
    count?: number;
    maxLength?: number;
    message: string;
}

export interface PreviewRow {
    rowNumber: number;
    data: Record<string, string | null>;
    errors: string[];
}

export interface ImportResult {
    success: boolean;
    message: string;
    successCount: number;
    insertedCount?: number;
    updatedCount?: number;
    errorCount: number;
    errors: Array<{ row: number; error: string }>;
    targetTable: string;
    mode?: string;
}

export type ImportMode = 'insert' | 'upsert' | 'update_only';

export interface ImportOptions {
    mode: ImportMode;
    conflictColumns: string[];
    updateColumns: string[];
    commitOnSuccess: boolean;
    commitPartial: boolean;
}

export interface FileAnalysis {
    fileId: string;
    filename: string;
    fileSize: number;
    columns: FileColumn[];
    rowCount: number;
    encoding: string;
    delimiter?: string;
}

export interface SchemaInfo {
    schema_name: string;
    table_count: number;
}

export interface ImportState {
    step: number;
    file: File | null;
    fileId: string | null;
    fileColumns: FileColumn[];
    rowCount: number;
    availableSchemas: SchemaInfo[];
    tables: TableInfo[];
    selectedTable: string | null;
    selectedSchema: string;
    targetColumns: TargetColumn[];
    mappings: ColumnMapping[];
    validationErrors: ValidationError[];
    validationWarnings: ValidationError[];
    previewData: PreviewRow[];
    importOptions: ImportOptions;
    importing: boolean;
    importResult: ImportResult | null;
}

export type ImportStep = 0 | 1 | 2 | 3 | 4;

export const STEPS = [
    { label: 'Upload', description: 'Sélectionner le fichier' },
    { label: 'Aperçu', description: 'Prévisualiser & choisir la table' },
    { label: 'Mapping', description: 'Associer les colonnes' },
    { label: 'Validation', description: 'Vérifier les données' },
    { label: 'Import', description: 'Charger les données' }
] as const;
