import React from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Button,
  Chip,
  Link,
  Box,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import PlayArrowIcon from '@mui/icons-material/PlayArrow';

export default function ProjectList({ projects, onGenerateSingle }) {
  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString();
  };

  if (projects.length === 0) {
    return (
      <Paper sx={{ p: 3, textAlign: 'center' }}>
        <p>No projects scheduled for this region.</p>
      </Paper>
    );
  }

  // Sort projects by job_start date ascending
  const sortedProjects = [...projects].sort((a, b) => {
    if (!a.job_start) return 1;
    if (!b.job_start) return -1;
    return new Date(a.job_start) - new Date(b.job_start);
  });

  return (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Project ID</TableCell>
            <TableCell>Project Name</TableCell>
            <TableCell>Loan App ID</TableCell>
            <TableCell>System Size</TableCell>
            <TableCell>Job Start</TableCell>
            <TableCell>PO Status</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {sortedProjects.map((project) => (
            <TableRow key={project.id} hover>
              <TableCell>
                <Link
                  href={`https://sunrise.gofreedompower.com/residential/projects/${project.id}/pulse`}
                  target="_blank"
                  rel="noopener noreferrer"
                  sx={{ color: 'primary.main' }}
                >
                  {project.id}
                </Link>
              </TableCell>
              <TableCell>{project.name}</TableCell>
              <TableCell>
                {project.loan_application_id ? (
                  <Link
                    href={`https://palmetto.finance/accounts/${project.loan_application_id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    sx={{ color: 'primary.main' }}
                  >
                    {project.loan_application_id}
                  </Link>
                ) : (
                  'N/A'
                )}
              </TableCell>
              <TableCell>{project.system_size || 'N/A'}</TableCell>
              <TableCell>{formatDate(project.job_start)}</TableCell>
              <TableCell>
                {project.has_po ? (
                  <Chip
                    icon={<CheckCircleIcon />}
                    label={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                        Has PO - Open in Netsuite
                        <OpenInNewIcon sx={{ fontSize: '0.875rem' }} />
                      </Box>
                    }
                    color="success"
                    size="small"
                    component={Link}
                    href={project.po_link}
                    target="_blank"
                    clickable
                  />
                ) : (
                  <Chip label="No PO" color="default" size="small" />
                )}
              </TableCell>
              <TableCell align="right">
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<PlayArrowIcon />}
                  onClick={() => onGenerateSingle(project.id)}
                >
                  {project.has_po ? 'Send PO to CED' : 'Generate PO & Send to CED'}
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
