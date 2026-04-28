const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_ENV = process.env.APP_ENV || 'local';
const APP_VERSION = process.env.APP_VERSION || 'dev';

app.use(express.static(path.join(__dirname, 'public')));

// Healthcheck para o ECS / ALB
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', env: APP_ENV, version: APP_VERSION });
});

// "API" mínima de produtos
app.get('/api/products', (_req, res) => {
  res.json([
    { id: 1, name: 'Mechanical Keyboard', price: 499.9 },
    { id: 2, name: '4K Monitor', price: 2199.0 },
    { id: 3, name: 'Noise Cancelling Headphones', price: 1299.5 }
  ]);
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`[products-app] listening on :${PORT} env=${APP_ENV} version=${APP_VERSION}`);
});
