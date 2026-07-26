// Types pour la gestion des fichiers et validation

export type SupportedFileFormat = 'csv' | 'xlsx' | 'xls';

export type FileValidationLevel = 'error' | 'warning' | 'info';

export interface FileValidationRule {
    field: string;
    type: 'required' | 'format' | 'range' | 'unique' | 'reference' | 'custom';
    message: string;
    params?: Record<string, any>;
}

export interface FileValidationResult {
    valid: boolean;
    errors: FileValidationError[];
    warnings: FileValidationWarning[];
    infos: FileValidationInfo[];
}

export interface FileValidationError {
    row?: number;
    column?: string;
    field?: string;
    code: string;
    message: string;
    value?: any;
    level: 'error';
}

export interface FileValidationWarning {
    row?: number;
    column?: string;
    field?: string;
    code: string;
    message: string;
    value?: any;
    level: 'warning';
}

export interface FileValidationInfo {
    row?: number;
    column?: string;
    field?: string;
    code: string;
    message: string;
    value?: any;
    level: 'info';
}

export interface FileMetadata {
    name: string;
    size: number;
    type: string;
    lastModified: number;
    extension: SupportedFileFormat;
    checksum?: string;
}

export interface FileParseResult {
    success: boolean;
    data: Record<string, any>[];
    headers: string[];
    totalRows: number;
    validRows: number;
    invalidRows: number;
    metadata: FileMetadata;
    errors: FileValidationError[];
    warnings: FileValidationWarning[];
    processingTime: number;
}

export interface FilePreview {
    headers: string[];
    rows: Record<string, any>[];
    totalRows: number;
    sampleSize: number;
    encoding: string;
    delimiter?: string; // Pour les CSV
    hasHeaders: boolean;
}

export interface ColumnMapping {
    sourceColumn: string;
    targetColumn: string;
    required: boolean;
    dataType: 'string' | 'number' | 'date' | 'boolean' | 'email' | 'phone';
    format?: string;
    defaultValue?: any;
    transformation?: string;
}

export interface FileTypeTemplate {
    type: string;
    name: string;
    description: string;
    fileFormats: SupportedFileFormat[];
    requiredColumns: string[];
    optionalColumns: string[];
    columnMappings: ColumnMapping[];
    validationRules: FileValidationRule[];
    examples: string[];
    sampleFile?: string;
    documentation?: string;
}

export interface FileUploadProgress {
    uploadId: string;
    fileName: string;
    fileSize: number;
    bytesUploaded: number;
    percentage: number;
    speed: number; // bytes per second
    timeRemaining: number; // seconds
    status: 'uploading' | 'processing' | 'completed' | 'failed' | 'cancelled';
    error?: string;
}

export interface FileChunk {
    index: number;
    start: number;
    end: number;
    data: Blob;
    uploaded: boolean;
    retries: number;
}

export interface ChunkedUploadConfig {
    chunkSize: number; // bytes
    maxRetries: number;
    parallelUploads: number;
    checksumValidation: boolean;
}

export interface FileProcessingOptions {
    skipEmptyRows: boolean;
    trimWhitespace: boolean;
    convertEncoding: boolean;
    targetEncoding: string;
    dateFormat?: string;
    numberFormat?: string;
    thousandsSeparator?: string;
    decimalSeparator?: string;
    booleanTrueValues: string[];
    booleanFalseValues: string[];
    nullValues: string[];
}

export interface FileCompressionInfo {
    compressed: boolean;
    format?: 'zip' | 'gzip' | 'bzip2';
    originalSize?: number;
    compressedSize?: number;
    compressionRatio?: number;
}

export interface FileSecurityScan {
    scanned: boolean;
    safe: boolean;
    threats: FileThreat[];
    scanTime: number;
    scanEngine: string;
}

export interface FileThreat {
    type: 'virus' | 'malware' | 'suspicious_content' | 'large_file' | 'invalid_format';
    severity: 'low' | 'medium' | 'high' | 'critical';
    description: string;
    recommendation: string;
}

export interface FileQuarantine {
    quarantined: boolean;
    reason: string;
    quarantineTime: string;
    releaseTime?: string;
    approvedBy?: string;
}

// Types pour les formats spécifiques

export interface CSVParsingOptions {
    delimiter: string;
    quote: string;
    escape: string;
    skipLinesStart: number;
    skipLinesEnd: number;
    encoding: string;
    hasHeaders: boolean;
}

export interface ExcelParsingOptions {
    sheetName?: string;
    sheetIndex?: number;
    startRow: number;
    endRow?: number;
    startColumn?: string;
    endColumn?: string;
    hasHeaders: boolean;
    evaluateFormulas: boolean;
}

// Types pour les transformations de données

export interface DataTransformation {
    id: string;
    name: string;
    description: string;
    type: 'format' | 'calculate' | 'lookup' | 'conditional' | 'custom';
    inputFields: string[];
    outputField: string;
    params: Record<string, any>;
    enabled: boolean;
}

export interface FieldFormatting {
    field: string;
    inputFormat: string;
    outputFormat: string;
    locale?: string;
    timezone?: string;
}

// Types pour les templates et exemples

export interface FileExample {
    name: string;
    description: string;
    fileType: string;
    downloadUrl: string;
    previewData: Record<string, any>[];
    instructions: string[];
}

export interface FileTemplate {
    id: string;
    name: string;
    category: string;
    description: string;
    fileType: string;
    headers: string[];
    sampleData: Record<string, any>[];
    validationRules: FileValidationRule[];
    instructions: string[];
    downloadUrl: string;
    lastUpdated: string;
    version: string;
}

// Types pour l'historique et le cache

export interface FileProcessingHistory {
    id: string;
    fileName: string;
    fileType: string;
    processedAt: string;
    processingTime: number;
    totalRows: number;
    successfulRows: number;
    failedRows: number;
    userId: string;
    userNam: string;
    status: 'completed' | 'failed' | 'cancelled';
    errors: FileValidationError[];
    warnings: FileValidationWarning[];
}

export interface FileCacheEntry {
    key: string;
    fileName: string;
    fileSize: number;
    uploadTime: string;
    expiryTime: string;
    processingResult?: FileParseResult;
    validationResult?: FileValidationResult;
    accessCount: number;
    lastAccessed: string;
}

// Types pour l'intégration

export interface FileIntegrationConfig {
    source: 'local' | 'url' | 'ftp' | 'sftp' | 'cloud';
    credentials?: Record<string, string>;
    path?: string;
    schedule?: string; // Cron expression
    autoProcess: boolean;
    notificationEmails: string[];
}

export interface WebhookConfig {
    enabled: boolean;
    url: string;
    events: string[];
    headers: Record<string, string>;
    authentication?: {
        type: 'none' | 'basic' | 'bearer' | 'api_key';
        credentials: Record<string, string>;
    };
}

// Export de tous les types groupés
export type FileValidationIssue = FileValidationError | FileValidationWarning | FileValidationInfo;

export interface FileProcessingConfig {
    parsing: FileProcessingOptions;
    validation: FileValidationRule[];
    transformation: DataTransformation[];
    integration: FileIntegrationConfig;
    webhook: WebhookConfig;
}

export interface CompleteFileInfo {
    metadata: FileMetadata;
    preview: FilePreview;
    validation: FileValidationResult;
    security: FileSecurityScan;
    compression: FileCompressionInfo;
    quarantine: FileQuarantine;
    processing: FileProcessingConfig;
    cache: FileCacheEntry;
} 