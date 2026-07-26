import {
    Check as CheckIcon,
    Code as CodeIcon,
    ContentCopy as CopyIcon,
    Download as DownloadIcon,
} from '@mui/icons-material';
import SearchIcon from '@mui/icons-material/Search';
import {
    Box,
    Button,
    Chip,
    IconButton,
    InputAdornment,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TableSortLabel,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useMemo, useState } from 'react';
import aiService from '../../services/aiService';

const MAX_TABLE_COLS = 30;

type Order = 'asc' | 'desc';

interface ResultsTableProps {
  colonnes: string[];
  lignes: Record<string, any>[];
  /** id du log : active les exports serveur (LIMIT élargi). */
  idLog?: number | null;
  /** SQL généré : active le bouton « Copier le SQL ». */
  sql?: string;
  maxHeight?: number;
}

// Compare deux valeurs en respectant le type (numérique vs texte).
function compareValues(a: any, b: any): number {
  if (a === null || a === undefined) return -1;
  if (b === null || b === undefined) return 1;
  const na = Number(a);
  const nb = Number(b);
  if (!Number.isNaN(na) && !Number.isNaN(nb) && a !== '' && b !== '') {
    return na - nb;
  }
  return String(a).localeCompare(String(b), 'fr', { numeric: true });
}

/**
 * Tableau de résultats générique et réutilisable : recherche plein texte, tri
 * par colonne, copie du tableau (TSV) et du SQL, exports CSV / Excel.
 */
const ResultsTable: React.FC<ResultsTableProps> = ({
  colonnes,
  lignes,
  idLog,
  sql,
  maxHeight = 420,
}) => {
  const [filtre, setFiltre] = useState('');
  const [orderBy, setOrderBy] = useState<string | null>(null);
  const [order, setOrder] = useState<Order>('asc');
  const [copie, setCopie] = useState<'' | 'table' | 'sql'>('');

  const cols = useMemo(() => colonnes.slice(0, MAX_TABLE_COLS), [colonnes]);

  // Filtrage plein texte (toutes colonnes), insensible à la casse.
  const lignesFiltrees = useMemo(() => {
    const q = filtre.trim().toLowerCase();
    if (!q) return lignes;
    return lignes.filter((row) =>
      cols.some((c) => {
        const v = row[c];
        return v !== null && v !== undefined && String(v).toLowerCase().includes(q);
      }),
    );
  }, [lignes, cols, filtre]);

  // Tri (sur la vue filtrée).
  const lignesAffichees = useMemo(() => {
    if (!orderBy) return lignesFiltrees;
    const copy = [...lignesFiltrees];
    copy.sort((r1, r2) => {
      const res = compareValues(r1[orderBy], r2[orderBy]);
      return order === 'asc' ? res : -res;
    });
    return copy;
  }, [lignesFiltrees, orderBy, order]);

  const handleSort = (col: string) => {
    if (orderBy === col) {
      setOrder((o) => (o === 'asc' ? 'desc' : 'asc'));
    } else {
      setOrderBy(col);
      setOrder('asc');
    }
  };

  const copierTable = async () => {
    const header = cols.join('\t');
    const corps = lignesAffichees
      .map((row) => cols.map((c) => (row[c] === null || row[c] === undefined ? '' : String(row[c]))).join('\t'))
      .join('\n');
    try {
      await navigator.clipboard.writeText(`${header}\n${corps}`);
      setCopie('table');
      setTimeout(() => setCopie(''), 1500);
    } catch {
      /* clipboard indisponible : on ignore */
    }
  };

  const copierSql = async () => {
    if (!sql) return;
    try {
      await navigator.clipboard.writeText(sql);
      setCopie('sql');
      setTimeout(() => setCopie(''), 1500);
    } catch {
      /* ignore */
    }
  };

  const exporter = async (format: 'csv' | 'xlsx') => {
    if (!idLog) return;
    try {
      await aiService.exportResult(idLog, format);
    } catch (e) {
      console.error(`Export ${format} échoué`, e);
    }
  };

  return (
    <Box sx={{ mt: 1 }}>
      {/* Barre d'outils : recherche + actions */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1, flexWrap: 'wrap' }}>
        <TextField
          size="small"
          placeholder="Filtrer les résultats…"
          value={filtre}
          onChange={(e) => setFiltre(e.target.value)}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
          sx={{ minWidth: 220 }}
        />
        <Chip
          size="small"
          variant="outlined"
          label={
            filtre
              ? `${lignesAffichees.length} / ${lignes.length} ligne(s)`
              : `${lignes.length} ligne(s)`
          }
        />
        <Box sx={{ flexGrow: 1 }} />
        <Tooltip title="Copier le tableau">
          <IconButton size="small" onClick={copierTable}>
            {copie === 'table' ? <CheckIcon fontSize="small" color="success" /> : <CopyIcon fontSize="small" />}
          </IconButton>
        </Tooltip>
        {sql && (
          <Tooltip title="Copier le SQL">
            <IconButton size="small" onClick={copierSql}>
              {copie === 'sql' ? <CheckIcon fontSize="small" color="success" /> : <CodeIcon fontSize="small" />}
            </IconButton>
          </Tooltip>
        )}
        {idLog ? (
          <>
            <Button size="small" startIcon={<DownloadIcon />} onClick={() => exporter('csv')}>
              CSV
            </Button>
            <Button size="small" startIcon={<DownloadIcon />} onClick={() => exporter('xlsx')}>
              Excel
            </Button>
          </>
        ) : null}
      </Box>

      <TableContainer component={Paper} variant="outlined" sx={{ maxHeight }}>
        <Table size="small" stickyHeader>
          <TableHead>
            <TableRow>
              {cols.map((c) => (
                <TableCell key={c} sx={{ fontWeight: 700, whiteSpace: 'nowrap' }}>
                  <TableSortLabel
                    active={orderBy === c}
                    direction={orderBy === c ? order : 'asc'}
                    onClick={() => handleSort(c)}
                  >
                    {c}
                  </TableSortLabel>
                </TableCell>
              ))}
            </TableRow>
          </TableHead>
          <TableBody>
            {lignesAffichees.map((row, i) => (
              <TableRow key={i} hover>
                {cols.map((c) => (
                  <TableCell key={c}>
                    {row[c] === null || row[c] === undefined ? '' : String(row[c])}
                  </TableCell>
                ))}
              </TableRow>
            ))}
            {!lignesAffichees.length && (
              <TableRow>
                <TableCell colSpan={cols.length || 1}>
                  <Typography variant="body2" color="text.secondary" sx={{ p: 1 }}>
                    Aucune ligne ne correspond au filtre.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>
      {colonnes.length > MAX_TABLE_COLS && (
        <Typography variant="caption" color="text.secondary">
          {colonnes.length - MAX_TABLE_COLS} colonne(s) masquée(s) — utilisez l'export pour tout voir.
        </Typography>
      )}
    </Box>
  );
};

export default ResultsTable;
