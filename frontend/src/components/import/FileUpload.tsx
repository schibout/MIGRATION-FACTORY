import {
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    InsertDriveFile as FileIcon,
    CloudUpload as UploadIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    Chip,
    CircularProgress,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useCallback, useRef, useState } from 'react';

interface FileUploadProps {
    fileType: string;
    onFileSelect: (file: File) => void;
    onUpload: (file: File, fileType: string) => void;
    uploading?: boolean;
    uploadProgress?: number;
    maxFileSize?: number; // en bytes
    allowedFormats?: string[];
    disabled?: boolean;
}

const FileUpload: React.FC<FileUploadProps> = ({
    fileType,
    onFileSelect,
    onUpload,
    uploading = false,
    uploadProgress = 0,
    maxFileSize = 50 * 1024 * 1024, // 50MB par défaut
    allowedFormats = ['csv', 'xlsx', 'xls'],
    disabled = false
}) => {
    const theme = useTheme();
    const fileInputRef = useRef<HTMLInputElement>(null);
    const [dragOver, setDragOver] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [errors, setErrors] = useState<string[]>([]);

    // Configuration des couleurs selon le type de fichier
    const getFileTypeColor = () => {
        switch (fileType) {
            case 'customers': return '#ff9800';
            case 'products': return '#4caf50';
            case 'orders': return '#2196f3';
            default: return theme.palette.primary.main;
        }
    };

    const color = getFileTypeColor();

    // Validation d'un fichier
    const validateFile = useCallback((file: File): string[] => {
        const errors: string[] = [];

        // Vérifier la taille
        if (file.size > maxFileSize) {
            errors.push(`Fichier trop volumineux (max ${formatFileSize(maxFileSize)})`);
        }

        // Vérifier le format
        const extension = file.name.split('.').pop()?.toLowerCase();
        if (!extension || !allowedFormats.includes(extension)) {
            errors.push(`Format non supporté. Formats autorisés: ${allowedFormats.join(', ')}`);
        }

        return errors;
    }, [maxFileSize, allowedFormats]);

    // Formater la taille de fichier
    const formatFileSize = (bytes: number): string => {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
    };

    // Gestion de la sélection de fichier
    const handleFileSelect = useCallback((file: File) => {
        const validationErrors = validateFile(file);
        setErrors(validationErrors);

        if (validationErrors.length === 0) {
            setSelectedFile(file);
            onFileSelect(file);
        } else {
            setSelectedFile(null);
        }
    }, [validateFile, onFileSelect]);

    // Gestion du drag & drop
    const handleDragOver = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        if (!disabled && !uploading) {
            setDragOver(true);
        }
    }, [disabled, uploading]);

    const handleDragLeave = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setDragOver(false);
    }, []);

    const handleDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        setDragOver(false);

        if (disabled || uploading) return;

        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleFileSelect(files[0]);
        }
    }, [disabled, uploading, handleFileSelect]);

    // Gestion du clic sur la zone
    const handleZoneClick = useCallback(() => {
        if (!disabled && !uploading && fileInputRef.current) {
            fileInputRef.current.click();
        }
    }, [disabled, uploading]);

    // Gestion de la sélection via input
    const handleInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (files && files.length > 0) {
            handleFileSelect(files[0]);
        }
    }, [handleFileSelect]);

    // Lancer l'upload
    const handleUpload = useCallback(() => {
        if (selectedFile && !uploading) {
            onUpload(selectedFile, fileType);
        }
    }, [selectedFile, uploading, onUpload, fileType]);

    return (
        <Box>
            {/* Zone de drop */}
            <Card
                sx={{
                    p: 4,
                    border: '2px dashed',
                    borderColor: dragOver 
                        ? color 
                        : errors.length > 0 
                            ? theme.palette.error.main 
                            : alpha(color, 0.3),
                    backgroundColor: dragOver 
                        ? alpha(color, 0.1) 
                        : errors.length > 0 
                            ? alpha(theme.palette.error.main, 0.05)
                            : alpha(color, 0.05),
                    textAlign: 'center',
                    cursor: disabled || uploading ? 'not-allowed' : 'pointer',
                    transition: 'all 0.3s ease',
                    position: 'relative',
                    '&:hover': !disabled && !uploading ? {
                        borderColor: color,
                        backgroundColor: alpha(color, 0.1),
                        transform: 'translateY(-2px)',
                        boxShadow: `0 8px 25px ${alpha(color, 0.2)}`
                    } : {},
                    opacity: disabled ? 0.6 : 1
                }}
                onClick={handleZoneClick}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
            >
                {/* Input caché */}
                <input
                    ref={fileInputRef}
                    type="file"
                    style={{ display: 'none' }}
                    accept={allowedFormats.map(format => `.${format}`).join(',')}
                    onChange={handleInputChange}
                    disabled={disabled || uploading}
                />

                {/* Contenu de la zone */}
                <Box sx={{ mb: 2 }}>
                    {uploading ? (
                        <CircularProgress size={60} sx={{ color }} />
                    ) : selectedFile && errors.length === 0 ? (
                        <CheckIcon sx={{ fontSize: 60, color: theme.palette.success.main }} />
                    ) : errors.length > 0 ? (
                        <ErrorIcon sx={{ fontSize: 60, color: theme.palette.error.main }} />
                    ) : (
                        <UploadIcon sx={{ fontSize: 60, color }} />
                    )}
                </Box>

                <Typography variant="h6" sx={{ mb: 1, fontWeight: 600 }}>
                    {uploading 
                        ? 'Upload en cours...'
                        : selectedFile && errors.length === 0 
                            ? 'Fichier sélectionné'
                            : errors.length > 0
                                ? 'Erreur de validation'
                                : 'Glissez votre fichier ici ou cliquez pour sélectionner'
                    }
                </Typography>

                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {uploading 
                        ? `${uploadProgress}% terminé`
                        : `Formats supportés : ${allowedFormats.join(', ').toUpperCase()} (max ${formatFileSize(maxFileSize)})`
                    }
                </Typography>

                {/* Information fichier sélectionné */}
                {selectedFile && errors.length === 0 && (
                    <Box sx={{ mb: 2 }}>
                        <Chip
                            icon={<FileIcon />}
                            label={`${selectedFile.name} (${formatFileSize(selectedFile.size)})`}
                            sx={{
                                backgroundColor: alpha(color, 0.1),
                                color,
                                border: `1px solid ${alpha(color, 0.3)}`
                            }}
                        />
                    </Box>
                )}

                {/* Bouton d'upload */}
                {selectedFile && errors.length === 0 && !uploading && (
                    <Button
                        variant="contained"
                        sx={{
                            backgroundColor: color,
                            color: 'white',
                            fontWeight: 600,
                            '&:hover': {
                                backgroundColor: alpha(color, 0.8)
                            }
                        }}
                        onClick={(e) => {
                            e.stopPropagation();
                            handleUpload();
                        }}
                    >
                        Démarrer l'import
                    </Button>
                )}
            </Card>

            {/* Erreurs de validation */}
            {errors.length > 0 && (
                <Box sx={{ mt: 2 }}>
                    {errors.map((error, index) => (
                        <Alert 
                            key={index} 
                            severity="error" 
                            sx={{ mb: 1 }}
                        >
                            {error}
                        </Alert>
                    ))}
                </Box>
            )}

            {/* Barre de progression */}
            {uploading && uploadProgress > 0 && (
                <Box sx={{ mt: 2 }}>
                    <Box
                        sx={{
                            width: '100%',
                            height: 8,
                            backgroundColor: alpha(color, 0.2),
                            borderRadius: 4,
                            overflow: 'hidden'
                        }}
                    >
                        <Box
                            sx={{
                                width: `${uploadProgress}%`,
                                height: '100%',
                                backgroundColor: color,
                                transition: 'width 0.3s ease',
                                borderRadius: 4
                            }}
                        />
                    </Box>
                    <Typography 
                        variant="caption" 
                        sx={{ mt: 1, display: 'block', textAlign: 'center' }}
                    >
                        {uploadProgress}% - {selectedFile?.name}
                    </Typography>
                </Box>
            )}
        </Box>
    );
};

export default FileUpload; 