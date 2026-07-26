import {
  ArrowBack as BackIcon,
  Close as CloseIcon,
  Edit as EditIcon,
  Key as KeyIcon,
  MenuBook as CatalogIcon,
  Search as SearchIcon
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TableSortLabel,
  Tabs,
  TextField,
  Tooltip,
  Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ifsCatalogService, {
  IfsCatalogEntity,
  IfsCatalogField,
  IfsCatalogLot,
  IfsCatalogRule,
  IfsCatalogRuleType,
  IfsCatalogStats
} from '../services/ifsCatalogService';

const RULE_LABELS: Record<IfsCatalogRuleType, string> = {
  NOT_NULL_ON_LOAD: 'Obligatoire au chargement',
  DEFAULT: 'Valeur par défaut',
  ENUM_DB_VALUES: 'Énumération',
  FK_LOGICAL: 'Référence (LOV)',
};

const RULE_COLORS: Record<IfsCatalogRuleType, 'error' | 'info' | 'secondary' | 'warning'> = {
  NOT_NULL_ON_LOAD: 'error',
  DEFAULT: 'info',
  ENUM_DB_VALUES: 'secondary',
  FK_LOGICAL: 'warning',
};

const ALL_LOTS = '__ALL__';

type EntitySortField = keyof IfsCatalogEntity;

// Champs de curation modifiables dans la popup (miroir de la whitelist backend).
const EDITABLE_KEYS: (keyof IfsCatalogField)[] = [
  'field_label_fr', 'default_value', 'reference', 'sort_order', 'data_length',
  'mandatory', 'in_scope', 'insertable', 'updatable', 'lov',
  'comments', 'transformation_rules',
];

// Thème métier déduit du nom d'entité (aligné sur les cartes "Données IFS").
// Premier mot-clé trouvé (dans l'ordre) l'emporte.
const THEME_RULES: { theme: string; color: string; keywords: string[] }[] = [
  { theme: 'Projets', color: '#f44336', keywords: ['PROJECT', 'PROJ', 'ACTIVITY', 'TEAM', 'REPORT_PROJECT'] },
  { theme: 'Fournisseurs', color: '#3f51b5', keywords: ['SUPPLIER', 'VENDOR', 'FOURNISSEUR'] },
  { theme: 'Clients', color: '#ff9800', keywords: ['CUSTOMER', 'CLIENT'] },
  { theme: 'Articles', color: '#4caf50', keywords: ['PART', 'ARTICLE', 'INVENTORY', 'SALES_PART', 'PURCHASE'] },
  { theme: 'Maintenance', color: '#9c27b0', keywords: ['MAINTENANCE', 'PM_', 'EQUIPMENT', 'FUNCTIONAL_LOCATION', 'WORK_ORDER', 'ASSET'] },
  { theme: 'Structure', color: '#2196f3', keywords: ['SITE', 'COMPANY', 'ORG', 'STRUCTURE', 'BRANCH'] },
];

const THEME_COLORS: Record<string, string> = Object.fromEntries(
  THEME_RULES.map((r) => [r.theme, r.color])
);

const themeColor = (theme?: string) => THEME_COLORS[theme ?? ''] ?? '#607d8b';

// Domaines métier proposés à la sélection manuelle
const DOMAIN_OPTIONS = [...THEME_RULES.map((r) => r.theme), 'Autre'];

const deriveTheme = (entity: string): string => {
  const name = entity.toUpperCase();
  for (const rule of THEME_RULES) {
    if (rule.keywords.some((kw) => name.includes(kw))) return rule.theme;
  }
  return 'Autre';
};

const computeAggregates = (fields: IfsCatalogField[]) => ({
  nb_fields: fields.length,
  nb_in_scope: fields.filter((f) => f.in_scope).length,
  nb_mandatory: fields.filter((f) => f.mandatory && f.in_scope).length,
  nb_defaults: fields.filter((f) => f.default_value != null).length,
  nb_enums: fields.filter((f) => f.enumeration_values && f.enumeration_values.length > 0).length,
  nb_references: fields.filter((f) => f.reference != null).length,
  nb_pk: fields.filter((f) => f.primary_key).length,
});

const IfsCatalog: React.FC = () => {
  const navigate = useNavigate();

  const [lots, setLots] = useState<IfsCatalogLot[]>([]);
  const [selectedLot, setSelectedLot] = useState<string>('');
  const [tab, setTab] = useState(0);
  const [loading, setLoading] = useState(false);

  // Onglet Catalogue
  const [entities, setEntities] = useState<IfsCatalogEntity[]>([]);
  const [entitySearch, setEntitySearch] = useState('');
  const [themeFilter, setThemeFilter] = useState('');
  const [entityFields, setEntityFields] = useState<Record<string, IfsCatalogField[]>>({});
  const [loadingFields, setLoadingFields] = useState<Record<string, boolean>>({});
  const [fieldSearch, setFieldSearch] = useState('');
  const [inScopeOnly, setInScopeOnly] = useState(false);
  const [mandatoryOnly, setMandatoryOnly] = useState(false);
  const [entitySort, setEntitySort] = useState<{ field: EntitySortField; dir: 'asc' | 'desc' }>({
    field: 'entity',
    dir: 'asc',
  });

  // Popups
  const [openEntity, setOpenEntity] = useState<IfsCatalogEntity | null>(null);
  const [editField, setEditField] = useState<IfsCatalogField | null>(null);
  const [editDraft, setEditDraft] = useState<Partial<IfsCatalogField>>({});
  const [savingField, setSavingField] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [savingTheme, setSavingTheme] = useState(false);

  // Onglet Règles
  const [rules, setRules] = useState<IfsCatalogRule[]>([]);
  const [rulesLoaded, setRulesLoaded] = useState(false);
  const [ruleEntityFilter, setRuleEntityFilter] = useState('');
  const [ruleTypeFilter, setRuleTypeFilter] = useState('');

  // Onglet Statistiques
  const [stats, setStats] = useState<IfsCatalogStats | null>(null);

  useEffect(() => {
    const loadLots = async () => {
      try {
        setLoading(true);
        const data = await ifsCatalogService.getLots();
        setLots(data);
        if (data.length > 0) {
          setSelectedLot(data[0].lot_id);
        }
      } catch (error) {
        console.error('Erreur lors du chargement des lots:', error);
      } finally {
        setLoading(false);
      }
    };
    loadLots();
  }, []);

  useEffect(() => {
    if (!selectedLot) return;
    // Changement de lot : on repart de zéro
    setEntities([]);
    setOpenEntity(null);
    setEntityFields({});
    setEntitySearch('');
    setThemeFilter('');
    setFieldSearch('');
    setRules([]);
    setRulesLoaded(false);
    setRuleEntityFilter('');
    setRuleTypeFilter('');
    setStats(null);

    const loadEntities = async () => {
      try {
        setLoading(true);
        const data = await ifsCatalogService.getEntities(selectedLot === ALL_LOTS ? '' : selectedLot);
        // Domaine métier : choix manuel (backend) sinon déduction du nom d'entité
        setEntities(data.map((e) => ({ ...e, theme: e.theme || deriveTheme(e.entity) })));
      } catch (error) {
        console.error('Erreur lors du chargement des entités:', error);
      } finally {
        setLoading(false);
      }
    };
    loadEntities();
  }, [selectedLot]);

  // Chargement paresseux des onglets Règles / Statistiques
  useEffect(() => {
    if (!selectedLot) return;
    const lotParam = selectedLot === ALL_LOTS ? '' : selectedLot;
    if (tab === 1 && !rulesLoaded) {
      ifsCatalogService.getRules(lotParam)
        .then((data) => { setRules(data); setRulesLoaded(true); })
        .catch((error) => console.error('Erreur lors du chargement des règles:', error));
    }
    if (tab === 2 && !stats) {
      ifsCatalogService.getStats(lotParam)
        .then(setStats)
        .catch((error) => console.error('Erreur lors du chargement des statistiques:', error));
    }
  }, [tab, selectedLot, rulesLoaded, stats]);

  const entityKey = (e: IfsCatalogEntity) => `${e.lot_id ?? ''}::${e.entity}`;

  const handleOpenEntity = async (e: IfsCatalogEntity) => {
    const key = entityKey(e);
    setOpenEntity(e);
    setFieldSearch('');
    if (!entityFields[key]) {
      try {
        setLoadingFields((prev) => ({ ...prev, [key]: true }));
        const fields = await ifsCatalogService.getEntityFields(e.entity, e.lot_id ?? selectedLot);
        setEntityFields((prev) => ({ ...prev, [key]: fields }));
      } catch (error) {
        console.error(`Erreur lors du chargement des champs de ${e.entity}:`, error);
      } finally {
        setLoadingFields((prev) => ({ ...prev, [key]: false }));
      }
    }
  };

  const openFieldEditor = (field: IfsCatalogField) => {
    setSaveError(null);
    setEditDraft({ ...field });
    setEditField(field);
  };

  const setDraft = (key: keyof IfsCatalogField, value: unknown) =>
    setEditDraft((prev) => ({ ...prev, [key]: value }));

  const saveField = async () => {
    if (!editField || !openEntity) return;
    const key = entityKey(openEntity);
    const patch: Partial<IfsCatalogField> = {};
    EDITABLE_KEYS.forEach((k) => { (patch as Record<string, unknown>)[k] = editDraft[k]; });
    try {
      setSavingField(true);
      setSaveError(null);
      const updated = await ifsCatalogService.updateField(editField.catalog_id, patch);
      const newFields = (entityFields[key] || []).map((f) =>
        f.catalog_id === updated.catalog_id ? updated : f
      );
      setEntityFields((prev) => ({ ...prev, [key]: newFields }));
      // Répercuter les compteurs de l'entité (in_scope / obligatoire / défaut ont pu changer)
      setEntities((prev) => prev.map((e) =>
        entityKey(e) === key ? { ...e, ...computeAggregates(newFields) } : e
      ));
      setEditField(null);
    } catch (error) {
      console.error('Erreur lors de la mise à jour du champ:', error);
      setSaveError("Échec de l'enregistrement. Vérifiez votre session et réessayez.");
    } finally {
      setSavingField(false);
    }
  };

  const changeEntityTheme = async (newTheme: string) => {
    if (!openEntity || newTheme === openEntity.theme) return;
    const key = entityKey(openEntity);
    const lot = openEntity.lot_id ?? selectedLot;
    try {
      setSavingTheme(true);
      await ifsCatalogService.updateEntityTheme(openEntity.entity, lot, newTheme);
      setOpenEntity((prev) => (prev ? { ...prev, theme: newTheme } : prev));
      setEntities((prev) => prev.map((e) => (entityKey(e) === key ? { ...e, theme: newTheme } : e)));
    } catch (error) {
      console.error('Erreur lors de la mise à jour du domaine métier:', error);
    } finally {
      setSavingTheme(false);
    }
  };

  const handleSortEntities = (field: EntitySortField) => {
    setEntitySort((prev) =>
      prev.field === field
        ? { field, dir: prev.dir === 'asc' ? 'desc' : 'asc' }
        : { field, dir: 'asc' }
    );
  };

  const showLotColumn = selectedLot === ALL_LOTS;

  const availableThemes = Array.from(new Set(entities.map((e) => e.theme ?? 'Autre'))).sort();

  const filteredEntities = entities
    .filter((e) => e.entity.toLowerCase().includes(entitySearch.toLowerCase()))
    .filter((e) => !themeFilter || e.theme === themeFilter)
    .sort((a, b) => {
      const av = a[entitySort.field];
      const bv = b[entitySort.field];
      let cmp: number;
      if (typeof av === 'number' && typeof bv === 'number') cmp = av - bv;
      else cmp = String(av ?? '').localeCompare(String(bv ?? ''));
      return entitySort.dir === 'asc' ? cmp : -cmp;
    });

  const filterFields = (fields: IfsCatalogField[]) =>
    fields.filter((f) => {
      if (inScopeOnly && !f.in_scope) return false;
      if (mandatoryOnly && !f.mandatory) return false;
      if (fieldSearch) {
        const term = fieldSearch.toLowerCase();
        return (
          f.field_name.toLowerCase().includes(term) ||
          (f.field_label_fr || '').toLowerCase().includes(term) ||
          (f.comments || '').toLowerCase().includes(term) ||
          (f.reference || '').toLowerCase().includes(term)
        );
      }
      return true;
    });

  const filteredRules = rules.filter((r) =>
    (!ruleEntityFilter || r.entity === ruleEntityFilter) &&
    (!ruleTypeFilter || r.rule === ruleTypeFilter)
  );

  const currentLot = lots.find((l) => l.lot_id === selectedLot);

  const openKey = openEntity ? entityKey(openEntity) : '';
  const openFields = openKey ? entityFields[openKey] : undefined;
  const openLoading = openKey ? loadingFields[openKey] : false;
  const openAgg = openFields ? computeAggregates(openFields) : null;

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      {/* Header */}
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3, flexWrap: 'wrap', gap: 2 }}>
        <IconButton onClick={() => navigate('/ifs-data')} sx={{ mr: 0 }}>
          <BackIcon />
        </IconButton>
        <CatalogIcon sx={{ fontSize: 32, color: '#009688' }} />
        <Typography variant="h4" component="h1" sx={{ flexGrow: 1 }}>
          Catalogue IFS
        </Typography>
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel id="lot-select-label">Lot</InputLabel>
          <Select
            labelId="lot-select-label"
            value={selectedLot}
            label="Lot"
            onChange={(e) => setSelectedLot(e.target.value)}
          >
            {lots.length > 1 && (
              <MenuItem value={ALL_LOTS}>Tous les lots</MenuItem>
            )}
            {lots.map((lot) => (
              <MenuItem key={lot.lot_id} value={lot.lot_id}>
                {lot.lot_id} ({lot.nb_entities} entités, {lot.nb_fields} champs)
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Dictionnaire des specs IFS chargé depuis les classeurs Lot*.xlsx : entités, champs,
        règles de gestion et mapping source→cible décidé en atelier.
        {currentLot?.loaded_at && ` Dernier chargement : ${new Date(currentLot.loaded_at).toLocaleString('fr-FR')}.`}
      </Typography>

      <Tabs value={tab} onChange={(_e, v) => setTab(v)} sx={{ mb: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Tab label="Catalogue" />
        <Tab label="Règles de gestion" />
        <Tab label="Statistiques" />
      </Tabs>

      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {!loading && lots.length === 0 && (
        <Card>
          <CardContent>
            <Typography>
              Le catalogue est vide : la table public.ifs_field_catalog n'est pas encore chargée
              (migrations 023 et 024 à exécuter sur le serveur).
            </Typography>
          </CardContent>
        </Card>
      )}

      {/* ─── Onglet 1 : Catalogue (entités → popup champs) ─── */}
      {!loading && tab === 0 && lots.length > 0 && (
        <>
          <Card sx={{ mb: 2 }}>
            <CardContent sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
              <TextField
                size="small"
                sx={{ flexGrow: 1, minWidth: 220 }}
                placeholder="Rechercher une entité..."
                value={entitySearch}
                onChange={(e) => setEntitySearch(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchIcon />
                    </InputAdornment>
                  ),
                }}
              />
              <FormControl size="small" sx={{ minWidth: 190 }}>
                <InputLabel id="theme-filter-label">Domaine métier</InputLabel>
                <Select
                  labelId="theme-filter-label"
                  value={themeFilter}
                  label="Domaine métier"
                  onChange={(e) => setThemeFilter(e.target.value)}
                >
                  <MenuItem value="">Tous les domaines</MenuItem>
                  {availableThemes.map((t) => (
                    <MenuItem key={t} value={t}>
                      <Box component="span" sx={{
                        display: 'inline-block', width: 10, height: 10, borderRadius: '50%',
                        bgcolor: themeColor(t), mr: 1,
                      }} />
                      {t}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              <Chip
                label="In scope seulement"
                color={inScopeOnly ? 'primary' : 'default'}
                variant={inScopeOnly ? 'filled' : 'outlined'}
                onClick={() => setInScopeOnly(!inScopeOnly)}
              />
              <Chip
                label="Obligatoires seulement"
                color={mandatoryOnly ? 'primary' : 'default'}
                variant={mandatoryOnly ? 'filled' : 'outlined'}
                onClick={() => setMandatoryOnly(!mandatoryOnly)}
              />
              <Typography variant="body2" color="text.secondary">
                {filteredEntities.length} entité(s)
              </Typography>
            </CardContent>
          </Card>

          <Paper>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    {showLotColumn && (
                      <TableCell width="10%" sortDirection={entitySort.field === 'lot_id' ? entitySort.dir : false}>
                        <TableSortLabel
                          active={entitySort.field === 'lot_id'}
                          direction={entitySort.field === 'lot_id' ? entitySort.dir : 'asc'}
                          onClick={() => handleSortEntities('lot_id')}
                        >
                          Lot
                        </TableSortLabel>
                      </TableCell>
                    )}
                    {([
                      ['entity', 'Entité', 'left'],
                      ['theme', 'Domaine métier', 'left'],
                      ['nb_fields', 'Champs', 'center'],
                      ['nb_in_scope', 'In scope / total', 'center'],
                      ['nb_mandatory', 'Obligatoires', 'center'],
                      ['nb_defaults', 'Défauts', 'center'],
                      ['nb_enums', 'Énumérations', 'center'],
                      ['nb_references', 'Références LOV', 'center'],
                      ['nb_pk', 'Clés', 'center'],
                    ] as [EntitySortField, string, 'left' | 'center'][]).map(([field, label, align]) => (
                      <TableCell
                        key={field}
                        align={align}
                        sortDirection={entitySort.field === field ? entitySort.dir : false}
                      >
                        <TableSortLabel
                          active={entitySort.field === field}
                          direction={entitySort.field === field ? entitySort.dir : 'asc'}
                          onClick={() => handleSortEntities(field)}
                        >
                          {label}
                        </TableSortLabel>
                      </TableCell>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filteredEntities.map((entity) => (
                    <TableRow
                      key={entityKey(entity)}
                      hover
                      onClick={() => handleOpenEntity(entity)}
                      sx={{ cursor: 'pointer' }}
                    >
                      {showLotColumn && (
                        <TableCell>
                          <Chip label={entity.lot_id} size="small" variant="outlined" />
                        </TableCell>
                      )}
                      <TableCell>
                        <Typography variant="body2" fontWeight="bold" sx={{ fontFamily: 'monospace' }}>
                          {entity.entity}
                        </Typography>
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={entity.theme}
                          size="small"
                          variant="outlined"
                          sx={{ color: themeColor(entity.theme), borderColor: themeColor(entity.theme) }}
                        />
                      </TableCell>
                      <TableCell align="center">{entity.nb_fields}</TableCell>
                      <TableCell align="center">{entity.nb_in_scope} / {entity.nb_fields}</TableCell>
                      <TableCell align="center">
                        {entity.nb_mandatory > 0
                          ? <Chip label={entity.nb_mandatory} size="small" color="error" variant="outlined" />
                          : '-'}
                      </TableCell>
                      <TableCell align="center">{entity.nb_defaults || '-'}</TableCell>
                      <TableCell align="center">{entity.nb_enums || '-'}</TableCell>
                      <TableCell align="center">{entity.nb_references || '-'}</TableCell>
                      <TableCell align="center">{entity.nb_pk || '-'}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </>
      )}

      {/* ─── Onglet 2 : Règles de gestion ─── */}
      {!loading && tab === 1 && lots.length > 0 && (
        <>
          <Card sx={{ mb: 2 }}>
            <CardContent sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
              <FormControl size="small" sx={{ minWidth: 200 }}>
                <InputLabel id="rule-entity-label">Entité</InputLabel>
                <Select
                  labelId="rule-entity-label"
                  value={ruleEntityFilter}
                  label="Entité"
                  onChange={(e) => setRuleEntityFilter(e.target.value)}
                >
                  <MenuItem value="">Toutes</MenuItem>
                  {entities.map((e) => (
                    <MenuItem key={e.entity} value={e.entity}>{e.entity}</MenuItem>
                  ))}
                </Select>
              </FormControl>
              <FormControl size="small" sx={{ minWidth: 220 }}>
                <InputLabel id="rule-type-label">Type de règle</InputLabel>
                <Select
                  labelId="rule-type-label"
                  value={ruleTypeFilter}
                  label="Type de règle"
                  onChange={(e) => setRuleTypeFilter(e.target.value)}
                >
                  <MenuItem value="">Toutes</MenuItem>
                  {(Object.keys(RULE_LABELS) as IfsCatalogRuleType[]).map((r) => (
                    <MenuItem key={r} value={r}>{RULE_LABELS[r]}</MenuItem>
                  ))}
                </Select>
              </FormControl>
              <Typography variant="body2" color="text.secondary">
                {filteredRules.length} règle(s)
              </Typography>
            </CardContent>
          </Card>

          <Paper>
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell width="20%">Entité</TableCell>
                    <TableCell width="25%">Champ</TableCell>
                    <TableCell width="20%">Règle</TableCell>
                    <TableCell width="35%">Détail</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {!rulesLoaded ? (
                    <TableRow>
                      <TableCell colSpan={4} align="center" sx={{ p: 3 }}>
                        <CircularProgress size={24} />
                      </TableCell>
                    </TableRow>
                  ) : filteredRules.map((rule, idx) => (
                    <TableRow key={`${rule.entity}-${rule.field}-${rule.rule}-${idx}`} hover>
                      <TableCell>
                        <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{rule.entity}</Typography>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{rule.field}</Typography>
                      </TableCell>
                      <TableCell>
                        <Chip label={RULE_LABELS[rule.rule]} size="small" color={RULE_COLORS[rule.rule]} variant="outlined" />
                      </TableCell>
                      <TableCell>
                        {rule.rule === 'DEFAULT' && <Chip label={rule.value} size="small" color="info" />}
                        {rule.rule === 'FK_LOGICAL' && (
                          <Typography variant="body2">→ {rule.target}</Typography>
                        )}
                        {rule.rule === 'ENUM_DB_VALUES' && (
                          <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                            {(rule.allowed || []).map((v) => (
                              <Chip key={v} label={v} size="small" variant="outlined" />
                            ))}
                          </Box>
                        )}
                        {rule.rule === 'NOT_NULL_ON_LOAD' && (
                          <Typography variant="body2" color="text.secondary">
                            Rejet si NULL au chargement
                          </Typography>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </>
      )}

      {/* ─── Onglet 3 : Statistiques ─── */}
      {!loading && tab === 2 && lots.length > 0 && (
        !stats ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Grid container spacing={2} sx={{ mb: 3 }}>
              {[
                { label: 'Entités', value: stats.nb_entities },
                { label: 'Champs', value: stats.nb_fields },
                { label: 'In scope', value: stats.nb_in_scope },
                { label: 'Obligatoires', value: stats.nb_mandatory },
                { label: 'Valeurs par défaut', value: stats.nb_defaults },
                { label: 'Références LOV', value: stats.nb_references },
                { label: 'Énumérations', value: stats.nb_enums },
                { label: 'Règles de transformation', value: stats.nb_transformations },
              ].map((s) => (
                <Grid item xs={6} sm={3} key={s.label}>
                  <Card>
                    <CardContent sx={{ textAlign: 'center' }}>
                      <Typography variant="h4" color="primary">{s.value}</Typography>
                      <Typography variant="body2" color="text.secondary">{s.label}</Typography>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>

            <Paper>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Entité</TableCell>
                      <TableCell align="center">Champs</TableCell>
                      <TableCell align="center">In scope / total</TableCell>
                      <TableCell align="center">Obligatoires</TableCell>
                      <TableCell align="center">Défauts</TableCell>
                      <TableCell align="center">Énumérations</TableCell>
                      <TableCell align="center">Références LOV</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {stats.per_entity.map((e) => (
                      <TableRow key={e.entity} hover>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{e.entity}</Typography>
                        </TableCell>
                        <TableCell align="center">{e.nb_fields}</TableCell>
                        <TableCell align="center">{e.nb_in_scope} / {e.nb_fields}</TableCell>
                        <TableCell align="center">{e.nb_mandatory}</TableCell>
                        <TableCell align="center">{e.nb_defaults}</TableCell>
                        <TableCell align="center">{e.nb_enums}</TableCell>
                        <TableCell align="center">{e.nb_references}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </Paper>
          </>
        )
      )}

      {/* ═══ Popup ENTITÉ : liste des champs (éditable) ═══ */}
      <Dialog
        open={!!openEntity}
        onClose={() => setOpenEntity(null)}
        maxWidth="lg"
        fullWidth
        PaperProps={{ sx: { borderRadius: 2, overflow: 'hidden' } }}
      >
        {openEntity && (
          <>
            <Box sx={{ height: 4, bgcolor: themeColor(openEntity.theme) }} />
            <DialogTitle sx={{ pb: 1.5 }}>
              <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2 }}>
                <Box sx={{ flexGrow: 1 }}>
                  <Typography variant="h6" component="div" sx={{ fontFamily: 'monospace', fontWeight: 700, letterSpacing: 0.5 }}>
                    {openEntity.entity}
                  </Typography>
                  <Stack direction="row" spacing={1} sx={{ mt: 1, flexWrap: 'wrap', gap: 0.5, alignItems: 'center' }}>
                    <Typography variant="caption" color="text.secondary">Domaine métier :</Typography>
                    <FormControl size="small" variant="standard" sx={{ minWidth: 140 }}>
                      <Select
                        value={DOMAIN_OPTIONS.includes(openEntity.theme ?? '') ? openEntity.theme : 'Autre'}
                        onChange={(e) => changeEntityTheme(e.target.value)}
                        disableUnderline
                        disabled={savingTheme}
                        renderValue={(v) => (
                          <Chip label={v} size="small" sx={{ color: '#fff', bgcolor: themeColor(v as string) }} />
                        )}
                      >
                        {DOMAIN_OPTIONS.map((d) => (
                          <MenuItem key={d} value={d}>
                            <Box component="span" sx={{
                              display: 'inline-block', width: 10, height: 10, borderRadius: '50%',
                              bgcolor: themeColor(d), mr: 1,
                            }} />
                            {d}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                    {savingTheme && <CircularProgress size={14} />}
                    {showLotColumn && <Chip label={openEntity.lot_id} size="small" variant="outlined" />}
                    {openAgg && (
                      <Typography variant="body2" color="text.secondary" sx={{ alignSelf: 'center', ml: 1 }}>
                        {openAgg.nb_fields} champs · {openAgg.nb_in_scope} in scope · {openAgg.nb_mandatory} obligatoire(s)
                      </Typography>
                    )}
                  </Stack>
                </Box>
                <IconButton onClick={() => setOpenEntity(null)} size="small">
                  <CloseIcon />
                </IconButton>
              </Box>
            </DialogTitle>
            <Divider />
            <DialogContent sx={{ pt: 2 }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5, flexWrap: 'wrap' }}>
                <TextField
                  size="small"
                  placeholder="Filtrer les champs (nom, libellé, commentaire...)"
                  value={fieldSearch}
                  onChange={(e) => setFieldSearch(e.target.value)}
                  sx={{ minWidth: 320, flexGrow: 1 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <SearchIcon fontSize="small" />
                      </InputAdornment>
                    ),
                  }}
                />
                <Chip
                  label="In scope"
                  size="small"
                  color={inScopeOnly ? 'primary' : 'default'}
                  variant={inScopeOnly ? 'filled' : 'outlined'}
                  onClick={() => setInScopeOnly(!inScopeOnly)}
                />
                <Chip
                  label="Obligatoires"
                  size="small"
                  color={mandatoryOnly ? 'primary' : 'default'}
                  variant={mandatoryOnly ? 'filled' : 'outlined'}
                  onClick={() => setMandatoryOnly(!mandatoryOnly)}
                />
              </Box>

              {openLoading ? (
                <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                  <CircularProgress size={28} />
                </Box>
              ) : openFields ? (
                <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: '60vh' }}>
                  <Table size="small" stickyHeader>
                    <TableHead>
                      <TableRow>
                        <TableCell width="4%">Ordre</TableCell>
                        <TableCell width="18%">Champ</TableCell>
                        <TableCell width="14%">Libellé</TableCell>
                        <TableCell width="12%">Type</TableCell>
                        <TableCell width="14%">Propriétés</TableCell>
                        <TableCell width="9%">Défaut</TableCell>
                        <TableCell width="11%">Réf. LOV</TableCell>
                        <TableCell width="14%">Énum. / Commentaire</TableCell>
                        <TableCell width="4%" align="right">Éditer</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {filterFields(openFields).map((field) => (
                        <TableRow
                          key={field.catalog_id}
                          hover
                          onClick={() => openFieldEditor(field)}
                          sx={{ cursor: 'pointer', ...(field.in_scope ? {} : { opacity: 0.5 }) }}
                        >
                          <TableCell>{field.sort_order ?? '-'}</TableCell>
                          <TableCell>
                            <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>
                              {field.field_name}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" fontSize="0.8rem">
                              {field.field_label_fr || '-'}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={field.data_length ? `${field.data_type}(${field.data_length})` : field.data_type || '-'}
                              size="small"
                              variant="outlined"
                            />
                            {field.sql_type && (
                              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', fontFamily: 'monospace', mt: 0.25 }}>
                                {field.sql_type}
                              </Typography>
                            )}
                          </TableCell>
                          <TableCell>
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                              {field.primary_key && (
                                <Tooltip title="Clé primaire">
                                  <KeyIcon fontSize="small" color="warning" />
                                </Tooltip>
                              )}
                              {field.mandatory && (
                                <Chip label="Obligatoire" size="small" color="error" variant="outlined" />
                              )}
                              {!field.in_scope && (
                                <Chip label="Hors scope" size="small" variant="outlined" />
                              )}
                              {!field.insertable && (
                                <Tooltip title="Non insérable (calculé par IFS)">
                                  <Chip label="Lecture seule" size="small" variant="outlined" />
                                </Tooltip>
                              )}
                            </Box>
                          </TableCell>
                          <TableCell>
                            {field.default_value
                              ? <Chip label={field.default_value} size="small" color="info" variant="outlined" />
                              : '-'}
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" fontSize="0.8rem">
                              {field.reference || '-'}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap', alignItems: 'center' }}>
                              {(field.enumeration_values || []).map((pair) => (
                                <Tooltip key={pair.db} title={`Valeur DB : ${pair.db}`}>
                                  <Chip label={`${pair.db} ⟺ ${pair.client}`} size="small" color="secondary" variant="outlined" />
                                </Tooltip>
                              ))}
                              {field.comments && field.comments !== 'vide' && (
                                <Tooltip title={field.comments}>
                                  <Typography
                                    variant="body2"
                                    fontSize="0.75rem"
                                    color="text.secondary"
                                    sx={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                                  >
                                    {field.comments}
                                  </Typography>
                                </Tooltip>
                              )}
                            </Box>
                          </TableCell>
                          <TableCell align="right">
                            <Tooltip title="Modifier ce champ">
                              <IconButton
                                size="small"
                                onClick={(e) => { e.stopPropagation(); openFieldEditor(field); }}
                              >
                                <EditIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              ) : null}
            </DialogContent>
          </>
        )}
      </Dialog>

      {/* ═══ Popup ÉDITION d'un champ ═══ */}
      <Dialog
        open={!!editField}
        onClose={() => (savingField ? null : setEditField(null))}
        maxWidth="sm"
        fullWidth
        PaperProps={{ sx: { borderRadius: 2, overflow: 'hidden' } }}
      >
        {editField && (
          <>
            <Box sx={{ height: 4, bgcolor: themeColor(openEntity?.theme) }} />
            <DialogTitle sx={{ pb: 1 }}>
              <Typography variant="subtitle1" sx={{ fontFamily: 'monospace', fontWeight: 700 }}>
                {editField.field_name}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {openEntity?.entity} · {editField.data_length ? `${editField.data_type}(${editField.data_length})` : editField.data_type} → {editField.sql_type}
              </Typography>
            </DialogTitle>
            <Divider />
            <DialogContent>
              {(editField.enumeration_values && editField.enumeration_values.length > 0) && (
                <Box sx={{ mb: 2 }}>
                  <Typography variant="caption" color="text.secondary">Énumérations (non éditables ici)</Typography>
                  <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap', mt: 0.5 }}>
                    {editField.enumeration_values.map((p) => (
                      <Chip key={p.db} label={`${p.db} ⟺ ${p.client}`} size="small" color="secondary" variant="outlined" />
                    ))}
                  </Box>
                </Box>
              )}

              <Stack spacing={2} sx={{ mt: 1 }}>
                <TextField
                  label="Libellé FR"
                  size="small"
                  fullWidth
                  value={editDraft.field_label_fr ?? ''}
                  onChange={(e) => setDraft('field_label_fr', e.target.value)}
                />
                <Box sx={{ display: 'flex', gap: 2 }}>
                  <TextField
                    label="Valeur par défaut"
                    size="small"
                    fullWidth
                    value={editDraft.default_value ?? ''}
                    onChange={(e) => setDraft('default_value', e.target.value)}
                  />
                  <TextField
                    label="Référence LOV"
                    size="small"
                    fullWidth
                    value={editDraft.reference ?? ''}
                    onChange={(e) => setDraft('reference', e.target.value)}
                  />
                </Box>
                <Box sx={{ display: 'flex', gap: 2 }}>
                  <TextField
                    label="Ordre"
                    size="small"
                    type="number"
                    fullWidth
                    value={editDraft.sort_order ?? ''}
                    onChange={(e) => setDraft('sort_order', e.target.value === '' ? null : Number(e.target.value))}
                  />
                  <TextField
                    label="Longueur"
                    size="small"
                    type="number"
                    fullWidth
                    value={editDraft.data_length ?? ''}
                    onChange={(e) => setDraft('data_length', e.target.value === '' ? null : Number(e.target.value))}
                  />
                </Box>

                <Divider textAlign="left">
                  <Typography variant="caption" color="text.secondary">Propriétés</Typography>
                </Divider>
                <Box sx={{ display: 'flex', flexWrap: 'wrap' }}>
                  {([
                    ['mandatory', 'Obligatoire'],
                    ['in_scope', 'In scope'],
                    ['insertable', 'Insérable'],
                    ['updatable', 'Modifiable'],
                    ['lov', 'LOV'],
                  ] as [keyof IfsCatalogField, string][]).map(([key, label]) => (
                    <FormControlLabel
                      key={key}
                      sx={{ width: '50%', m: 0 }}
                      control={
                        <Switch
                          size="small"
                          checked={Boolean(editDraft[key])}
                          onChange={(e) => setDraft(key, e.target.checked)}
                        />
                      }
                      label={<Typography variant="body2">{label}</Typography>}
                    />
                  ))}
                </Box>

                <TextField
                  label="Commentaire (mapping source→cible)"
                  size="small"
                  fullWidth
                  multiline
                  minRows={2}
                  value={editDraft.comments ?? ''}
                  onChange={(e) => setDraft('comments', e.target.value)}
                />
                <TextField
                  label="Règle de transformation"
                  size="small"
                  fullWidth
                  multiline
                  minRows={2}
                  value={editDraft.transformation_rules ?? ''}
                  onChange={(e) => setDraft('transformation_rules', e.target.value)}
                />

                {saveError && <Alert severity="error">{saveError}</Alert>}
              </Stack>
            </DialogContent>
            <DialogActions sx={{ px: 3, pb: 2 }}>
              <Button onClick={() => setEditField(null)} disabled={savingField} color="inherit">
                Annuler
              </Button>
              <Button
                onClick={saveField}
                variant="contained"
                disabled={savingField}
                startIcon={savingField ? <CircularProgress size={16} color="inherit" /> : undefined}
              >
                Enregistrer
              </Button>
            </DialogActions>
          </>
        )}
      </Dialog>
    </Box>
  );
};

export default IfsCatalog;
