import { useEffect, useRef } from 'react';
import { Box } from '@mui/material';
import { useTheme } from '@mui/material/styles';

// Sample data for the chart
const data = [
  { day: '01/04', records: 3500 },
  { day: '02/04', records: 4200 },
  { day: '03/04', records: 3800 },
  { day: '04/04', records: 5100 },
  { day: '05/04', records: 4700 },
  { day: '06/04', records: 6300 },
  { day: '07/04', records: 5800 },
  { day: '08/04', records: 7500 },
  { day: '09/04', records: 6900 },
  { day: '10/04', records: 8200 },
  { day: '11/04', records: 7600 },
  { day: '12/04', records: 9100 },
  { day: '13/04', records: 8700 },
  { day: '14/04', records: 9800 },
  { day: '15/04', records: 9200 },
];

const LineChart = () => {
  const theme = useTheme();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Calculate dimensions
    const width = canvas.width;
    const height = canvas.height;
    const padding = 40;
    const chartWidth = width - 2 * padding;
    const chartHeight = height - 2 * padding;
    
    // Find min/max values
    const maxRecords = Math.max(...data.map(d => d.records));
    const minRecords = Math.min(...data.map(d => d.records));
    const range = maxRecords - minRecords;
    
    // Draw axes
    ctx.beginPath();
    ctx.strokeStyle = theme.palette.divider;
    ctx.lineWidth = 1;
    ctx.moveTo(padding, padding);
    ctx.lineTo(padding, height - padding);
    ctx.lineTo(width - padding, height - padding);
    ctx.stroke();
    
    // Draw grid lines
    const gridLines = 5;
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = theme.palette.text.secondary;
    ctx.font = '10px Arial';
    
    for (let i = 0; i <= gridLines; i++) {
      const y = padding + (chartHeight * i) / gridLines;
      ctx.beginPath();
      ctx.moveTo(padding, height - y);
      ctx.lineTo(width - padding, height - y);
      ctx.setLineDash([3, 3]);
      ctx.strokeStyle = theme.palette.divider;
      ctx.stroke();
      ctx.setLineDash([]);
      
      // Y-axis labels
      const value = Math.round(minRecords + (range * i) / gridLines);
      ctx.fillText(value.toLocaleString(), padding - 5, height - y);
    }
    
    // Draw x-axis labels
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    
    data.forEach((d, i) => {
      const x = padding + (chartWidth * i) / (data.length - 1);
      if (i % 2 === 0) { // Only show every other label to avoid crowding
        ctx.fillText(d.day, x, height - padding + 5);
      }
    });
    
    // Draw line
    ctx.beginPath();
    ctx.strokeStyle = theme.palette.primary.main;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    
    data.forEach((d, i) => {
      const x = padding + (chartWidth * i) / (data.length - 1);
      const normalizedValue = (d.records - minRecords) / range;
      const y = height - padding - normalizedValue * chartHeight;
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    });
    
    ctx.stroke();
    
    // Draw area under the line
    ctx.lineTo(padding + chartWidth, height - padding);
    ctx.lineTo(padding, height - padding);
    ctx.closePath();
    ctx.fillStyle = `${theme.palette.primary.main}20`; // 20% opacity
    ctx.fill();
    
    // Draw data points
    data.forEach((d, i) => {
      const x = padding + (chartWidth * i) / (data.length - 1);
      const normalizedValue = (d.records - minRecords) / range;
      const y = height - padding - normalizedValue * chartHeight;
      
      ctx.beginPath();
      ctx.fillStyle = theme.palette.background.paper;
      ctx.strokeStyle = theme.palette.primary.main;
      ctx.lineWidth = 2;
      ctx.arc(x, y, 4, 0, 2 * Math.PI);
      ctx.fill();
      ctx.stroke();
    });
    
  }, [theme]);
  
  return (
    <Box sx={{ width: '100%', height: 300, position: 'relative' }}>
      <canvas
        ref={canvasRef}
        width={600}
        height={300}
        style={{ width: '100%', height: '100%' }}
      />
    </Box>
  );
};

export default LineChart; 