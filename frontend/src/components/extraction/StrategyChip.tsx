import { Chip, Tooltip, Typography } from '@mui/material';

// Stratégie appliquée par l'API :8000 à une table (tablesDetails[].strategy) :
// "differentielle (<condition RFC>)" -> Delta, "complete (<raison>)" -> Complet,
// null -> table pas encore démarrée ou job antérieur au différentiel (2026-10).
export const strategyLabel = (strategy?: string | null) =>
  !strategy ? null : strategy.startsWith('differentielle') ? 'Delta' : 'Complet';

const StrategyChip = ({ strategy }: { strategy?: string | null }) => {
  const label = strategyLabel(strategy);
  if (!label) return <Typography variant="caption" color="text.secondary">-</Typography>;
  return (
    <Tooltip title={strategy}>
      <Chip
        size="small"
        variant="outlined"
        label={label}
        color={label === 'Delta' ? 'info' : 'warning'}
      />
    </Tooltip>
  );
};

export default StrategyChip;
