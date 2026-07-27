/**
 * Contrat de la DataTable partagee.
 *
 * Parti pris : la DataTable ne trie JAMAIS et ne decoupe JAMAIS les donnees.
 * Tri, pagination et recherche sont pilotes par la page (le plus souvent cote
 * serveur). Les pages qui disposent deja de tout le jeu de donnees font leur
 * tri/slice en `useMemo` et passent le resultat — le composant reste ainsi une
 * couche de PRESENTATION, sans etat metier cache.
 */
import type { ReactNode } from 'react';

/** Chiffres et codes : chasse fixe systeme, alignes en colonnes. */
export const MONO = '"SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace';

export interface DataTableColumn<T> {
  /** Identifiant unique ; sert d'accesseur par defaut (row[key]). */
  key: string;
  /** Libelle affiche dans l'en-tete (en francais). */
  label: string;
  /** Largeur minimale de la colonne. */
  width?: number | string;
  align?: 'left' | 'center' | 'right';
  /** Rend la valeur en chasse fixe a chiffres tabulaires (codes, quantites). */
  mono?: boolean;
  /** Affiche une fleche de tri (le tri lui-meme est fait par la page). */
  sortable?: boolean;
  /** Rendu personnalise ; par defaut String(row[key]) ou un tiret cadratin. */
  render?: (row: T) => ReactNode;
  /** Tronque a cette largeur avec des points de suspension (+ title au survol). */
  ellipsisMaxWidth?: number;
  /** Colonne masquee au premier affichage (menu « Colonnes »). */
  defaultHidden?: boolean;
  /** Valeur a exporter en CSV si differente de l'affichage. */
  csvValue?: (row: T) => string;
}

export interface DataTablePagination {
  /** Index de page a partir de 0 (convention TablePagination). */
  page: number;
  pageSize: number;
  /** Nombre total de lignes ; -1 si inconnu. */
  total: number;
  onPageChange: (page: number) => void;
  onPageSizeChange: (pageSize: number) => void;
  pageSizeOptions?: number[];
}

export interface DataTableSearchOptions {
  onChange: (query: string) => void;
  placeholder?: string;
  /** Delai avant de propager la saisie (defaut 300 ms). */
  debounceMs?: number;
  /** Valeur initiale du champ. */
  initialValue?: string;
}

export interface DataTableToolbarOptions {
  search?: DataTableSearchOptions;
  /** Menu de selection des colonnes visibles. */
  columnVisibility?: boolean;
  /** Export CSV de la page courante (colonnes visibles). */
  csvExport?: boolean | { filePrefix: string };
  /** Boutons libres, alignes a droite. */
  actions?: ReactNode;
}

export type SortDirection = 'asc' | 'desc';

export interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  rows: T[];
  getRowKey: (row: T, index: number) => string | number;

  loading?: boolean;
  /** Nombre de lignes fantomes pendant le chargement initial. */
  skeletonRows?: number;
  emptyLabel?: string;

  sortBy?: string;
  sortDir?: SortDirection;
  onSortChange?: (key: string, direction: SortDirection) => void;

  /** Omis => aucune barre de pagination. */
  pagination?: DataTablePagination;
  /** Omis => aucune barre d'outils. */
  toolbar?: DataTableToolbarOptions;

  onRowClick?: (row: T) => void;
  selectedRowKey?: string | number | null;

  /**
   * Hauteur maximale du conteneur. Omise, le tableau occupe la place
   * disponible (flex:1) — a utiliser dans un parent en colonne flex.
   */
  maxHeight?: number | string;
  /** Force une largeur minimale : le defilement horizontal se fait DANS le tableau. */
  minTableWidth?: number;
  /** Style applique au Paper englobant. */
  sx?: object;
}
