import { Box } from '@mui/material';
import { useTheme } from '@mui/material/styles';

interface ExtractionStatusChartProps {
  success: number;
  running: number;
  failed: number;
}

const ExtractionStatusChart = ({ success, running, failed }: ExtractionStatusChartProps) => {
  const theme = useTheme();
  const total = success + running + failed;
  
  // Calculate percentages
  const successPercent = Math.round((success / total) * 100);
  const runningPercent = Math.round((running / total) * 100);
  const failedPercent = Math.round((failed / total) * 100);
  
  // Donut chart styling
  const size = 150;
  const thickness = 20;
  const radius = (size - thickness) / 2;
  const circumference = 2 * Math.PI * radius;
  
  // Calculate arc lengths for each segment
  const successLength = (successPercent / 100) * circumference;
  const runningLength = (runningPercent / 100) * circumference;
  const failedLength = (failedPercent / 100) * circumference;
  
  // Calculate stroke dasharray and dashoffset for each arc
  const successDasharray = `${successLength} ${circumference - successLength}`;
  const runningDasharray = `${runningLength} ${circumference - runningLength}`;
  const failedDasharray = `${failedLength} ${circumference - failedLength}`;
  
  const successDashoffset = 0;
  const runningDashoffset = -successLength;
  const failedDashoffset = -(successLength + runningLength);
  
  return (
    <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2, mb: 1 }}>
      <Box sx={{ position: 'relative', width: size, height: size }}>
        {/* Background circle */}
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={theme.palette.background.paper}
            strokeWidth={thickness}
          />
          
          {/* Success segment */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={theme.palette.secondary.main}
            strokeWidth={thickness}
            strokeDasharray={successDasharray}
            strokeDashoffset={successDashoffset}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            style={{ transition: 'all 0.3s ease' }}
          />
          
          {/* Running segment */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={theme.palette.primary.main}
            strokeWidth={thickness}
            strokeDasharray={runningDasharray}
            strokeDashoffset={runningDashoffset}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            style={{ transition: 'all 0.3s ease' }}
          />
          
          {/* Failed segment */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={theme.palette.error.main}
            strokeWidth={thickness}
            strokeDasharray={failedDasharray}
            strokeDashoffset={failedDashoffset}
            transform={`rotate(-90 ${size / 2} ${size / 2})`}
            style={{ transition: 'all 0.3s ease' }}
          />
        </svg>
        
        {/* Center text */}
        <Box
          sx={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
          }}
        >
          <Box sx={{ 
            color: theme.palette.text.primary, 
            fontSize: '2rem', 
            fontWeight: 'bold',
            lineHeight: 1 
          }}>
            {total}
          </Box>
          <Box sx={{ 
            color: theme.palette.text.secondary, 
            fontSize: '0.75rem',
          }}>
            Total
          </Box>
        </Box>
      </Box>
    </Box>
  );
};

export default ExtractionStatusChart; 