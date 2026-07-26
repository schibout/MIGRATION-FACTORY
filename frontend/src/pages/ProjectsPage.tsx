import {
    CloudDownload as ImportIcon,
    AccountTree as ProjectIcon,
    Person as ResourceIcon,
    People as UsersIcon,
    Timeline as TimelineIcon,
    Visibility as ViewIcon,
} from '@mui/icons-material';
import {
    Box,
    Card,
    CardActionArea,
    CardContent,
    Container,
    Grid,
    Typography
} from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

interface ProjectCard {
    title: string;
    description: string;
    icon: JSX.Element;
    path: string;
    color: string;
}

const ProjectsPage: React.FC = () => {
    const navigate = useNavigate();

    const projectCards: ProjectCard[] = [
        {
            title: 'Importer Projets SharePoint',
            description: 'Importer les projets depuis SharePoint ASAP vers la base de données',
            icon: <ImportIcon sx={{ fontSize: 48 }} />,
            path: '/import/projets',
            color: '#2196f3'
        },
        {
            title: 'Visualiser les Projets',
            description: 'Consulter et rechercher les projets importés depuis SharePoint',
            icon: <ViewIcon sx={{ fontSize: 48 }} />,
            path: '/import/sharepoint-projects',
            color: '#4caf50'
        },
        {
            title: 'États d\'Avancement',
            description: 'Importer les états d\'avancement de tous les projets SharePoint',
            icon: <TimelineIcon sx={{ fontSize: 48 }} />,
            path: '/import/etats-avancement',
            color: '#00bcd4'
        },
        {
            title: 'Importer Ressources SharePoint',
            description: 'Importer les ressources depuis SharePoint ASAP vers la base de données',
            icon: <ResourceIcon sx={{ fontSize: 48 }} />,
            path: '/import/ressources',
            color: '#ff9800'
        },
        {
            title: 'Importer Utilisateurs ASAP',
            description: 'Importer les utilisateurs depuis SharePoint ASAP vers la base de données',
            icon: <UsersIcon sx={{ fontSize: 48 }} />,
            path: '/import/users',
            color: '#f44336'
        },
        {
            title: 'Visualiser les Utilisateurs',
            description: 'Consulter et rechercher les utilisateurs importés depuis SharePoint',
            icon: <ViewIcon sx={{ fontSize: 48 }} />,
            path: '/import/sharepoint-users',
            color: '#00bcd4'
        },
        {
            title: 'Projet Modèle IFS',
            description: 'Structure de référence MOD_PRJ_TN (sous-projets, portes, activity classes)',
            icon: <ProjectIcon sx={{ fontSize: 48 }} />,
            path: '/projets/modele',
            color: '#1565c0'
        },
        {
            title: 'Projets à reprendre',
            description: 'Liste de référence des projets à reprendre (export SharePoint) avec détail jalons, CFV et budgets',
            icon: <ViewIcon sx={{ fontSize: 48 }} />,
            path: '/projets/a-reprendre',
            color: '#0f766e'
        },
    ];

    return (
        <Container maxWidth="xl" sx={{ py: 4 }}>
            <Box sx={{ mb: 4 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <ProjectIcon sx={{ fontSize: 40, color: '#ff9800', mr: 2 }} />
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Gestion des Projets
                    </Typography>
                </Box>
                <Typography variant="body1" color="text.secondary">
                    Importez et consultez les projets, ressources et utilisateurs depuis SharePoint ASAP
                </Typography>
            </Box>

            <Grid container spacing={3}>
                {projectCards.map((card) => (
                    <Grid item xs={12} sm={6} md={4} key={card.title}>
                        <Card
                            sx={{
                                height: '100%',
                                transition: 'all 0.3s ease',
                                '&:hover': {
                                    transform: 'translateY(-8px)',
                                    boxShadow: 6,
                                },
                            }}
                        >
                            <CardActionArea
                                onClick={() => navigate(card.path)}
                                sx={{ height: '100%', p: 2 }}
                            >
                                <CardContent>
                                    <Box
                                        sx={{
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            mb: 2,
                                            color: card.color,
                                        }}
                                    >
                                        {card.icon}
                                    </Box>
                                    <Typography
                                        variant="h6"
                                        component="h2"
                                        gutterBottom
                                        align="center"
                                        sx={{ fontWeight: 600 }}
                                    >
                                        {card.title}
                                    </Typography>
                                    <Typography
                                        variant="body2"
                                        color="text.secondary"
                                        align="center"
                                    >
                                        {card.description}
                                    </Typography>
                                </CardContent>
                            </CardActionArea>
                        </Card>
                    </Grid>
                ))}
            </Grid>
        </Container>
    );
};

export default ProjectsPage;


