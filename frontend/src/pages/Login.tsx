import {
    Alert,
    Box,
    Button,
    CircularProgress,
    Container,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Link,
    Paper,
    TextField,
    Typography
} from '@mui/material';
import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useLocation, useNavigate } from 'react-router-dom';
import { RootState } from '../store';
import { clearError, login } from '../store/slices/authSlice';
import api from '../services/api';

const Login = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  
  const { status, error, isAuthenticated } = useSelector((state: RootState) => state.auth);
  
  const from = location.state?.from || '/';

  const [forgotOpen, setForgotOpen] = useState(false);
  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotStatus, setForgotStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [forgotMessage, setForgotMessage] = useState('');
  
  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true });
    }
    return () => {
      dispatch(clearError());
    };
  }, [navigate, dispatch, isAuthenticated, from]);
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (username.trim() && password.trim()) {
      dispatch(login({ username, password }) as any);
    }
  };

  useEffect(() => {
    if (isAuthenticated && status === 'succeeded') {
      navigate(from, { replace: true });
    }
  }, [isAuthenticated, status, navigate, from]);

  const handleForgotPassword = async () => {
    if (!forgotEmail.trim()) return;
    setForgotStatus('loading');
    try {
      const response = await api.post('/auth/forgot-password', { email: forgotEmail });
      setForgotStatus('success');
      setForgotMessage(response.data.message || 'Un email de réinitialisation a été envoyé.');
    } catch (err: any) {
      setForgotStatus('error');
      setForgotMessage(err.response?.data?.error || 'Erreur lors de l\'envoi.');
    }
  };

  const handleCloseForgot = () => {
    setForgotOpen(false);
    setForgotEmail('');
    setForgotStatus('idle');
    setForgotMessage('');
  };

  return (
    <Container maxWidth="sm">
      <Box sx={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'center', 
        justifyContent: 'center', 
        minHeight: '100vh',
        py: 4
      }}>
        <Paper elevation={3} sx={{ p: 4, width: '100%', maxWidth: 400 }}>
          <Typography component="h1" variant="h4" align="center" gutterBottom>
            Connexion
          </Typography>
          
          {from !== '/' && (
            <Alert severity="info" sx={{ mb: 2 }}>
              Vous devez vous connecter pour accéder à cette page.
            </Alert>
          )}
          
          <Box component="form" onSubmit={handleSubmit} sx={{ mt: 1 }}>
            <TextField
              margin="normal"
              required
              fullWidth
              id="username"
              label="Nom d'utilisateur"
              name="username"
              autoComplete="username"
              autoFocus
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={status === 'loading'}
            />
            <TextField
              margin="normal"
              required
              fullWidth
              name="password"
              label="Mot de passe"
              type="password"
              id="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={status === 'loading'}
            />
            
            {error && (
              <Alert severity="error" sx={{ mt: 2 }}>
                {error}
              </Alert>
            )}
            
            <Button
              type="submit"
              fullWidth
              variant="contained"
              sx={{ mt: 3, mb: 1 }}
              disabled={status === 'loading'}
            >
              {status === 'loading' ? (
                <CircularProgress size={20} color="inherit" />
              ) : (
                'Se connecter'
              )}
            </Button>

            <Box sx={{ textAlign: 'center', mt: 1 }}>
              <Link
                component="button"
                type="button"
                variant="body2"
                onClick={() => setForgotOpen(true)}
                sx={{ cursor: 'pointer' }}
              >
                Mot de passe oublié ?
              </Link>
            </Box>
          </Box>
        </Paper>
      </Box>

      <Dialog open={forgotOpen} onClose={handleCloseForgot} maxWidth="xs" fullWidth>
        <DialogTitle>Mot de passe oublié</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Saisissez votre adresse email. Un lien de réinitialisation vous sera envoyé.
          </Typography>
          <TextField
            autoFocus
            fullWidth
            label="Adresse email"
            type="email"
            value={forgotEmail}
            onChange={(e) => setForgotEmail(e.target.value)}
            disabled={forgotStatus === 'loading' || forgotStatus === 'success'}
          />
          {forgotStatus === 'success' && (
            <Alert severity="success" sx={{ mt: 2 }}>{forgotMessage}</Alert>
          )}
          {forgotStatus === 'error' && (
            <Alert severity="error" sx={{ mt: 2 }}>{forgotMessage}</Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseForgot}>Fermer</Button>
          {forgotStatus !== 'success' && (
            <Button
              onClick={handleForgotPassword}
              variant="contained"
              disabled={forgotStatus === 'loading' || !forgotEmail.trim()}
            >
              {forgotStatus === 'loading' ? <CircularProgress size={20} /> : 'Envoyer'}
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Container>
  );
};

export default Login;