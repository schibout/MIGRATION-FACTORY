// Types pour le système d'import

export interface ImportJob {
    job_uuid: string;
    file_name: string;
    file_type: string;
    status: ImportStatus;
    total_rows?: number;
    processed_rows?: number;
    success_rows?: number;
    error_rows?: number;
    progress_percent?: number;
    created_at: string;
    started_at?: string;
    completed_at?: string;
    error_message?: string;
    user_id?: number;
    user_name?: string;
}

export type ImportStatus = 
    | 'pending' 
    | 'processing' 
    | 'completed' 
    | 'completed_with_errors' 
    | 'failed' 
    | 'cancelled';

export interface ImportDetail {
    id: number;
    job_uuid: string;
    row_number: number;
    status: 'success' | 'error';
    error_message?: string;
    row_data: Record<string, any>;
    processed_at: string;
}

export interface ImportStats {
    total_imports: number;
    successful_imports: number;
    failed_imports: number;
    pending_imports: number;
    total_rows_processed: number;
    success_rate: number;
    avg_processing_time: number;
    imports_today: number;
    imports_this_week: number;
    imports_this_month: number;
}

export interface TopError {
    error_message: string;
    count: number;
    percentage: number;
}

export interface FileTypeStats {
    file_type: string;
    count: number;
    success_rate: number;
    avg_rows: number;
}

export interface FileTypeConfig {
    type: string;
    name: string;
    description: string;
    required_columns: string[];
    optional_columns?: string[];
    validation_rules?: Record<string, any>;
    target_table: string;
    max_file_size?: number;
    allowed_formats: string[];
}

export interface ImportLog {
    id: number;
    job_uuid: string;
    level: 'info' | 'warning' | 'error';
    message: string;
    details?: Record<string, any>;
    created_at: string;
}

export interface UploadResponse {
    success: boolean;
    job_uuid?: string;
    message: string;
    errors?: string[];
}

export interface ImportJobsResponse {
    success: boolean;
    data: ImportJob[];
    total: number;
    page: number;
    per_page: number;
    message?: string;
}

export interface ImportStatsResponse {
    success: boolean;
    data: ImportStats;
    message?: string;
}

export interface ImportDetailsResponse {
    success: boolean;
    data: ImportDetail[];
    total: number;
    page: number;
    per_page: number;
    message?: string;
}

export interface FileTypeConfigsResponse {
    success: boolean;
    data: FileTypeConfig[];
    message?: string;
}

// Types pour les filtres
export interface ImportFilters {
    status?: ImportStatus | ImportStatus[];
    file_type?: string | string[];
    date_from?: string;
    date_to?: string;
    user_id?: number;
    search?: string;
}

// Types pour la pagination
export interface PaginationParams {
    page?: number;
    per_page?: number;
    sort_by?: string;
    sort_order?: 'asc' | 'desc';
}

// Types pour les hooks
export interface UseImportOptions {
    autoRefresh?: boolean;
    refreshInterval?: number;
}

export interface UseImportResult {
    jobs: ImportJob[];
    stats: ImportStats | null;
    loading: boolean;
    error: string | null;
    refreshJobs: () => Promise<void>;
    refreshStats: () => Promise<void>;
    uploadFile: (file: File, fileType: string) => Promise<UploadResponse>;
    cancelJob: (jobUuid: string) => Promise<void>;
    retryJob: (jobUuid: string) => Promise<void>;
}

// Types pour les composants
export interface FileUploadProps {
    fileType: string;
    onFileSelect: (file: File) => void;
    onUpload: (file: File, fileType: string) => void;
    uploading?: boolean;
    uploadProgress?: number;
    maxFileSize?: number;
    allowedFormats?: string[];
    disabled?: boolean;
}

export interface ImportProgressProps {
    job: ImportJob;
    onCancel?: (jobUuid: string) => void;
    onRetry?: (jobUuid: string) => void;
    onViewDetails?: (jobUuid: string) => void;
    showActions?: boolean;
}

export interface FileTypeSelectorProps {
    selectedType?: string;
    onTypeSelect: (type: string) => void;
    disabled?: boolean;
}

export interface ImportDashboardProps {
    stats?: ImportStats;
    topErrors?: TopError[];
    fileTypeStats?: FileTypeStats[];
    onRefresh?: () => void;
    onViewAllImports?: () => void;
    loading?: boolean;
}

export interface ImportHistoryProps {
    jobs?: ImportJob[];
    loading?: boolean;
    onRefresh?: () => void;
    onViewDetails?: (jobUuid: string) => void;
    onCancel?: (jobUuid: string) => void;
    onRetry?: (jobUuid: string) => void;
    filters?: ImportFilters;
    onFiltersChange?: (filters: ImportFilters) => void;
    pagination?: PaginationParams;
    onPaginationChange?: (pagination: PaginationParams) => void;
}

export interface ImportDetailsProps {
    job: ImportJob;
    details?: ImportDetail[];
    logs?: ImportLog[];
    loading?: boolean;
    onRefresh?: () => void;
    onExportErrors?: () => void;
    onCancel?: () => void;
    onRetry?: () => void;
    pagination?: PaginationParams;
    onPaginationChange?: (pagination: PaginationParams) => void;
} 