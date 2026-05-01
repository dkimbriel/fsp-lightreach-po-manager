import React, { useRef, useEffect } from 'react';
import {
  Box,
  Paper,
  Typography,
  List,
  ListItem,
  ListItemText,
} from '@mui/material';

const LOG_COLORS = {
  info: '#1976d2',
  success: '#2e7d32',
  warning: '#ed6c02',
  error: '#d32f2f',
};

export default function LogViewer({ logs }) {
  const logEndRef = useRef(null);

  useEffect(() => {
    // Auto-scroll to bottom when new logs arrive
    logEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  if (!logs || logs.length === 0) {
    return (
      <Paper sx={{ p: 2, bgcolor: '#f5f5f5' }}>
        <Typography variant="body2" color="text.secondary">
          No logs yet...
        </Typography>
      </Paper>
    );
  }

  return (
    <Paper
      sx={{
        bgcolor: '#1e1e1e',
        color: '#fff',
        maxHeight: 400,
        overflow: 'auto',
        fontFamily: 'monospace',
      }}
    >
      <List dense disablePadding>
        {logs.map((log, index) => (
          <ListItem
            key={index}
            sx={{
              py: 0.5,
              px: 2,
              borderLeft: `3px solid ${LOG_COLORS[log.level] || LOG_COLORS.info}`,
              '&:hover': { bgcolor: 'rgba(255,255,255,0.05)' },
            }}
          >
            <ListItemText
              primary={
                <Box component="span" display="flex" gap={2}>
                  <Typography
                    component="span"
                    variant="body2"
                    sx={{ color: '#888', minWidth: 60 }}
                  >
                    {log.timestamp}
                  </Typography>
                  <Typography
                    component="span"
                    variant="body2"
                    sx={{
                      color: LOG_COLORS[log.level] || LOG_COLORS.info,
                      minWidth: 60,
                      fontWeight: 'bold',
                      textTransform: 'uppercase',
                    }}
                  >
                    {log.level}
                  </Typography>
                  <Typography
                    component="span"
                    variant="body2"
                    sx={{ color: '#fff', flex: 1 }}
                  >
                    {log.message}
                  </Typography>
                </Box>
              }
            />
          </ListItem>
        ))}
        <div ref={logEndRef} />
      </List>
    </Paper>
  );
}
