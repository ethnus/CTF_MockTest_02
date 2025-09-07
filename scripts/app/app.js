const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Main application endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Ethnus Mock Test 02 - Container Orchestration!',
    service: 'webapp',
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0'
  });
});

// API endpoints
app.get('/api/info', (req, res) => {
  res.json({
    service: 'webapp',
    description: 'Mock Test 02 - Container Orchestration & Service Discovery',
    features: [
      'ECS Fargate',
      'Application Load Balancer',
      'Service Discovery',
      'Auto Scaling',
      'CloudWatch Monitoring'
    ]
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
