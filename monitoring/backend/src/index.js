const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');

const PORT = Number(process.env.PORT) || 8080;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/robotevents';

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

let db;
let events;
let client;

async function connectMongo() {
  client = new MongoClient(MONGODB_URI);
  await client.connect();
  db = client.db();
  events = db.collection('events');
  await events.createIndex({ createdAt: -1 });
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, mongo: Boolean(events) });
});

app.post('/api/events', async (req, res) => {
  if (!events) {
    return res.status(503).json({ ok: false, error: 'Base de datos no disponible' });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const doc = {
    type: String(body.type || 'unknown'),
    source: body.source != null ? String(body.source) : null,
    action: body.action != null ? String(body.action) : null,
    success: typeof body.success === 'boolean' ? body.success : null,
    detail: body.detail != null ? String(body.detail) : null,
    payload: body.payload && typeof body.payload === 'object' ? body.payload : null,
    createdAt: new Date(),
  };

  try {
    const r = await events.insertOne(doc);
    return res.status(201).json({ ok: true, id: String(r.insertedId) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ ok: false, error: 'No se pudo guardar el evento' });
  }
});

app.get('/api/events', async (req, res) => {
  if (!events) {
    return res.status(503).json({ ok: false, error: 'Base de datos no disponible' });
  }

  const limit = Math.min(Math.max(Number(req.query.limit) || 100, 1), 500);

  try {
    const list = await events
      .find({})
      .sort({ createdAt: -1 })
      .limit(limit)
      .toArray();

    return res.json({ ok: true, events: list });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ ok: false, error: 'No se pudo leer el log' });
  }
});

async function main() {
  await connectMongo();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend escuchando en :${PORT}`);
  });
}

main().catch((err) => {
  console.error('Fallo al iniciar:', err);
  process.exit(1);
});
