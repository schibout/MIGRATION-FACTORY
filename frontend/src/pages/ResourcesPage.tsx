import {
    Description as FileIcon,
    Link as ConnectionIcon,
    EventAvailable as AvailabilityIcon,
    AccountTree as ParentIcon,
    Build as MaintenanceIcon,
    Person as PersonIcon,
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

interface ResourceCard {
    title: string;
    description: string;
    icon: JSX.Element;
    path: string;
    color: string;
}

const ResourcesPage: React.FC = () => {
    const navigate = useNavigate();

    const resourceCards: ResourceCard[] = [
        {
            title: 'Resource Detail File',
            description: 'Consulter les détails des fichiers de ressources',
            icon: <FileIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/detail-file',
            color: '#2196f3'
        },
        {
            title: 'Resource Connection',
            description: 'Gérer les connexions entre ressources',
            icon: <ConnectionIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/connection',
            color: '#4caf50'
        },
        {
            title: 'Resource Availability',
            description: 'Consulter la disponibilité des ressources',
            icon: <AvailabilityIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/availability',
            color: '#ff9800'
        },
        {
            title: 'Resource Parent',
            description: 'Gérer la hiérarchie des ressources parentes',
            icon: <ParentIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/parent',
            color: '#9c27b0'
        },
        {
            title: 'Maint Person Resource',
            description: 'Gérer les ressources de maintenance par personne',
            icon: <MaintenanceIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/maint-person',
            color: '#f44336'
        },
        {
            title: 'IFS Person',
            description: 'Consulter les personnes dans IFS',
            icon: <PersonIcon sx={{ fontSize: 48 }} />,
            path: '/ressources/ifs-person',
            color: '#00bcd4'
        },
    ];

    return (
        <Container maxWidth="xl" sx={{ py: 4 }}>
            <Box sx={{ mb: 4 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <PersonIcon sx={{ fontSize: 40, color: '#ff9800', mr: 2 }} />
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Gestion des Ressources
                    </Typography>
                </Box>
                <Typography variant="body1" color="text.secondary">
                    Consultez et gérez les ressources, connexions, disponibilités et hiérarchies
                </Typography>
            </Box>

            <Grid container spacing={3}>
                {resourceCards.map((card) => (
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

export default ResourcesPage;

