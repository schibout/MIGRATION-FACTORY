/**
 * Export CSV des lignes affichees.
 *
 * Separateur point-virgule et BOM UTF-8 : c'est ce qu'attend Excel en config
 * francaise (sans le BOM, les accents sont illisibles ; avec la virgule, tout
 * atterrit dans une seule colonne).
 */
import type { DataTableColumn } from './types';

const escapeCell = (value: unknown): string => {
  if (value === null || value === undefined) return '';
  const text = String(value);
  // Guillemets, separateur ou saut de ligne -> on encadre et on double les guillemets.
  return /[";\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

/** Valeur brute d'une cellule pour l'export (ignore le rendu React). */
const cellValue = <T,>(column: DataTableColumn<T>, row: T): string => {
  if (column.csvValue) return column.csvValue(row);
  const raw = (row as Record<string, unknown>)[column.key];
  return raw === null || raw === undefined ? '' : String(raw);
};

export const buildCsv = <T,>(columns: DataTableColumn<T>[], rows: T[]): string => {
  const header = columns.map((c) => escapeCell(c.label)).join(';');
  const body = rows.map((row) => columns.map((c) => escapeCell(cellValue(c, row))).join(';'));
  return [header, ...body].join('\r\n');
};

/** Declenche le telechargement du CSV dans le navigateur. */
export const downloadCsv = <T,>(
  columns: DataTableColumn<T>[],
  rows: T[],
  filePrefix = 'export',
): void => {
  const csv = buildCsv(columns, rows);
  const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
  // ﻿ = BOM UTF-8, indispensable pour Excel.
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${filePrefix}_${stamp}.csv`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
};
