import { useCallback, useRef, useState } from 'react';
import { importService } from '../services/importService';
import { UploadResponse } from '../types/import.types';

export interface FileValidationOptions {
    maxSize?: number; // en bytes
    allowedTypes?: string[];
    requiredColumns?: string[];
}

export interface UseFileUploadOptions {
    onSuccess?: (response: UploadResponse) => void;
    onError?: (error: string) => void;
    onProgress?: (progress: number) => void;
    autoValidate?: boolean;
    validationOptions?: FileValidationOptions;
}

export interface FileUploadState {
    file: File | null;
    uploading: boolean;
    progress: number;
    error: string | null;
    success: boolean;
    response: UploadResponse | null;
    validationErrors: string[];
    preview: any[] | null;
}

export interface UseFileUploadResult {
    state: FileUploadState;
    
    // Actions principales
    selectFile: (file: File) => Promise<void>;
    uploadFile: (fileType: string) => Promise<UploadResponse | null>;
    validateFile: (file: File, fileType: string) => Promise<boolean>;
    resetUpload: () => void;
    cancelUpload: () => void;
    
    // Utilitaires
    formatFileSize: (bytes: number) => string;
    getFileExtension: (filename: string) => string;
    isValidFileType: (file: File) => boolean;
    
    // État calculé
    canUpload: boolean;
    uploadPercentage: string;
}

export const useFileUpload = (options: UseFileUploadOptions = {}): UseFileUploadResult => {
    const {
        onSuccess,
        onError,
        onProgress,
        autoValidate = true,
        validationOptions = {
            maxSize: 50 * 1024 * 1024, // 50MB
            allowedTypes: ['csv', 'xlsx', 'xls'],
            requiredColumns: []
        }
    } = options;

    // État
    const [state, setState] = useState<FileUploadState>({
        file: null,
        uploading: false,
        progress: 0,
        error: null,
        success: false,
        response: null,
        validationErrors: [],
        preview: null
    });

    // Référence pour annuler l'upload (si supporté)
    const uploadControllerRef = useRef<AbortController | null>(null);

    // Formatage de la taille de fichier
    const formatFileSize = useCallback((bytes: number): string => {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
    }, []);

    // Extraction de l'extension
    const getFileExtension = useCallback((filename: string): string => {
        return filename.split('.').pop()?.toLowerCase() || '';
    }, []);

    // Validation du type de fichier
    const isValidFileType = useCallback((file: File): boolean => {
        const extension = getFileExtension(file.name);
        return validationOptions.allowedTypes?.includes(extension) || false;
    }, [getFileExtension, validationOptions.allowedTypes]);

    // Validation côté client d'un fichier
    const validateFileClient = useCallback((file: File): string[] => {
        const errors: string[] = [];

        // Vérifier la taille
        if (validationOptions.maxSize && file.size > validationOptions.maxSize) {
            errors.push(`Fichier trop volumineux (max ${formatFileSize(validationOptions.maxSize)})`);
        }

        // Vérifier le type
        if (!isValidFileType(file)) {
            errors.push(`Format non supporté. Formats autorisés: ${validationOptions.allowedTypes?.join(', ')}`);
        }

        // Vérifier que le fichier n'est pas vide
        if (file.size === 0) {
            errors.push('Le fichier est vide');
        }

        return errors;
    }, [validationOptions, formatFileSize, isValidFileType]);

    // Validation côté serveur d'un fichier
    const validateFile = useCallback(async (file: File, fileType: string): Promise<boolean> => {
        setState(prev => ({ ...prev, error: null, validationErrors: [] }));

        try {
            // Validation côté client d'abord
            const clientErrors = validateFileClient(file);
            if (clientErrors.length > 0) {
                setState(prev => ({ ...prev, validationErrors: clientErrors }));
                return false;
            }

            // Validation côté serveur
            const response = await importService.validateFile(file, fileType);
            
            if (response.success) {
                setState(prev => ({ 
                    ...prev, 
                    preview: response.preview || null,
                    validationErrors: response.warnings || []
                }));
                return true;
            } else {
                setState(prev => ({ 
                    ...prev, 
                    validationErrors: response.errors || [],
                    error: response.message
                }));
                return false;
            }
        } catch (err) {
            const errorMessage = 'Erreur lors de la validation du fichier';
            setState(prev => ({ 
                ...prev, 
                error: errorMessage,
                validationErrors: [errorMessage]
            }));
            return false;
        }
    }, [validateFileClient]);

    // Sélection d'un fichier
    const selectFile = useCallback(async (file: File) => {
        setState(prev => ({ 
            ...prev, 
            file, 
            error: null, 
            success: false, 
            response: null,
            validationErrors: [],
            preview: null
        }));

        if (autoValidate) {
            // Validation côté client seulement pour la sélection
            const errors = validateFileClient(file);
            setState(prev => ({ ...prev, validationErrors: errors }));
        }
    }, [autoValidate, validateFileClient]);

    // Upload du fichier
    const uploadFile = useCallback(async (fileType: string): Promise<UploadResponse | null> => {
        if (!state.file) {
            const error = 'Aucun fichier sélectionné';
            setState(prev => ({ ...prev, error }));
            onError?.(error);
            return null;
        }

        setState(prev => ({ 
            ...prev, 
            uploading: true, 
            progress: 0, 
            error: null, 
            success: false 
        }));

        try {
            // Validation finale avant upload
            const isValid = await validateFile(state.file, fileType);
            if (!isValid) {
                setState(prev => ({ ...prev, uploading: false }));
                return null;
            }

            // Créer un contrôleur d'annulation
            uploadControllerRef.current = new AbortController();

            // Simuler la progression (à remplacer par vraie progression si disponible)
            const progressInterval = setInterval(() => {
                setState(prev => {
                    const newProgress = Math.min(prev.progress + 10, 90);
                    onProgress?.(newProgress);
                    return { ...prev, progress: newProgress };
                });
            }, 200);

            // Upload du fichier
            const response = await importService.uploadFile(state.file, fileType);

            // Nettoyer l'intervalle de progression
            clearInterval(progressInterval);

            if (response.success) {
                setState(prev => ({ 
                    ...prev, 
                    uploading: false, 
                    progress: 100, 
                    success: true, 
                    response 
                }));
                onSuccess?.(response);
            } else {
                setState(prev => ({ 
                    ...prev, 
                    uploading: false, 
                    error: response.message || 'Erreur lors de l\'upload' 
                }));
                onError?.(response.message || 'Erreur lors de l\'upload');
            }

            return response;

        } catch (err: any) {
            const errorMessage = err.name === 'AbortError' 
                ? 'Upload annulé' 
                : 'Erreur réseau lors de l\'upload';
            
            setState(prev => ({ 
                ...prev, 
                uploading: false, 
                error: errorMessage 
            }));
            onError?.(errorMessage);
            return null;
        } finally {
            uploadControllerRef.current = null;
        }
    }, [state.file, validateFile, onSuccess, onError, onProgress]);

    // Annulation de l'upload
    const cancelUpload = useCallback(() => {
        if (uploadControllerRef.current) {
            uploadControllerRef.current.abort();
        }
        setState(prev => ({ 
            ...prev, 
            uploading: false, 
            progress: 0, 
            error: 'Upload annulé' 
        }));
    }, []);

    // Reset de l'état
    const resetUpload = useCallback(() => {
        if (uploadControllerRef.current) {
            uploadControllerRef.current.abort();
        }
        setState({
            file: null,
            uploading: false,
            progress: 0,
            error: null,
            success: false,
            response: null,
            validationErrors: [],
            preview: null
        });
    }, []);

    // État calculé
    const canUpload = state.file !== null && 
                     !state.uploading && 
                     state.validationErrors.length === 0;

    const uploadPercentage = `${Math.round(state.progress)}%`;

    return {
        state,
        selectFile,
        uploadFile,
        validateFile,
        resetUpload,
        cancelUpload,
        formatFileSize,
        getFileExtension,
        isValidFileType,
        canUpload,
        uploadPercentage
    };
}; 