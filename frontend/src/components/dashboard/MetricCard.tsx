import { Box, Typography } from '@mui/material';
import { ArrowUpward, ArrowDownward } from '@mui/icons-material';

interface MetricCardProps {
  title: string;
  value: string;
  change?: number;
  unit?: string;
  suffix?: string;
}

const MetricCard = ({ title, value, change = 0, unit = '', suffix = '' }: MetricCardProps) => {
  return (
    <Box
      sx={{
        bgcolor: 'background.paper',
        p: 1.5,
        borderRadius: 1,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <Typography variant="body2" color="text.secondary" gutterBottom>
        {title}
      </Typography>
      <Box sx={{ display: 'flex', alignItems: 'baseline', mb: 0.5 }}>
        <Typography
          variant="h6"
          component="div"
          sx={{ fontWeight: 700, lineHeight: 1.2 }}
        >
          {value}
          {unit && <span style={{ fontSize: '0.8em' }}>{unit}</span>}
          {suffix && <span style={{ fontSize: '0.7em', marginLeft: '2px' }}>{suffix}</span>}
        </Typography>
      </Box>
      {change !== 0 && (
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            color: change > 0 ? 'success.main' : 'error.main',
            fontSize: '0.75rem',
          }}
        >
          {change > 0 ? (
            <ArrowUpward fontSize="inherit" sx={{ mr: 0.5 }} />
          ) : (
            <ArrowDownward fontSize="inherit" sx={{ mr: 0.5 }} />
          )}
          <span>{Math.abs(change)}%</span>
        </Box>
      )}
    </Box>
  );
};

export default MetricCard; 