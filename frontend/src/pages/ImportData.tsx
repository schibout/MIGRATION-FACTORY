import {
    alpha,
    Box,
    Card,
    Grid,
    Typography,
    useMediaQuery,
    useTheme
} from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

// Import des icônes
import {
    Inventory as ArticleIcon,
    People as ClientIcon,
    History as HistoryIcon,
    Engineering as ProjetIcon,
    Storage as StorageIcon,
    TableChart as TableIcon,
    Timeline as TimelineIcon,
    Upload as UploadIcon
} from '@mui/icons-material';

// Type pour les éléments du menu d'import
interface ImportMenuItem {
    title: string;
    path: string;
    icon: React.ReactNode;
    description: string;
    count?: number;
}

const ImportDataPage: React.FC = () => {
    const theme = useTheme();
    const navigate = useNavigate();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isMedium = useMediaQuery(theme.breakpoints.down('md'));

    // Liste des éléments du menu d'import
    const importItems: ImportMenuItem[] = [
        {
            title: 'Import Générique',
            path: '/import/generic',
            icon: <TableIcon sx={{ fontSize: 40, color: '#e91e63' }} />,
            description: 'Import guidé vers n\'importe quelle table avec mapping automatique'
        },
        {
            title: 'Explorateur de Données',
            path: '/data-browser',
            icon: <StorageIcon sx={{ fontSize: 40, color: '#673ab7' }} />,
            description: 'Consulter les données de n\'importe quelle table'
        },
        {
            title: 'Import Clients',
            path: '/import/clients',
            icon: <ClientIcon sx={{ fontSize: 40, color: '#ff9800' }} />,
            description: 'Importer les données clients vers IFS Customer Info'
        },
        {
            title: 'Import Articles',
            path: '/import/articles',
            icon: <ArticleIcon sx={{ fontSize: 40, color: '#4caf50' }} />,
            description: 'Importer le catalogue d\'articles vers IFS Part Catalog'
        },
        {
            title: 'Import Projets',
            path: '/import/projets',
            icon: <ProjetIcon sx={{ fontSize: 40, color: '#2196f3' }} />,
            description: 'Importer les données de projets et structures'
        },
        {
            title: 'États d\'Avancement',
            path: '/import/etats-avancement',
            icon: <TimelineIcon sx={{ fontSize: 40, color: '#00bcd4' }} />,
            description: 'Importer les états d\'avancement des projets SharePoint'
        },
        {
            title: 'Historique',
            path: '/import/history',
            icon: <HistoryIcon sx={{ fontSize: 40, color: '#9c27b0' }} />,
            description: 'Consulter l\'historique des imports et leurs résultats'
        }
    ];

    // Déterminer le nombre de colonnes en fonction de la taille de l'écran
    const getGridCols = () => {
        if (isMobile) return 12; // 1 carte par ligne sur mobile
        if (isMedium) return 6;  // 2 cartes par ligne sur tablette
        return 4;                // 3 cartes par ligne sur desktop
    };

    return (
        <Box sx={{ width: '100%', p: 3 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
                <UploadIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
                <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                    IMPORT DES DONNÉES
                </Typography>
            </Box>

            <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                Importez vos données depuis des fichiers CSV ou Excel vers le système IFS.
            </Typography>

            <Grid container spacing={3}>
                {importItems.map((item) => (
                    <Grid item xs={getGridCols()} key={item.path}>
                        <Card 
                            sx={{ 
                                height: '100%', 
                                cursor: 'pointer',
                                transition: 'all 0.3s ease',
                                position: 'relative',
                                overflow: 'hidden',
                                '&:hover': {
                                    transform: 'translateY(-8px)',
                                    boxShadow: '0 12px 32px rgba(0,0,0,0.15)',
                                    '& .import-overlay': {
                                        opacity: 1
                                    }
                                }
                            }}
                            onClick={() => navigate(item.path)}
                        >
                            {/* Overlay pour l'effet hover */}
                            <Box 
                                className="import-overlay"
                                sx={{
                                    position: 'absolute',
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.1)}, ${alpha(theme.palette.secondary.main, 0.1)})`,
                                    opacity: 0,
                                    transition: 'opacity 0.3s ease',
                                    zIndex: 1
                                }}
                            />

                            <Box sx={{ 
                                display: 'flex', 
                                flexDirection: 'column',
                                alignItems: 'center',
                                textAlign: 'center',
                                p: 4,
                                position: 'relative',
                                zIndex: 2
                            }}>
                                <Box 
                                    sx={{ 
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        width: 90,
                                        height: 90,
                                        borderRadius: '50%',
                                        backgroundColor: alpha(theme.palette.background.paper, 0.9),
                                        mb: 3,
                                        boxShadow: '0 4px 16px rgba(0,0,0,0.1)',
                                        border: `2px solid ${alpha(theme.palette.divider, 0.1)}`
                                    }}
                                >
                                    {item.icon}
                                </Box>

                                <Typography 
                                    variant="h6" 
                                    component="h2" 
                                    sx={{ 
                                        mb: 2,
                                        fontWeight: 600,
                                        color: theme.palette.text.primary
                                    }}
                                >
                                    {item.title}
                                </Typography>

                                <Typography 
                                    variant="body2" 
                                    color="text.secondary"
                                    sx={{
                                        fontSize: '0.875rem',
                                        lineHeight: 1.5,
                                        maxWidth: '280px'
                                    }}
                                >
                                    {item.description}
                                </Typography>

                                {/* Badge d'action */}
                                <Box
                                    sx={{
                                        mt: 2,
                                        px: 2,
                                        py: 0.5,
                                        borderRadius: '16px',
                                        backgroundColor: alpha(theme.palette.primary.main, 0.1),
                                        border: `1px solid ${alpha(theme.palette.primary.main, 0.2)}`
                                    }}
                                >
                                    <Typography
                                        variant="caption"
                                        sx={{
                                            color: theme.palette.primary.main,
                                            fontWeight: 500,
                                            fontSize: '0.75rem'
                                        }}
                                    >
                                        Cliquez pour importer
                                    </Typography>
                                </Box>
                            </Box>
                        </Card>
                    </Grid>
                ))}
            </Grid>

            {/* Section d'information supplémentaire */}
            <Box sx={{ mt: 6, p: 3, backgroundColor: alpha(theme.palette.info.main, 0.05), borderRadius: 2 }}>
                <Typography variant="h6" sx={{ mb: 2, color: theme.palette.info.main }}>
                    Informations sur l'import
                </Typography>
                <Grid container spacing={2}>
                    <Grid item xs={12} sm={6}>
                        <Typography variant="body2" color="text.secondary">
                            • Formats supportés : CSV, Excel (XLSX, XLS)
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            • Validation automatique des données
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            • Gestion des erreurs ligne par ligne
                        </Typography>
                    </Grid>
                    <Grid item xs={12} sm={6}>
                        <Typography variant="body2" color="text.secondary">
                            • Taille maximale : 50 MB par fichier
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            • Suivi en temps réel du traitement
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            • Rapport détaillé des résultats
                        </Typography>
                    </Grid>
                </Grid>
            </Box>
        </Box>
    );
};

export default ImportDataPage; 