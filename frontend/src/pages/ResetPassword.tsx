import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Container,
  Paper,
  TextField,
  Typography
} from '@mui/material';
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import api from '../services/api';

const ResetPassword = () => {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token') || '';
  const navigate = useNavigate();

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!token) {
      setStatus('error');
      setMessage('Token manquant. Veuillez utiliser le lien reçu par email.');
      return;
    }

    if (password.length < 6) {
      setStatus('error');
      setMessage('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    if (password !== confirmPassword) {
      setStatus('error');
      setMessage('Les mots de passe ne correspondent pas.');
      return;
    }

    setStatus('loading');
    try {
      const response = await api.post('/auth/reset-password', { token, password });
      setStatus('success');
      setMessage(response.data.message || 'Mot de passe réinitialisé avec succès.');
    } catch (err: any) {
      setStatus('error');
      setMessage(err.response?.data?.error || 'Erreur lors de la réinitialisation.');
    }
  };

  return (
    <Container maxWidth="sm">
      <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', py: 4 }}>
        <Paper elevation={3} sx={{ p: 4, width: '100%', maxWidth: 400 }}>
          <Typography component="h1" variant="h5" align="center" gutterBottom>
            Réinitialiser le mot de passe
          </Typography>

          {status === 'success' ? (
            <>
              <Alert severity="success" sx={{ mb: 2 }}>{message}</Alert>
              <Button fullWidth variant="contained" onClick={() => navigate('/login')}>
                Retour à la connexion
              </Button>
            </>
          ) : (
            <Box component="form" onSubmit={handleSubmit} sx={{ mt: 1 }}>
              <TextField
                margin="normal"
                required
                fullWidth
                label="Nouveau mot de passe"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={status === 'loading'}
              />
              <TextField
                margin="normal"
                required
                fullWidth
                label="Confirmer le mot de passe"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                disabled={status === 'loading'}
              />

              {status === 'error' && (
                <Alert severity="error" sx={{ mt: 2 }}>{message}</Alert>
              )}

              <Button
                type="submit"
                fullWidth
                variant="contained"
                sx={{ mt: 3, mb: 1 }}
                disabled={status === 'loading'}
              >
                {status === 'loading' ? <CircularProgress size={20} color="inherit" /> : 'Réinitialiser'}
              </Button>
              <Button fullWidth variant="text" onClick={() => navigate('/login')} sx={{ mt: 1 }}>
                Retour à la connexion
              </Button>
            </Box>
          )}
        </Paper>
      </Box>
    </Container>
  );
};

export default ResetPassword;
