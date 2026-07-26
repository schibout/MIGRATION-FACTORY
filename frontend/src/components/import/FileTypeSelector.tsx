import {
    Description as FileIcon,
    ShoppingCart as OrderIcon,
    People as PeopleIcon,
    Inventory as ProductIcon
} from '@mui/icons-material';
import {
    Avatar,
    Box,
    Card,
    Chip,
    Grid,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';

interface FileTypeConfig {
    type: string;
    name: string;
    description: string;
    requiredColumns: string[];
    icon: React.ReactNode;
    color: string;
    examples: string[];
}

interface FileTypeSelectorProps {
    selectedType?: string;
    onTypeSelect: (type: string) => void;
    disabled?: boolean;
}

const FileTypeSelector: React.FC<FileTypeSelectorProps> = ({
    selectedType,
    onTypeSelect,
    disabled = false
}) => {
    const theme = useTheme();

    // Configuration des types de fichiers
    const fileTypes: FileTypeConfig[] = [
        {
            type: 'customers',
            name: 'Clients',
            description: 'Fichier contenant les informations des clients',
            requiredColumns: ['name', 'email'],
            icon: <PeopleIcon />,
            color: '#ff9800',
            examples: ['clients.csv', 'customers.xlsx', 'contacts.csv']
        },
        {
            type: 'products',
            name: 'Produits',
            description: 'Fichier contenant le catalogue des produits',
            requiredColumns: ['code', 'name', 'price'],
            icon: <ProductIcon />,
            color: '#4caf50',
            examples: ['produits.csv', 'articles.xlsx', 'inventory.csv']
        },
        {
            type: 'orders',
            name: 'Commandes',
            description: 'Fichier contenant les commandes et transactions',
            requiredColumns: ['order_number', 'customer_id', 'total'],
            icon: <OrderIcon />,
            color: '#2196f3',
            examples: ['commandes.csv', 'orders.xlsx', 'sales.csv']
        }
    ];

    return (
        <Box>
            <Typography variant="h6" sx={{ mb: 3, fontWeight: 600 }}>
                Sélectionnez le type de fichier à importer
            </Typography>

            <Grid container spacing={3}>
                {fileTypes.map((fileType) => {
                    const isSelected = selectedType === fileType.type;
                    
                    return (
                        <Grid key={fileType.type} item xs={12} md={4}>
                            <Card
                                sx={{
                                    p: 3,
                                    cursor: disabled ? 'not-allowed' : 'pointer',
                                    border: '2px solid',
                                    borderColor: isSelected 
                                        ? fileType.color 
                                        : alpha(theme.palette.grey[300], 0.5),
                                    backgroundColor: isSelected 
                                        ? alpha(fileType.color, 0.05) 
                                        : 'background.paper',
                                    transition: 'all 0.3s ease',
                                    opacity: disabled ? 0.6 : 1,
                                    position: 'relative',
                                    '&:hover': !disabled ? {
                                        borderColor: fileType.color,
                                        backgroundColor: alpha(fileType.color, 0.05),
                                        transform: 'translateY(-4px)',
                                        boxShadow: `0 8px 25px ${alpha(fileType.color, 0.2)}`
                                    } : {},
                                    '&::before': isSelected ? {
                                        content: '""',
                                        position: 'absolute',
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        height: 4,
                                        backgroundColor: fileType.color,
                                        borderRadius: '4px 4px 0 0'
                                    } : {}
                                }}
                                onClick={() => !disabled && onTypeSelect(fileType.type)}
                            >
                                {/* En-tête avec icône */}
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                                    <Avatar
                                        sx={{
                                            backgroundColor: alpha(fileType.color, 0.1),
                                            color: fileType.color,
                                            width: 48,
                                            height: 48
                                        }}
                                    >
                                        {fileType.icon}
                                    </Avatar>
                                    <Box sx={{ flex: 1 }}>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            {fileType.name}
                                        </Typography>
                                        {isSelected && (
                                            <Chip
                                                size="small"
                                                label="Sélectionné"
                                                sx={{
                                                    backgroundColor: fileType.color,
                                                    color: 'white',
                                                    fontSize: '0.7rem',
                                                    height: 20
                                                }}
                                            />
                                        )}
                                    </Box>
                                </Box>

                                {/* Description */}
                                <Typography 
                                    variant="body2" 
                                    color="text.secondary" 
                                    sx={{ mb: 3, lineHeight: 1.5 }}
                                >
                                    {fileType.description}
                                </Typography>

                                {/* Colonnes requises */}
                                <Box sx={{ mb: 3 }}>
                                    <Typography 
                                        variant="caption" 
                                        sx={{ 
                                            fontWeight: 600, 
                                            textTransform: 'uppercase',
                                            color: 'text.secondary',
                                            letterSpacing: 0.5
                                        }}
                                    >
                                        Colonnes requises
                                    </Typography>
                                    <Box sx={{ mt: 1 }}>
                                        {fileType.requiredColumns.map((column, index) => (
                                            <Chip
                                                key={index}
                                                size="small"
                                                label={column}
                                                sx={{
                                                    mr: 0.5,
                                                    mb: 0.5,
                                                    backgroundColor: alpha(fileType.color, 0.1),
                                                    color: fileType.color,
                                                    fontSize: '0.7rem',
                                                    '& .MuiChip-label': {
                                                        fontFamily: 'monospace'
                                                    }
                                                }}
                                            />
                                        ))}
                                    </Box>
                                </Box>

                                {/* Exemples de fichiers */}
                                <Box>
                                    <Typography 
                                        variant="caption" 
                                        sx={{ 
                                            fontWeight: 600, 
                                            textTransform: 'uppercase',
                                            color: 'text.secondary',
                                            letterSpacing: 0.5
                                        }}
                                    >
                                        Exemples de noms
                                    </Typography>
                                    <Box sx={{ mt: 1 }}>
                                        {fileType.examples.map((example, index) => (
                                            <Box key={index} sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                                                <FileIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                                                <Typography 
                                                    variant="caption" 
                                                    sx={{ 
                                                        color: 'text.secondary',
                                                        fontFamily: 'monospace'
                                                    }}
                                                >
                                                    {example}
                                                </Typography>
                                            </Box>
                                        ))}
                                    </Box>
                                </Box>
                            </Card>
                        </Grid>
                    );
                })}
            </Grid>

            {/* Information complémentaire */}
            {selectedType && (
                <Box sx={{ mt: 3, p: 2, backgroundColor: alpha(theme.palette.info.main, 0.1), borderRadius: 1 }}>
                    <Typography variant="body2" color="info.main">
                        <strong>Astuce :</strong> Assurez-vous que votre fichier contient bien toutes les colonnes requises. 
                        Les colonnes supplémentaires seront ignorées lors de l'import.
                    </Typography>
                </Box>
            )}
        </Box>
    );
};

export default FileTypeSelector; 