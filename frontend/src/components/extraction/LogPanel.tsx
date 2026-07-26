import { Box, Chip, Stack, Typography } from '@mui/material';
import { format } from 'date-fns';
import { ExtractionLog } from '../../services/extractionService';

interface LogPanelProps {
  logs: ExtractionLog[];
  live?: boolean;
  height?: number;
  title?: string;
}

const levelColor = (level?: string) => {
  switch ((level || '').toUpperCase()) {
    case 'ERROR': return 'error.main';
    case 'WARNING': case 'WARN': return 'warning.main';
    case 'SUCCESS': return 'success.main';
    default: return 'text.primary';
  }
};

const fmtTime = (ts?: string) => {
  if (!ts) return '';
  if (isNaN(Date.parse(ts))) return ts;
  return format(new Date(ts), 'HH:mm:ss');
};

/** Journal d'exécution — même rendu que la page /data-loading. */
const LogPanel = ({ logs, live = false, height = 300, title = "Journal d'exécution" }: LogPanelProps) => (
  <Box>
    <Typography variant="h6" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
      {title}
      {live && <Chip label="live" color="primary" size="small" sx={{ height: 20, fontSize: '0.65rem' }} />}
    </Typography>
    <Box sx={{ height, overflowY: 'auto', bgcolor: 'background.default', p: 2, borderRadius: 1 }}>
      <Stack spacing={1}>
        {logs.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ fontStyle: 'italic' }}>
            Aucune activité à afficher.
          </Typography>
        ) : (
          logs.map((log, i) => (
            <Box key={i} sx={{ display: 'flex', alignItems: 'flex-start' }}>
              <Typography variant="caption" sx={{ color: 'text.secondary', mr: 1, minWidth: 60 }}>
                [{fmtTime(log.timestamp)}]
              </Typography>
              <Typography variant="body2" sx={{ color: levelColor(log.level), whiteSpace: 'pre-wrap' }}>
                {log.message}
              </Typography>
            </Box>
          ))
        )}
      </Stack>
    </Box>
  </Box>
);

export default LogPanel;
