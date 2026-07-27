import { createTheme } from '@mui/material/styles';

export const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#4d8bf0', // Blue similar to the dashboard image
    },
    secondary: {
      main: '#6dd48c', // Green for positive indicators
    },
    error: {
      main: '#f44336', // Red for negative values
    },
    background: {
      default: '#1e2738', // Dark blue background
      paper: '#2c3649',   // Slightly lighter card background
    },
    text: {
      primary: '#ffffff',
      secondary: '#b0b8c8',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
    h4: {
      fontWeight: 500,
      letterSpacing: '0.01em',
      textTransform: 'uppercase',
    },
    h6: {
      fontWeight: 500,
      fontSize: '1rem',
      letterSpacing: '0.1em',
      textTransform: 'uppercase',
    },
  },
  components: {
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          boxShadow: '0 4px 20px 0 rgba(0,0,0,0.2)',
          backgroundColor: '#2c3649',
        },
      },
    },
    MuiCardHeader: {
      styleOverrides: {
        root: {
          padding: '16px 24px',
        },
      },
    },
    MuiCardContent: {
      styleOverrides: {
        root: {
          padding: '16px 24px',
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'uppercase',
          fontWeight: 500,
          borderRadius: 4,
        },
        contained: {
          boxShadow: 'none',
        },
      },
    },
    // ── Tableaux « console de données » ──────────────────────────────────
    // Densité, zébrage, hover et en-tête sticky définis ICI une fois pour
    // toutes : les 45 fichiers de tableaux en héritent sans modification.
    MuiTable: {
      defaultProps: {
        size: 'small', // densité globale (~34px/ligne au lieu de ~53px)
      },
      styleOverrides: {
        root: {
          backgroundColor: '#2c3649',
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          padding: '6px 12px',
        },
        head: {
          fontWeight: 600,
          fontSize: '0.72rem',
          textTransform: 'uppercase',
          letterSpacing: '0.06em',
          whiteSpace: 'nowrap',
          color: '#b0b8c8',
          // Fond OPAQUE obligatoire : avec stickyHeader, les lignes défilent
          // sous l'en-tête ; un fond translucide les laisserait transparaître.
          backgroundColor: '#1e2738',
          borderBottom: '1px solid rgba(255, 255, 255, 0.14)',
        },
        body: {
          borderBottom: '1px solid rgba(255, 255, 255, 0.06)',
        },
      },
    },
    // Zébrage/hover portés par MuiTableBody et non MuiTableRow : une règle sur
    // MuiTableRow s'appliquerait aussi aux lignes du thead.
    MuiTableBody: {
      styleOverrides: {
        root: {
          '& .MuiTableRow-root:nth-of-type(even)': {
            backgroundColor: 'rgba(255, 255, 255, 0.025)',
          },
          // Déclaré après le zébrage pour gagner à spécificité égale.
          '& .MuiTableRow-root:hover': {
            backgroundColor: 'rgba(77, 139, 240, 0.08)',
          },
          '& .MuiTableRow-root.Mui-selected': {
            backgroundColor: 'rgba(77, 139, 240, 0.16)',
          },
          '& .MuiTableRow-root.Mui-selected:hover': {
            backgroundColor: 'rgba(77, 139, 240, 0.22)',
          },
        },
      },
    },
    MuiTablePagination: {
      styleOverrides: {
        root: {
          borderTop: '1px solid rgba(255, 255, 255, 0.08)',
        },
        toolbar: {
          minHeight: 44,
        },
      },
    },
  },
}); 