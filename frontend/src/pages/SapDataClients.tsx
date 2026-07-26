import { Navigate } from 'react-router-dom';

/** Comme Achats : périmètre clients = catalogue tables + structure + lien explorateur. */
const SapDataClients = () => <Navigate to="/sap-data/catalog?scope=client" replace />;

export default SapDataClients;
