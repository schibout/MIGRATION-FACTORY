import { useTheme } from '@mui/material/styles';
import { Box } from '@mui/material';

interface DataQualityChartProps {
  quality: number;
}

const DataQualityChart = ({ quality }: DataQualityChartProps) => {
  const theme = useTheme();
  
  // Semi-circular gauge styling
  const size = 180;
  const thickness = 15;
  const radius = (size - thickness) / 2;
  const semicircleCircumference = Math.PI * radius;
  
  // Calculate the arc length for the filled portion
  const filledLength = (quality / 100) * semicircleCircumference;
  
  // Calculate stroke dasharray and dashoffset
  const dasharray = `${filledLength} ${semicircleCircumference - filledLength}`;
  
  // Determine color based on quality score
  let color = theme.palette.error.main; // Red for low quality
  if (quality >= 70) {
    color = theme.palette.secondary.main; // Green for high quality
  } else if (quality >= 40) {
    color = theme.palette.warning.main; // Orange/Yellow for medium quality
  }
  
  return (
    <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2, position: 'relative' }}>
      <svg width={size} height={size / 2 + thickness} viewBox={`0 0 ${size} ${size / 2 + thickness}`}>
        {/* Background semi-circle */}
        <path
          d={`M ${thickness / 2}, ${size / 2} 
              A ${radius}, ${radius} 0 0 1 ${size - thickness / 2}, ${size / 2}`}
          fill="none"
          stroke={theme.palette.background.paper}
          strokeWidth={thickness}
          strokeLinecap="round"
        />
        
        {/* Filled semi-circle */}
        <path
          d={`M ${thickness / 2}, ${size / 2} 
              A ${radius}, ${radius} 0 0 1 ${size - thickness / 2}, ${size / 2}`}
          fill="none"
          stroke={color}
          strokeWidth={thickness}
          strokeDasharray={dasharray}
          strokeLinecap="round"
          style={{ transition: 'all 0.3s ease' }}
        />
        
        {/* Marks for gauge */}
        {[0, 25, 50, 75, 100].map((mark) => {
          const angle = (mark / 100) * Math.PI;
          const x = size / 2 + Math.cos(angle) * (radius + thickness / 2);
          const y = size / 2 - Math.sin(angle) * (radius + thickness / 2);
          
          return (
            <g key={mark}>
              <line
                x1={size / 2}
                y1={size / 2}
                x2={x}
                y2={y}
                stroke={theme.palette.text.secondary}
                strokeWidth={1}
                strokeOpacity={0.3}
              />
              <text
                x={x}
                y={y + 15}
                textAnchor="middle"
                fontSize="10"
                fill={theme.palette.text.secondary}
              >
                {mark}%
              </text>
            </g>
          );
        })}
        
        {/* Needle */}
        {(() => {
          const angle = (quality / 100) * Math.PI;
          const needleLength = radius + thickness;
          const x = size / 2 + Math.cos(angle) * needleLength;
          const y = size / 2 - Math.sin(angle) * needleLength;
          
          return (
            <>
              <line
                x1={size / 2}
                y1={size / 2}
                x2={x}
                y2={y}
                stroke={theme.palette.text.primary}
                strokeWidth={2}
                strokeLinecap="round"
              />
              <circle
                cx={size / 2}
                cy={size / 2}
                r={thickness / 2}
                fill={theme.palette.text.primary}
              />
            </>
          );
        })()}
      </svg>
      
      {/* Center text */}
      <Box
        sx={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          textAlign: 'center',
          mb: 1,
        }}
      >
        <Box sx={{ fontSize: '2.5rem', fontWeight: 'bold', lineHeight: 1, color }}>
          {quality}%
        </Box>
        <Box sx={{ fontSize: '0.75rem', color: theme.palette.text.secondary }}>
          Qualité Globale
        </Box>
      </Box>
    </Box>
  );
};

export default DataQualityChart; 