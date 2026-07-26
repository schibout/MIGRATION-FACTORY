import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  FormControlLabel,
  Grid,
  IconButton,
  InputAdornment,
  Paper,
  Stack,
  Switch,
  Tab,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import RestartAltIcon from '@mui/icons-material/RestartAlt';
import SaveIcon from '@mui/icons-material/Save';
import VisibilityIcon from '@mui/icons-material/Visibility';
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff';
import NetworkCheckIcon from '@mui/icons-material/NetworkCheck';
import { useEffect, useMemo, useState } from 'react';
import settingsService, {
  SettingCategory,
  SettingItem,
  TestResult,
  TestTarget,
} from '../services/settingsService';

const MASK = '••••••••';

const TEST_TARGETS: Record<string, TestTarget> = {
  database: 'database',
  sap: 'sap',
  sharepoint: 'sharepoint',
  smtp: 'smtp',
};

type DraftValues = Record<string, string>;

const Parametres: React.FC = () => {
  const [categories, setCategories] = useState<SettingCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [activeTab, setActiveTab] = useState(0);
  const [draft, setDraft] = useState<DraftValues>({});
  const [revealed, setRevealed] = useState<Record<string, boolean>>({});
  const [message, setMessage] = useState<{ type: 'success' | 'error' | 'info'; text: string } | null>(null);
  const [testing, setTesting] = useState<TestTarget | null>(null);
  const [testResults, setTestResults] = useState<Record<string, TestResult>>({});

  useEffect(() => {
    load();
  }, []);

  const load = async () => {
    setLoading(true);
    try {
      const data = await settingsService.getAll();
      setCategories(data);
      const init: DraftValues = {};
      data.forEach((cat) =>
        cat.items.forEach((item) => {
          init[item.key] = item.value || '';
        }),
      );
      setDraft(init);
    } catch (e: any) {
      setMessage({ type: 'error', text: e?.response?.data?.error || 'Erreur lors du chargement des paramètres' });
    } finally {
      setLoading(false);
    }
  };

  const dirtyKeys = useMemo(() => {
    const dirty: string[] = [];
    categories.forEach((cat) =>
      cat.items.forEach((item) => {
        const current = draft[item.key] ?? '';
        const original = item.value || '';
        if (item.secret) {
          // Pour les secrets, on ne sauvegarde que si l'utilisateur a saisi une valeur ≠ MASK et ≠ vide
          if (current && current !== MASK && current !== original) dirty.push(item.key);
        } else if (current !== original) {
          dirty.push(item.key);
        }
      }),
    );
    return dirty;
  }, [draft, categories]);

  const requiresRestart = useMemo(() => {
    return categories.some((cat) =>
      cat.items.some((item) => dirtyKeys.includes(item.key) && item.requires_restart),
    );
  }, [categories, dirtyKeys]);

  const handleChange = (key: string, value: string) => {
    setDraft((prev) => ({ ...prev, [key]: value }));
  };

  const handleSave = async () => {
    if (dirtyKeys.length === 0) return;
    setSaving(true);
    setMessage(null);
    try {
      const payload: DraftValues = {};
      dirtyKeys.forEach((k) => {
        payload[k] = draft[k];
      });
      const res = await settingsService.update(payload);
      setMessage({
        type: 'success',
        text: `${res.updated.length} paramètre(s) sauvegardé(s).${requiresRestart ? ' Un redémarrage du backend est nécessaire pour certains changements.' : ''}`,
      });
      await load();
    } catch (e: any) {
      setMessage({ type: 'error', text: e?.response?.data?.error || 'Erreur lors de la sauvegarde' });
    } finally {
      setSaving(false);
    }
  };

  const handleTest = async (target: TestTarget) => {
    setTesting(target);
    try {
      const res = await settingsService.test(target);
      setTestResults((prev) => ({ ...prev, [target]: res }));
    } catch (e: any) {
      setTestResults((prev) => ({
        ...prev,
        [target]: { success: false, error: e?.response?.data?.error || 'Erreur réseau' },
      }));
    } finally {
      setTesting(null);
    }
  };

  const toggleReveal = (key: string) => {
    setRevealed((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const renderField = (item: SettingItem) => {
    const value = draft[item.key] ?? '';
    const showReveal = revealed[item.key];

    if (item.type === 'boolean') {
      const checked = (value || '').toLowerCase() === 'true';
      return (
        <FormControlLabel
          control={
            <Switch
              checked={checked}
              onChange={(e) => handleChange(item.key, e.target.checked ? 'true' : 'false')}
            />
          }
          label={item.label}
        />
      );
    }

    const isPassword = item.type === 'password' || item.secret;
    return (
      <TextField
        fullWidth
        size="small"
        type={isPassword && !showReveal ? 'password' : item.type === 'number' ? 'number' : 'text'}
        label={item.label}
        value={value}
        onChange={(e) => handleChange(item.key, e.target.value)}
        placeholder={item.secret && item.has_value ? MASK : ''}
        helperText={item.key}
        InputProps={
          isPassword
            ? {
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton size="small" onClick={() => toggleReveal(item.key)} edge="end">
                      {showReveal ? <VisibilityOffIcon fontSize="small" /> : <VisibilityIcon fontSize="small" />}
                    </IconButton>
                  </InputAdornment>
                ),
              }
            : undefined
        }
      />
    );
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  const currentCategory = categories[activeTab];
  const testTarget = currentCategory ? TEST_TARGETS[currentCategory.key] : undefined;
  const currentTestResult = testTarget ? testResults[testTarget] : undefined;

  return (
    <Box sx={{ p: 3 }}>
      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 2 }}>
        <Box>
          <Typography variant="h4" gutterBottom>
            Paramètres système
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Variables de connexion (SAP, base de données, SharePoint, SMTP…) et configuration globale.
            Les valeurs saisies ici surchargent celles du fichier <code>.env</code>.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1}>
          {requiresRestart && (
            <Chip
              color="warning"
              icon={<RestartAltIcon />}
              label="Redémarrage backend requis"
              size="small"
            />
          )}
          <Button variant="outlined" onClick={load} disabled={saving}>
            Recharger
          </Button>
          <Button
            variant="contained"
            startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveIcon />}
            onClick={handleSave}
            disabled={saving || dirtyKeys.length === 0}
          >
            Sauvegarder ({dirtyKeys.length})
          </Button>
        </Stack>
      </Stack>

      {message && (
        <Alert severity={message.type} onClose={() => setMessage(null)} sx={{ mb: 2 }}>
          {message.text}
        </Alert>
      )}

      <Paper variant="outlined">
        <Tabs
          value={activeTab}
          onChange={(_, v) => setActiveTab(v)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: 'divider' }}
        >
          {categories.map((cat, idx) => (
            <Tab key={cat.key} label={cat.label} id={`settings-tab-${idx}`} />
          ))}
        </Tabs>

        {currentCategory && (
          <Box sx={{ p: 3 }}>
            {testTarget && (
              <Stack direction="row" spacing={2} alignItems="center" sx={{ mb: 2 }}>
                <Tooltip title="Tester la connexion avec les valeurs courantes (sauvegardez d'abord)">
                  <span>
                    <Button
                      variant="outlined"
                      size="small"
                      startIcon={
                        testing === testTarget ? (
                          <CircularProgress size={14} />
                        ) : (
                          <NetworkCheckIcon />
                        )
                      }
                      onClick={() => handleTest(testTarget)}
                      disabled={testing !== null}
                    >
                      Tester la connexion
                    </Button>
                  </span>
                </Tooltip>
                {currentTestResult && (
                  <Alert
                    severity={currentTestResult.success ? 'success' : 'error'}
                    sx={{ flex: 1, py: 0 }}
                  >
                    {currentTestResult.success
                      ? currentTestResult.message || 'OK'
                      : currentTestResult.error || 'Échec'}
                    {currentTestResult.details && (
                      <Typography variant="caption" display="block" sx={{ opacity: 0.8 }}>
                        {currentTestResult.details}
                      </Typography>
                    )}
                  </Alert>
                )}
              </Stack>
            )}

            <Grid container spacing={2}>
              {currentCategory.items.map((item) => (
                <Grid item xs={12} sm={6} md={4} key={item.key}>
                  {renderField(item)}
                  {item.requires_restart && (
                    <Chip
                      size="small"
                      variant="outlined"
                      icon={<RestartAltIcon sx={{ fontSize: 14 }} />}
                      label="Redémarrage requis"
                      sx={{ mt: 0.5, fontSize: 10, height: 20 }}
                    />
                  )}
                </Grid>
              ))}
            </Grid>
          </Box>
        )}
      </Paper>

      <Box sx={{ mt: 2 }}>
        <Typography variant="caption" color="text.secondary">
          Astuce : les mots de passe restent masqués. Laissez le champ vide ou avec « {MASK} » pour conserver
          la valeur actuelle. Saisissez une nouvelle valeur uniquement pour la changer.
        </Typography>
      </Box>
    </Box>
  );
};

export default Parametres;
