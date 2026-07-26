import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  FormControlLabel,
  Grid,
  Switch,
  TextField,
  Typography
} from '@mui/material';
import { useEffect, useState } from 'react';
import api from '../services/api';

interface SmtpConfig {
  smtp_server: string;
  smtp_port: number;
  smtp_use_tls: boolean;
  smtp_username: string;
  smtp_password: string;
  smtp_from_email: string;
  smtp_from_name: string;
  password_reset_expiry: number;
  frontend_url: string;
}

const SmtpConfigPage = () => {
  const [config, setConfig] = useState<SmtpConfig>({
    smtp_server: '',
    smtp_port: 587,
    smtp_use_tls: true,
    smtp_username: '',
    smtp_password: '',
    smtp_from_email: '',
    smtp_from_name: 'Migration Factory',
    password_reset_expiry: 3600,
    frontend_url: 'http://localhost:3000',
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testEmail, setTestEmail] = useState('');
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    try {
      const response = await api.get('/auth/smtp-config');
      setConfig((prev) => ({ ...prev, ...response.data, smtp_password: '' }));
    } catch {
      setMessage({ type: 'error', text: 'Impossible de charger la configuration SMTP' });
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    setMessage(null);
    try {
      const payload: Record<string, unknown> = { ...config };
      if (!config.smtp_password) delete payload.smtp_password;
      await api.put('/auth/smtp-config', payload);
      setMessage({ type: 'success', text: 'Configuration SMTP sauvegardée' });
    } catch (err: any) {
      setMessage({ type: 'error', text: err.response?.data?.error || 'Erreur lors de la sauvegarde' });
    } finally {
      setSaving(false);
    }
  };

  const handleTest = async () => {
    if (!testEmail.trim()) return;
    setTesting(true);
    setMessage(null);
    try {
      const response = await api.post('/auth/smtp-config/test', { email: testEmail });
      setMessage({ type: 'success', text: response.data.message });
    } catch (err: any) {
      setMessage({ type: 'error', text: err.response?.data?.error || 'Erreur lors du test' });
    } finally {
      setTesting(false);
    }
  };

  const handleChange = (field: keyof SmtpConfig) => (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.type === 'number' ? Number(e.target.value) : e.target.value;
    setConfig((prev) => ({ ...prev, [field]: value }));
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3, maxWidth: 800, mx: 'auto' }}>
      <Typography variant="h4" gutterBottom>Configuration SMTP</Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Paramètres du serveur de messagerie pour l'envoi des emails de réinitialisation de mot de passe.
      </Typography>

      {message && (
        <Alert severity={message.type} sx={{ mb: 2 }} onClose={() => setMessage(null)}>
          {message.text}
        </Alert>
      )}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Serveur SMTP</Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={8}>
              <TextField fullWidth label="Serveur SMTP" value={config.smtp_server} onChange={handleChange('smtp_server')} placeholder="smtp.example.com" />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField fullWidth label="Port" type="number" value={config.smtp_port} onChange={handleChange('smtp_port')} />
            </Grid>
            <Grid item xs={12}>
              <FormControlLabel
                control={<Switch checked={config.smtp_use_tls} onChange={(e) => setConfig((prev) => ({ ...prev, smtp_use_tls: e.target.checked }))} />}
                label="Utiliser TLS"
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="Nom d'utilisateur SMTP" value={config.smtp_username} onChange={handleChange('smtp_username')} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="Mot de passe SMTP" type="password" value={config.smtp_password} onChange={handleChange('smtp_password')} placeholder="Laisser vide pour ne pas modifier" />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Expéditeur</Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="Email expéditeur" value={config.smtp_from_email} onChange={handleChange('smtp_from_email')} placeholder="noreply@example.com" />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="Nom expéditeur" value={config.smtp_from_name} onChange={handleChange('smtp_from_name')} />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Paramètres</Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="Expiration du lien (secondes)" type="number" value={config.password_reset_expiry} onChange={handleChange('password_reset_expiry')} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField fullWidth label="URL du frontend" value={config.frontend_url} onChange={handleChange('frontend_url')} />
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Box sx={{ display: 'flex', gap: 2, mb: 3 }}>
        <Button variant="contained" onClick={handleSave} disabled={saving}>
          {saving ? <CircularProgress size={20} /> : 'Sauvegarder'}
        </Button>
      </Box>

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>Tester la configuration</Typography>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
            <TextField label="Email de test" value={testEmail} onChange={(e) => setTestEmail(e.target.value)} size="small" sx={{ flex: 1 }} />
            <Button variant="outlined" onClick={handleTest} disabled={testing || !testEmail.trim()}>
              {testing ? <CircularProgress size={20} /> : 'Envoyer un test'}
            </Button>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
};

export default SmtpConfigPage;
