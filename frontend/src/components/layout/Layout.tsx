import {
    Assessment as AssessmentIcon,
    ChevronRight as ChevronRightIcon,
    CloudUpload as CloudUploadIcon,
    Dashboard as DashboardIcon,
    DataObject as DataObjectIcon,
    FactCheck as FactCheckIcon,
    KeyboardArrowDown as KeyboardArrowDownIcon,
    KeyboardArrowUp as KeyboardArrowUpIcon,
    Logout as LogoutIcon,
    Build as MaintenanceIcon,
    MenuBook as MenuBookIcon,
    Menu as MenuIcon,
    Person as PersonIcon,
    AccountTree as ProjectIcon,
    People as ResourceIcon,
    Settings as SettingsIcon,
    SmartToy as SmartToyIcon,
    Storage as StorageIcon,
} from '@mui/icons-material';
import {
    AppBar,
    Avatar,
    Box,
    Collapse,
    Divider,
    Drawer,
    IconButton,
    List,
    ListItem,
    ListItemButton,
    ListItemIcon,
    ListItemText,
    Menu,
    MenuItem,
    Toolbar,
    Tooltip,
    Typography,
    useMediaQuery,
    useTheme,
} from '@mui/material';
import React, { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { RootState } from '../../store';
import { logout } from '../../store/slices/authSlice';

// Drawer width
const drawerWidth = 240;

// Définition des interfaces pour les éléments du menu
interface SubMenuItem {
  text: string;
  path: string;
}

interface MenuItem {
  text: string;
  icon: JSX.Element;
  path: string;
  subItems?: SubMenuItem[];
}

// Navigation items
const menuItems: MenuItem[] = [
  { text: 'Dashboard', icon: <DashboardIcon />, path: '/' },
  { text: 'Extraction', icon: <StorageIcon />, path: '/extraction' },
  { text: 'Données SAP', icon: <DataObjectIcon />, path: '/sap-data' },
  { text: 'Données IFS', icon: <DataObjectIcon />, path: '/ifs-data' },
  { text: 'Projets', icon: <ProjectIcon />, path: '/projets' },
  { text: 'Ressources', icon: <ResourceIcon />, path: '/ressources' },
  { text: 'Maintenance', icon: <MaintenanceIcon />, path: '/maintenance' },
  { text: 'Chargement des données', icon: <CloudUploadIcon />, path: '/data-loading' },
  { text: 'Import des données', icon: <CloudUploadIcon />, path: '/data-import' },
  { text: 'Export des données', icon: <AssessmentIcon />, path: '/data-exports' },
  { text: "Contrats d'interface", icon: <FactCheckIcon />, path: '/interface-contracts' },
  { text: 'Intelligence Artificielle', icon: <SmartToyIcon />, path: '/intelligence-artificielle' },
  { text: "Mode d'emploi", icon: <MenuBookIcon />, path: '/mode-emploi' },
  { text: 'Configuration', icon: <SettingsIcon />, path: '/configuration' },
];

const Layout = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const dispatch = useDispatch();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const [mobileOpen, setMobileOpen] = useState(false);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [expandedMenus, setExpandedMenus] = useState<Record<string, boolean>>({});
  
  const user = useSelector((state: RootState) => state.auth.user);
  
  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };
  
  const handleMenuClick = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };
  
  const handleMenuClose = () => {
    setAnchorEl(null);
  };
  
  const handleLogout = async () => {
    try {
      // Fermer le menu d'abord
      handleMenuClose();
      
      // Nettoyer le localStorage complètement
      localStorage.removeItem('token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
      
      // Dispatch l'action logout et attendre qu'elle se termine
      await dispatch(logout()).unwrap();
      
      // Rediriger vers la page de login après la déconnexion
      navigate('/login');
    } catch (error) {
      console.error('Erreur lors de la déconnexion:', error);
      // Même en cas d'erreur, rediriger vers login
      navigate('/login');
    }
  };
  
  const handleNavigation = (path: string) => {
    navigate(path);
    if (isMobile) {
      setMobileOpen(false);
    }
  };
  
  const toggleExpand = (path: string) => {
    setExpandedMenus((prev) => ({
      ...prev,
      [path]: !prev[path]
    }));
  };
  
  // Drawer content
  const drawer = (
    <div>
      <Toolbar sx={{ justifyContent: 'center' }}>
        <Typography variant="h6" component="div" sx={{ fontWeight: 700 }}>
          Migration Factory
        </Typography>
      </Toolbar>
      <Divider />
      <List>
        {menuItems.map((item) => (
          <React.Fragment key={item.text}>
            <ListItem disablePadding>
              <ListItemButton
                selected={
                  location.pathname === item.path ||
                  location.pathname.startsWith(`${item.path}/`)
                }
                onClick={() => {
                  if (item.subItems?.length) {
                    toggleExpand(item.path);
                  } else {
                    handleNavigation(item.path);
                  }
                }}
              >
                <ListItemIcon sx={{ minWidth: 40 }}>{item.icon}</ListItemIcon>
                <ListItemText primary={item.text} />
                {item.subItems?.length ? (
                  expandedMenus[item.path] ? (
                    <KeyboardArrowUpIcon />
                  ) : (
                    <KeyboardArrowDownIcon />
                  )
                ) : (
                  location.pathname.startsWith(`${item.path}/`) && (
                    <ChevronRightIcon sx={{ opacity: 0.5 }} />
                  )
                )}
              </ListItemButton>
            </ListItem>
            {item.subItems?.length && (
              <Collapse in={expandedMenus[item.path]} timeout="auto" unmountOnExit>
                <List component="div" disablePadding>
                  {item.subItems.map((subItem) => (
                    <ListItem key={subItem.path} disablePadding>
                      <ListItemButton
                        selected={location.pathname === subItem.path}
                        onClick={() => handleNavigation(subItem.path)}
                        sx={{ pl: 4 }}
                      >
                        <ListItemIcon sx={{ minWidth: 40 }}>
                          <ChevronRightIcon />
                        </ListItemIcon>
                        <ListItemText primary={subItem.text} />
                      </ListItemButton>
                    </ListItem>
                  ))}
                </List>
              </Collapse>
            )}
          </React.Fragment>
        ))}
      </List>
    </div>
  );

  return (
    <Box sx={{ display: 'flex', width: '100%', maxWidth: '100vw', overflowX: 'hidden' }}>
      <AppBar
        position="fixed"
        sx={{
          backgroundColor: '#1e2738',
          width: { md: `calc(100% - ${drawerWidth}px)` },
          ml: { md: `${drawerWidth}px` },
          boxShadow: 'none',
          borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
        }}
      >
        <Toolbar>
          <IconButton
            color="inherit"
            aria-label="open drawer"
            edge="start"
            onClick={handleDrawerToggle}
            sx={{ mr: 2, display: { md: 'none' } }}
          >
            <MenuIcon />
          </IconButton>
          <Typography
            variant="h6"
            noWrap
            component="div"
            sx={{ flexGrow: 1, display: { xs: 'none', sm: 'block' } }}
          >
            {menuItems.find(
              (item) =>
                location.pathname === item.path ||
                location.pathname.startsWith(`${item.path}/`)
            )?.text || 'Migration Factory'}
          </Typography>
          <Tooltip title="Paramètres de compte">
            <Box
              onClick={handleMenuClick}
              sx={{
                display: 'flex',
                alignItems: 'center',
                cursor: 'pointer',
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '25px',
                padding: '8px 16px',
                '&:hover': {
                  backgroundColor: 'rgba(255, 255, 255, 0.15)',
                },
                transition: 'background-color 0.3s ease'
              }}
            >
              <Avatar
                sx={{
                  width: 32,
                  height: 32,
                  mr: 2
                }}
                src={`https://api.dicebear.com/7.x/avataaars/svg?seed=${user?.username || 'default'}&backgroundColor=3f51b5,2196f3,4caf50,ff9800,f44336,9c27b0`}
                alt={user?.username || 'Utilisateur'}
              >
                {user?.username?.charAt(0)?.toUpperCase() || 'U'}
              </Avatar>
              <Box sx={{ display: { xs: 'none', sm: 'block' } }}>
                <Typography variant="body2" sx={{ color: 'white', fontWeight: 'medium' }}>
                  {user?.username || 'Utilisateur'}
                </Typography>
                <Typography variant="caption" sx={{ color: 'rgba(255, 255, 255, 0.7)' }}>
                  Administrateur
                </Typography>
              </Box>
            </Box>
          </Tooltip>
          <Menu
            anchorEl={anchorEl}
            open={Boolean(anchorEl)}
            onClose={handleMenuClose}
            transformOrigin={{ horizontal: 'right', vertical: 'top' }}
            anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
          >
            <MenuItem onClick={() => {
              handleMenuClose();
              navigate('/profile');
            }}>
              <ListItemIcon>
                <PersonIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText>Mon profil</ListItemText>
            </MenuItem>
            <Divider />
            <MenuItem onClick={handleLogout}>
              <ListItemIcon>
                <LogoutIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText>Déconnexion</ListItemText>
            </MenuItem>
          </Menu>
        </Toolbar>
      </AppBar>
      <Box
        component="nav"
        sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}
      >
        {/* Mobile drawer */}
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={handleDrawerToggle}
          ModalProps={{
            keepMounted: true, // Better open performance on mobile
          }}
          sx={{
            display: { xs: 'block', md: 'none' },
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: drawerWidth,
              backgroundColor: '#1e2738',
              borderRight: '1px solid rgba(255, 255, 255, 0.08)',
            },
          }}
        >
          {drawer}
        </Drawer>
        {/* Desktop drawer */}
        <Drawer
          variant="permanent"
          sx={{
            display: { xs: 'none', md: 'block' },
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: drawerWidth,
              backgroundColor: '#1e2738',
              borderRight: '1px solid rgba(255, 255, 255, 0.08)',
            },
          }}
          open
        >
          {drawer}
        </Drawer>
      </Box>
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          // Enfant flex : sans minWidth 0 il refuse de retrecir sous la largeur
          // de son contenu, donc un tableau large pousse <main> hors viewport et
          // overflowX le coupait en silence (colonnes inatteignables).
          // Avec minWidth 0, les TableContainer defilent en interne ; 'auto' ne
          // sert plus que de filet pour les pages qui n'en ont pas.
          minWidth: 0,
          width: { xs: '100%', md: `calc(100% - ${drawerWidth}px)` },
          minHeight: '100vh',
          maxWidth: '100%',
          overflowX: 'auto',
          position: 'relative'
        }}
      >
        <Box sx={{ mt: 8 }}> {/* Espace pour l'AppBar fixe */}
          <Outlet />
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;