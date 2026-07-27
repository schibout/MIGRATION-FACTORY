/**
 * Barre d'outils de la DataTable : recherche debouncee, menu de colonnes,
 * export CSV, et un emplacement libre pour les actions de la page.
 *
 * Ne s'affiche que si au moins une option est demandee.
 */
import {
  Box,
  Checkbox,
  Divider,
  IconButton,
  InputAdornment,
  ListItemText,
  Menu,
  MenuItem,
  TextField,
  Tooltip,
} from '@mui/material';
import ClearIcon from '@mui/icons-material/Close';
import DownloadIcon from '@mui/icons-material/FileDownload';
import SearchIcon from '@mui/icons-material/Search';
import ViewColumnIcon from '@mui/icons-material/ViewColumn';
import { useEffect, useRef, useState } from 'react';

import type { DataTableColumn, DataTableToolbarOptions } from './types';

interface Props<T> {
  options: DataTableToolbarOptions;
  columns: DataTableColumn<T>[];
  hiddenKeys: string[];
  onToggleColumn: (key: string) => void;
  onExportCsv: () => void;
}

function DataTableToolbar<T>({
  options,
  columns,
  hiddenKeys,
  onToggleColumn,
  onExportCsv,
}: Props<T>) {
  const { search, columnVisibility, csvExport, actions } = options;
  const [query, setQuery] = useState(search?.initialValue ?? '');
  const [menuAnchor, setMenuAnchor] = useState<null | HTMLElement>(null);
  const onChangeRef = useRef(search?.onChange);

  useEffect(() => {
    onChangeRef.current = search?.onChange;
  }, [search?.onChange]);

  // Debounce : evite une requete serveur a chaque frappe.
  useEffect(() => {
    if (!search) return undefined;
    const delay = search.debounceMs ?? 300;
    const timer = setTimeout(() => onChangeRef.current?.(query), delay);
    return () => clearTimeout(timer);
  }, [query, search]);

  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 1,
        px: 1.5,
        py: 1,
        borderBottom: 1,
        borderColor: 'divider',
        flexWrap: 'wrap',
      }}
    >
      {search && (
        <TextField
          size="small"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={search.placeholder ?? 'Rechercher…'}
          sx={{ flex: '1 1 260px', maxWidth: 420 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
            endAdornment: query ? (
              <InputAdornment position="end">
                <IconButton size="small" onClick={() => setQuery('')} aria-label="Effacer">
                  <ClearIcon fontSize="small" />
                </IconButton>
              </InputAdornment>
            ) : undefined,
          }}
        />
      )}

      <Box sx={{ flex: 1 }} />

      {actions}

      {columnVisibility && (
        <>
          <Tooltip title="Colonnes affichées">
            <IconButton size="small" onClick={(e) => setMenuAnchor(e.currentTarget)}>
              <ViewColumnIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Menu
            anchorEl={menuAnchor}
            open={Boolean(menuAnchor)}
            onClose={() => setMenuAnchor(null)}
            slotProps={{ paper: { sx: { maxHeight: 380 } } }}
          >
            {columns.map((column) => (
              <MenuItem
                key={column.key}
                dense
                onClick={() => onToggleColumn(column.key)}
              >
                <Checkbox
                  size="small"
                  checked={!hiddenKeys.includes(column.key)}
                  sx={{ p: 0.5, mr: 1 }}
                />
                <ListItemText primaryTypographyProps={{ variant: 'body2' }}>
                  {column.label}
                </ListItemText>
              </MenuItem>
            ))}
          </Menu>
        </>
      )}

      {csvExport && (
        <>
          {columnVisibility && <Divider orientation="vertical" flexItem sx={{ mx: 0.5 }} />}
          <Tooltip title="Exporter la page affichée en CSV">
            <IconButton size="small" onClick={onExportCsv}>
              <DownloadIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </>
      )}
    </Box>
  );
}

export default DataTableToolbar;
