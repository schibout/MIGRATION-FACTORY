import { Box, CircularProgress } from '@mui/material';
import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import Layout from './components/layout/Layout';
import ExportQueriesManagement from './pages/admin/ExportQueriesManagement';
import { ImportTypesConfiguration } from './pages/admin/ImportTypesConfiguration';
import AssistantIA from './pages/AssistantIA';
import Configuration from './pages/Configuration';
import HermesChat from './pages/HermesChat';
import ConfigurationIA from './pages/ConfigurationIA';
import Dashboard from './pages/Dashboard';
import DataBrowserPage from './pages/DataBrowser';
import DataLoadingPage from './pages/dataLoading/DataLoadingPage';
import DefaultValuesManagement from './pages/DefaultValuesManagement';
import MatriceSiteFamille from './pages/MatriceSiteFamille';
import EquipmentPage from './pages/EquipmentPage';
import ExportArticles from './pages/ExportArticles.tsx';
import ExportClients from './pages/ExportClients';
import ExportData from './pages/ExportData';
import ExportFournisseurs from './pages/ExportFournisseurs';
import ExportMaintenance from './pages/ExportMaintenance';
import ExportOperation from './pages/ExportOperation';
import ExportPmAction from './pages/ExportPmAction';
import ExportProjects from './pages/ExportProjects';
import ExportStructureMaintenance from './pages/ExportStructureMaintenance';
import Extraction from './pages/Extraction';
import ExtractionHub from './pages/ExtractionHub';
import MetadataExtraction from './pages/MetadataExtraction';
import FieldMappingManagement from './pages/FieldMappingManagement';
import IfsCatalog from './pages/IfsCatalog';
import IfsData from './pages/IfsData';
import IfsDataArticles from './pages/IfsDataArticles';
import IfsDataClients from './pages/IfsDataClients';
import IfsDataFournisseurs from './pages/IfsDataFournisseurs';
import IH02HierarchyPage from './pages/IH02HierarchyPage';
import ImportArticlesPage from './pages/ImportArticles';
import InterfaceContractsPage from './pages/InterfaceContracts';
import ImportClientsSimple from './pages/ImportClientsSimple';
import ImportDataPage from './pages/ImportData';
import ImportDetailsPage from './pages/ImportDetailsPage';
import ImportEtatsAvancementPage from './pages/ImportEtatsAvancement';
import ImportGenericPage from './pages/ImportGeneric';
import ImportHistoryPage from './pages/ImportHistoryPage';
import ImportProjetsPage from './pages/ImportProjets';
import ImportRessourcesPage from './pages/ImportRessources';
import ImportUsersPage from './pages/ImportUsers';
import IntelligenceArtificielle from './pages/IntelligenceArtificielle';
import ListesValeurs from './pages/ListesValeurs';
import Login from './pages/Login';
import MaintenanceArticlesPage from './pages/MaintenanceArticlesPage';
import MaintenanceHierarchyPage from './pages/MaintenanceHierarchyPage';
import MaintenancePage from './pages/MaintenancePage';
import MaintenanceBackupsPage from './pages/MaintenanceBackupsPage';
import MaintenancePeToolsPage from './pages/MaintenancePeToolsPage';
import MaintenanceIbauPage from './pages/MaintenanceIbauPage';
import ModeEmploi from './pages/ModeEmploi';
import Parametres from './pages/Parametres';
import ProjectDetailPage from './pages/ProjectDetailPage';
import ProjectsPage from './pages/ProjectsPage';
import ModelProjectPage from './pages/ModelProjectPage';
import ProjetsAReprendre from './pages/ProjetsAReprendre';
import ReglesGestion from './pages/ReglesGestion';
import ResetPassword from './pages/ResetPassword';
import ResourceDetailPage from './pages/ResourceDetailPage';
import IfsPersonPage from './pages/resources/IfsPersonPage';
import MaintPersonResourcePage from './pages/resources/MaintPersonResourcePage';
import ResourceAvailabilityPage from './pages/resources/ResourceAvailabilityPage';
import ResourceConnectionPageAdvanced from './pages/resources/ResourceConnectionPageAdvanced';
import ResourceDetailFilePageAdvanced from './pages/resources/ResourceDetailFilePageAdvanced';
import ResourceParentPage from './pages/resources/ResourceParentPage';
import ResourcesPage from './pages/ResourcesPage';
import ResultatsIA from './pages/ResultatsIA';
import SapArticles from './pages/SapArticles';
import SapData from './pages/SapData';
import SapDataClients from './pages/SapDataClients';
import SapDataExplorerPage from './pages/SapDataExplorer';
import SapDataFournisseurs from './pages/SapDataFournisseurs';
import SapTableCatalog from './pages/SapTableCatalog';
import SecurityPage from './pages/security/SecurityPage';
import SharePointProjectsPage from './pages/SharePointProjectsPage';
import SharePointResourcesPage from './pages/SharePointResourcesPage';
import SharePointUsersPage from './pages/SharePointUsersPage';
import SmtpConfigPage from './pages/SmtpConfigPage';
import TableStructureManagement from './pages/TableStructureManagementNew';
import TranscodificationManagement from './pages/TranscodificationManagement';
import UserDetailPage from './pages/UserDetailPage';
import { AppDispatch, RootState } from './store';
import { fetchCurrentUser } from './store/slices/authSlice';

// Composant pour protéger les routes qui nécessitent une authentification
const ProtectedRoute = ({ children }: { children: JSX.Element }) => {
  const { isAuthenticated, status } = useSelector((state: RootState) => state.auth);
  const location = useLocation();
  
  // Afficher un spinner pendant la vérification de l'authentification
  if (status === 'loading') {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  // Toujours vérifier l'authentification (même en développement)
  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Rendre le composant enfant si authentifié
  return children;
};

function App() {
  const dispatch = useDispatch<AppDispatch>();
  const { isAuthenticated, user, token } = useSelector((state: RootState) => state.auth);

  useEffect(() => {
    // Récupérer les infos utilisateur seulement si on a un token mais pas d'infos utilisateur
    if (token && !user && isAuthenticated) {
      dispatch(fetchCurrentUser());
    }
  }, [dispatch, token, user, isAuthenticated]);

  return (
    <Box sx={{ display: 'flex', height: '100vh' }}>
      <Routes>
        {/* Routes accessibles sans authentification */}
        <Route path="/login" element={<Login />} />
        <Route path="/reset-password" element={<ResetPassword />} />

        {/* Routes protégées (nécessitent une authentification) */}
        <Route path="/" element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }>
          <Route index element={<Dashboard />} />
          <Route path="extraction" element={<ExtractionHub />} />
          <Route path="extraction/data" element={<Extraction />} />
          <Route path="extraction/new" element={<Extraction mode="new" />} />
          <Route path="extraction/history" element={<Extraction mode="history" />} />
          <Route path="extraction/metadata" element={<MetadataExtraction />} />
          <Route path="extraction/status" element={<Extraction mode="status" />} />
          
          {/* Redirection du menu Données vers la page d'accueil */}
          <Route path="data" element={<Navigate to="/" replace />} />
          <Route path="data/:tableName" element={<Navigate to="/" replace />} />
          
          {/* Routes pour les données SAP */}
          <Route path="sap-data" element={<SapData />} />
          <Route path="sap-data/fournisseurs" element={<SapDataFournisseurs />} />
          <Route path="sap-data/clients" element={<SapDataClients />} />
          <Route path="sap-data/articles" element={<SapArticles />} />
          <Route path="sap-data/catalog" element={<SapTableCatalog />} />
          <Route path="sap-data/explorer" element={<SapDataExplorerPage />} />
          <Route path="sap-raw-data" element={<Navigate to="/sap-data" replace />} />
          
          {/* Routes pour les données IFS */}
          <Route path="ifs-data" element={<IfsData />} />
          <Route path="ifs-data/catalog" element={<IfsCatalog />} />
          <Route path="ifs-data/clients" element={<IfsDataClients />} />
          <Route path="ifs-data/fournisseurs" element={<IfsDataFournisseurs />} />
          <Route path="ifs-data/articles" element={<IfsDataArticles />} />
          <Route path="ifs-target-data" element={<Navigate to="/ifs-data" replace />} />
          
          {/* Routes pour les projets */}
          <Route path="projets" element={<ProjectsPage />} />
          <Route path="projets/modele" element={<ModelProjectPage />} />
          <Route path="projets/a-reprendre" element={<ProjetsAReprendre />} />
          
          {/* Routes pour les ressources */}
          <Route path="ressources" element={<ResourcesPage />} />
          <Route path="ressources/detail-file" element={<ResourceDetailFilePageAdvanced />} />
          <Route path="ressources/connection" element={<ResourceConnectionPageAdvanced />} />
          <Route path="ressources/availability" element={<ResourceAvailabilityPage />} />
          <Route path="ressources/parent" element={<ResourceParentPage />} />
          <Route path="ressources/maint-person" element={<MaintPersonResourcePage />} />
          <Route path="ressources/ifs-person" element={<IfsPersonPage />} />
          
          {/* Route pour le chargement des données */}
          <Route path="data-loading" element={<DataLoadingPage />} />
          
          {/* Route pour l'explorateur de données */}
          <Route path="data-browser" element={<DataBrowserPage />} />

          {/* Contrats d'interface SAP -> IFS (deep link par table pour envoi
              d'un lien direct au metier) */}
          <Route path="interface-contracts/:tableCible?" element={<InterfaceContractsPage />} />
          
          {/* Routes pour l'import des données */}
          <Route path="data-import" element={<ImportDataPage />} />
          <Route path="import" element={<ImportDataPage />} />
          <Route path="import/generic" element={<ImportGenericPage />} />
          <Route path="import/history" element={<ImportHistoryPage />} />
          <Route path="import/details/:jobUuid" element={<ImportDetailsPage />} />
          <Route path="import/articles" element={<ImportArticlesPage />} />
          <Route path="import/clients" element={<ImportClientsSimple />} />
          <Route path="import/projets" element={<ImportProjetsPage />} />
          <Route path="import/etats-avancement" element={<ImportEtatsAvancementPage />} />
          <Route path="import/ressources" element={<ImportRessourcesPage />} />
          <Route path="import/users" element={<ImportUsersPage />} />
          <Route path="import/sharepoint-projects" element={<SharePointProjectsPage />} />
          <Route path="import/sharepoint-resources" element={<SharePointResourcesPage />} />
          <Route path="import/sharepoint-users" element={<SharePointUsersPage />} />
          <Route path="ressources/detail/:resourceId" element={<ResourceDetailPage />} />
          <Route path="users/detail/:userId" element={<UserDetailPage />} />
          <Route path="projets/detail/:projectId" element={<ProjectDetailPage />} />
          
          {/* Routes pour l'export des données */}
          <Route path="data-exports" element={<ExportData />} />
          <Route path="export/fournisseurs" element={<ExportFournisseurs />} />
          <Route path="export/articles" element={<ExportArticles />} />
          <Route path="export/maintenance" element={<ExportMaintenance />} />
          <Route path="export/pm-action" element={<ExportPmAction />} />
          <Route path="export/operations" element={<ExportOperation />} />
          <Route path="export/structure-maintenance" element={<ExportStructureMaintenance />} />
          <Route path="maintenance" element={<MaintenancePage />} />
          <Route path="maintenance/hierarchy" element={<MaintenanceHierarchyPage />} />
          <Route path="maintenance/equipment" element={<EquipmentPage />} />
          <Route path="maintenance/articles" element={<MaintenanceArticlesPage />} />
          <Route path="maintenance/articles/ersa" element={<MaintenanceArticlesPage fixedMtart="ERSA" />} />
          <Route path="maintenance/articles/ibau" element={<MaintenanceArticlesPage fixedMtart="IBAU" />} />
          <Route path="maintenance/articles/nlag" element={<MaintenanceArticlesPage fixedMtart="NLAG" />} />
          <Route path="maintenance/ih02" element={<IH02HierarchyPage />} />
          <Route path="maintenance/backups" element={<MaintenanceBackupsPage />} />
          <Route path="maintenance/pe-tools" element={<MaintenancePeToolsPage />} />
          <Route path="maintenance/ibau" element={<MaintenanceIbauPage />} />
          <Route path="export/clients" element={<ExportClients />} />
          <Route path="export/projets" element={<ExportProjects />} />
          
          {/* Route Assistant IA */}
          <Route path="intelligence-artificielle" element={<IntelligenceArtificielle />} />
          <Route path="assistant-ia" element={<AssistantIA />} />
          <Route path="resultats-ia" element={<ResultatsIA />} />
          <Route path="configuration-ia" element={<ConfigurationIA />} />
          <Route path="hermes" element={<HermesChat />} />

          {/* Modes d'emploi (guides HTML servis depuis public/guides/) */}
          <Route path="mode-emploi" element={<ModeEmploi />} />

          {/* Routes pour la configuration */}
          <Route path="configuration" element={<Configuration />} />
          <Route path="configuration/field-mappings" element={<FieldMappingManagement />} />
          <Route path="configuration/transcodifications" element={<TranscodificationManagement />} />
          <Route path="configuration/valeurs-defaut" element={<DefaultValuesManagement />} />
          <Route path="configuration/matrice-site-famille" element={<MatriceSiteFamille />} />
          <Route path="configuration/security" element={<SecurityPage />} />
          <Route path="configuration/table-structure" element={<TableStructureManagement />} />
          <Route path="configuration/smtp" element={<SmtpConfigPage />} />

          {/* Routes pour la configuration */}
          <Route path="transcodification" element={<TranscodificationManagement />} />
          <Route path="mapping-champs" element={<FieldMappingManagement />} />
          <Route path="regles-gestion" element={<ReglesGestion />} />
          <Route path="parametres" element={<Parametres />} />
          <Route path="listes-valeurs" element={<ListesValeurs />} />
          
          {/* Routes d'administration */}
          <Route path="admin/export-queries" element={<ExportQueriesManagement />} />
          <Route path="admin/import-types" element={<ImportTypesConfiguration />} />
        </Route>

        {/* Redirection des routes inconnues vers la page d'accueil */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Box>
  );
}

export default App;