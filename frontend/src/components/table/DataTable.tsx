/**
 * Tableau de données partagé — style « console de données ».
 *
 * Reprend le meilleur de l'existant : la mise en page d'EquipmentPage (Paper en
 * colonne flex, conteneur qui prend la place restante, en-tete fige, pagination
 * epinglee en bas, labels FR) et la barre d'outils de SapDataTable (recherche
 * debouncee, colonnes masquables, export CSV).
 *
 * Principes :
 *   - densite : lignes compactes (heritees du theme) pour balayer beaucoup de
 *     lignes sans scroller ;
 *   - les grandeurs et les codes sont en chasse fixe a chiffres tabulaires
 *     (`mono`) : les colonnes s'alignent et se comparent d'un regard ;
 *   - le chargement affiche des lignes fantomes de la bonne hauteur, pas un
 *     spinner qui fait sauter la mise en page ;
 *   - le defilement horizontal se fait DANS le tableau (`minTableWidth`), pas
 *     en poussant la page.
 *
 * Le composant ne trie ni ne pagine lui-meme : voir types.ts.
 */
import {
  Box,
  LinearProgress,
  Paper,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TableSortLabel,
  Typography,
} from '@mui/material';
import { useCallback, useMemo, useState } from 'react';

import DataTableToolbar from './DataTableToolbar';
import { downloadCsv } from './csv';
import { MONO } from './types';
import type { DataTableColumn, DataTableProps, SortDirection } from './types';

const DEFAULT_PAGE_SIZES = [10, 25, 50, 100];

function DataTable<T>({
  columns,
  rows,
  getRowKey,
  loading = false,
  skeletonRows,
  emptyLabel = 'Aucune donnée',
  sortBy,
  sortDir = 'asc',
  onSortChange,
  pagination,
  toolbar,
  onRowClick,
  selectedRowKey = null,
  maxHeight,
  minTableWidth,
  sx,
}: DataTableProps<T>) {
  const [hiddenKeys, setHiddenKeys] = useState<string[]>(() =>
    columns.filter((c) => c.defaultHidden).map((c) => c.key),
  );

  const visibleColumns = useMemo(
    () => columns.filter((c) => !hiddenKeys.includes(c.key)),
    [columns, hiddenKeys],
  );

  const toggleColumn = useCallback((key: string) => {
    setHiddenKeys((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key],
    );
  }, []);

  const handleSort = (column: DataTableColumn<T>) => {
    if (!column.sortable || !onSortChange) return;
    const nextDir: SortDirection =
      sortBy === column.key && sortDir === 'asc' ? 'desc' : 'asc';
    onSortChange(column.key, nextDir);
  };

  const handleExport = useCallback(() => {
    const prefix =
      typeof toolbar?.csvExport === 'object' ? toolbar.csvExport.filePrefix : 'export';
    downloadCsv(visibleColumns, rows, prefix);
  }, [toolbar, visibleColumns, rows]);

  const renderCellContent = (column: DataTableColumn<T>, row: T) => {
    if (column.render) return column.render(row);
    const raw = (row as Record<string, unknown>)[column.key];
    return raw === null || raw === undefined || raw === '' ? '—' : String(raw);
  };

  const cellSx = (column: DataTableColumn<T>) => ({
    ...(column.width ? { minWidth: column.width } : {}),
    ...(column.mono ? { fontFamily: MONO, fontVariantNumeric: 'tabular-nums' } : {}),
    ...(column.ellipsisMaxWidth
      ? {
          maxWidth: column.ellipsisMaxWidth,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }
      : {}),
  });

  // Lignes fantomes : autant que la page en contiendra, pour que le tableau ne
  // change pas de hauteur quand les donnees arrivent.
  const ghostRows = skeletonRows ?? pagination?.pageSize ?? 8;
  const showSkeleton = loading && rows.length === 0;
  const showRefetchBar = loading && rows.length > 0;

  return (
    <Paper
      elevation={0}
      sx={{
        display: 'flex',
        flexDirection: 'column',
        minHeight: 0,
        ...(maxHeight ? {} : { flex: 1 }),
        border: 1,
        borderColor: 'divider',
        borderRadius: 2,
        overflow: 'hidden',
        ...sx,
      }}
    >
      {toolbar && (
        <DataTableToolbar
          options={toolbar}
          columns={columns}
          hiddenKeys={hiddenKeys}
          onToggleColumn={toggleColumn}
          onExportCsv={handleExport}
        />
      )}

      {/* Barre fine pendant un rechargement : les lignes restent lisibles. */}
      <Box sx={{ height: 2 }}>{showRefetchBar && <LinearProgress sx={{ height: 2 }} />}</Box>

      <TableContainer
        sx={{
          flex: maxHeight ? undefined : 1,
          minHeight: 0,
          maxHeight,
          overflowX: 'auto',
        }}
      >
        <Table stickyHeader sx={minTableWidth ? { minWidth: minTableWidth } : undefined}>
          <TableHead>
            <TableRow>
              {visibleColumns.map((column) => (
                <TableCell
                  key={column.key}
                  align={column.align ?? 'left'}
                  sortDirection={sortBy === column.key ? sortDir : false}
                  sx={column.width ? { minWidth: column.width } : undefined}
                >
                  {column.sortable && onSortChange ? (
                    <TableSortLabel
                      active={sortBy === column.key}
                      direction={sortBy === column.key ? sortDir : 'asc'}
                      onClick={() => handleSort(column)}
                    >
                      {column.label}
                    </TableSortLabel>
                  ) : (
                    column.label
                  )}
                </TableCell>
              ))}
            </TableRow>
          </TableHead>

          <TableBody>
            {showSkeleton &&
              Array.from({ length: ghostRows }).map((_, rowIndex) => (
                <TableRow key={`skeleton-${rowIndex}`}>
                  {visibleColumns.map((column) => (
                    <TableCell key={column.key}>
                      <Skeleton variant="text" width={column.mono ? '60%' : '85%'} />
                    </TableCell>
                  ))}
                </TableRow>
              ))}

            {!showSkeleton && rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={visibleColumns.length} align="center" sx={{ py: 5 }}>
                  <Typography variant="body2" color="text.secondary">
                    {emptyLabel}
                  </Typography>
                </TableCell>
              </TableRow>
            )}

            {!showSkeleton &&
              rows.map((row, index) => {
                const key = getRowKey(row, index);
                return (
                  <TableRow
                    key={key}
                    hover={!!onRowClick}
                    selected={selectedRowKey !== null && selectedRowKey === key}
                    onClick={onRowClick ? () => onRowClick(row) : undefined}
                    sx={onRowClick ? { cursor: 'pointer' } : undefined}
                  >
                    {visibleColumns.map((column) => {
                      const content = renderCellContent(column, row);
                      return (
                        <TableCell
                          key={column.key}
                          align={column.align ?? 'left'}
                          sx={cellSx(column)}
                          // Valeur complete au survol quand elle est tronquee.
                          title={
                            column.ellipsisMaxWidth && typeof content === 'string'
                              ? content
                              : undefined
                          }
                        >
                          {content}
                        </TableCell>
                      );
                    })}
                  </TableRow>
                );
              })}
          </TableBody>
        </Table>
      </TableContainer>

      {pagination && (
        <TablePagination
          component="div"
          count={pagination.total}
          page={pagination.page}
          rowsPerPage={pagination.pageSize}
          rowsPerPageOptions={pagination.pageSizeOptions ?? DEFAULT_PAGE_SIZES}
          onPageChange={(_, page) => pagination.onPageChange(page)}
          onRowsPerPageChange={(e) => {
            pagination.onPageSizeChange(parseInt(e.target.value, 10));
            pagination.onPageChange(0);
          }}
          labelRowsPerPage="Lignes par page :"
          labelDisplayedRows={({ from, to, count }) =>
            `${from.toLocaleString('fr-FR')}–${to.toLocaleString('fr-FR')} sur ${
              count === -1 ? `plus de ${to.toLocaleString('fr-FR')}` : count.toLocaleString('fr-FR')
            }`
          }
        />
      )}
    </Paper>
  );
}

export default DataTable;
