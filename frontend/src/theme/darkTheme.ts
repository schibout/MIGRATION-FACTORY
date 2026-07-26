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
    MuiTable: {
      styleOverrides: {
        root: {
          backgroundColor: '#2c3649',
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        head: {
          fontWeight: 600,
          color: '#ffffff',
          backgroundColor: '#1e2738',
        },
        body: {
          borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
        },
      },
    },
  },
}); 