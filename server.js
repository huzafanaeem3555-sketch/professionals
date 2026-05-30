process.noDeprecation = process.env.NODE_NO_DEPRECATION !== 'false';

require('dotenv').config();
const app = require('./src/app');

const PORT = process.env.PORT || 3000;

// ✅ ADD ROOT ROUTE HERE (Before app.listen)
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Service Connect API is running on Railway!',
    version: '1.0.0',
    status: 'online',
    endpoints: {
      search: '/api/search?q=plumber',
      suggestions: '/api/search/suggest?q=ele',
      professionals: '/api/professionals',
      health: '/health'
    },
    timestamp: new Date().toISOString()
  });
});

// ✅ Add health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 URL: http://localhost:${PORT}`);
});