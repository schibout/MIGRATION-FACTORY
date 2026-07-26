import { CloudUpload as UploadIcon } from '@mui/icons-material';
import {
    Box,
    Card,
    CircularProgress,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useCallback, useState } from 'react';

interface StepUploadProps {
    loading: boolean;
    onFileSelect: (file: File) => Promise<void>;
}

const StepUpload: React.FC<StepUploadProps> = ({ loading, onFileSelect }) => {
    const theme = useTheme();
    const [dragOver, setDragOver] = useState(false);

    const formatFileSize = (bytes: number): string => {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
    };

    const handleDragOver = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        if (!loading) {
            setDragOver(true);
        }
    }, [loading]);

    const handleDragLeave = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setDragOver(false);
    }, []);

    const handleDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setDragOver(false);
        if (loading) return;

        const files = e.dataTransfer.files;
        if (files.length > 0) {
            onFileSelect(files[0]);
        }
    }, [loading, onFileSelect]);

    const handleClick = useCallback(() => {
        if (!loading) {
            document.getElementById('file-input')?.click();
        }
    }, [loading]);

    const handleFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (files && files.length > 0) {
            onFileSelect(files[0]);
        }
    }, [onFileSelect]);

    return (
        <Box>
            <Card
                sx={{
                    p: 6,
                    border: '2px dashed',
                    borderColor: dragOver 
                        ? theme.palette.primary.main 
                        : alpha(theme.palette.primary.main, 0.3),
                    backgroundColor: dragOver 
                        ? alpha(theme.palette.primary.main, 0.1) 
                        : alpha(theme.palette.primary.main, 0.02),
                    textAlign: 'center',
                    cursor: loading ? 'wait' : 'pointer',
                    transition: 'all 0.3s ease',
                    '&:hover': !loading ? {
                        borderColor: theme.palette.primary.main,
                        backgroundColor: alpha(theme.palette.primary.main, 0.05),
                        transform: 'translateY(-2px)',
                        boxShadow: `0 8px 25px ${alpha(theme.palette.primary.main, 0.2)}`
                    } : {}
                }}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
                onClick={handleClick}
            >
                <input
                    id="file-input"
                    type="file"
                    style={{ display: 'none' }}
                    accept=".csv,.xlsx,.xls"
                    onChange={handleFileChange}
                    disabled={loading}
                />

                {loading ? (
                    <CircularProgress size={80} sx={{ mb: 2 }} />
                ) : (
                    <UploadIcon 
                        sx={{ 
                            fontSize: 80, 
                            color: theme.palette.primary.main, 
                            mb: 2 
                        }} 
                    />
                )}

                <Typography variant="h5" sx={{ mb: 1, fontWeight: 600 }}>
                    {loading ? 'Analyse du fichier en cours...' : 'Glissez votre fichier ici'}
                </Typography>
                
                <Typography variant="body1" color="text.secondary" sx={{ mb: 2 }}>
                    ou cliquez pour sélectionner
                </Typography>
                
                <Typography variant="body2" color="text.secondary">
                    Formats supportés : CSV, Excel (XLSX, XLS) • Max 50 MB
                </Typography>

                {/* Feature highlights */}
                <Box 
                    sx={{ 
                        mt: 4, 
                        pt: 3, 
                        borderTop: `1px solid ${alpha(theme.palette.divider, 0.5)}`,
                        display: 'flex',
                        justifyContent: 'center',
                        gap: 4,
                        flexWrap: 'wrap'
                    }}
                >
                    <Box sx={{ textAlign: 'center' }}>
                        <Typography variant="subtitle2" color="primary.main">
                            Détection automatique
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            Types de colonnes
                        </Typography>
                    </Box>
                    <Box sx={{ textAlign: 'center' }}>
                        <Typography variant="subtitle2" color="primary.main">
                            Mapping intelligent
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            Association automatique
                        </Typography>
                    </Box>
                    <Box sx={{ textAlign: 'center' }}>
                        <Typography variant="subtitle2" color="primary.main">
                            Validation
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            Avant import
                        </Typography>
                    </Box>
                </Box>
            </Card>
        </Box>
    );
};

export default StepUpload;
