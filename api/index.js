// === Arquivo: api/index.js ===
import express from 'express';
import sqlite3 from 'sqlite3';
import cors from 'cors';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const swaggerDocument = YAML.load(path.join(__dirname, 'swagger.yaml'));

const app = express();
const PORT = process.env.PORT || 3000;
const API_TOKEN = process.env.API_AUTH_TOKEN || 'default-token';

app.use(cors());
app.use(express.json());

// Middleware de log
app.use((req, res, next) => {
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  console.log(`📥 ${req.method} ${req.originalUrl} | IP: ${ip}`);
  if (req.method !== 'GET') console.log(`📨 Payload:`, req.body);
  next();
});

// Middleware de autenticação apenas para /api/*
app.use('/api', (req, res, next) => {
  const tokenRecebido = req.headers['authorization'];
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  // Logs de debug
  console.log(`🔍 TOKEN esperado: Bearer ${API_TOKEN}`);
  console.log(`📥 Authorization recebido:`, tokenRecebido || '[nenhum]');

  if (!tokenRecebido) {
    console.log(`🔒 Rejeitado: sem token | IP: ${ip}`);
    return res.status(401).json({ error: 'Token ausente no header Authorization' });
  }

  if (tokenRecebido !== `Bearer ${API_TOKEN}`) {
    console.log(`🔒 Rejeitado: token inválido | IP: ${ip}`);
    return res.status(403).json({ error: 'Token inválido' });
  }

  next();
});

// Swagger UI em / (sem proteção)
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Inicializa o banco SQLite
const db = new sqlite3.Database('./comments.db', (err) => {
  if (err) return console.error(err.message);
  console.log('📦 Banco de dados SQLite conectado.');
});

db.run(`CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL,
  comment TEXT NOT NULL,
  content_id INTEGER NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)`);

// POST /api/comment/new
app.post('/api/comment/new', (req, res) => {
  const { email, comment, content_id } = req.body;
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  if (!email || !comment) {
    const errMsg = 'Campos obrigatórios: email, comment';
    console.log(`❌ POST /api/comment/new | IP: ${ip} | ${errMsg}`);
    return res.status(400).json({ error: errMsg });
  }

  if (content_id) {
    const stmt = db.prepare(`INSERT INTO comments (email, comment, content_id) VALUES (?, ?, ?)`);
    stmt.run(email, comment, content_id, function (err) {
      if (err) {
        console.log(`❌ ERRO SQL | ${err.message}`);
        return res.status(500).json({ error: err.message });
      }
      const msg = `Comentário adicionado ao ID ${content_id}`;
      console.log(`✅ POST /api/comment/new | IP: ${ip} | ${msg}`);
      res.status(201).json({ message: msg });
    });
  } else {
    db.get(`SELECT MAX(content_id) as max FROM comments`, (err, row) => {
      if (err) {
        console.log(`❌ ERRO SQL | ${err.message}`);
        return res.status(500).json({ error: err.message });
      }
      const newContentId = (row?.max || 0) + 1;
      const stmt = db.prepare(`INSERT INTO comments (email, comment, content_id) VALUES (?, ?, ?)`);
      stmt.run(email, comment, newContentId, function (err) {
        if (err) {
          console.log(`❌ ERRO SQL | ${err.message}`);
          return res.status(500).json({ error: err.message });
        }
        const msg = `Novo ID gerado ${newContentId}`;
        console.log(`✅ POST /api/comment/new | IP: ${ip} | ${msg}`);
        res.status(201).json({ message: msg });
      });
    });
  }
});

// GET /api/comment/list/:content_id
app.get('/api/comment/list/:content_id', (req, res) => {
  const { content_id } = req.params;
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  db.all(`SELECT * FROM comments WHERE content_id = ? ORDER BY created_at ASC`, [content_id], (err, rows) => {
    if (err) {
      console.log(`❌ GET /api/comment/list/${content_id} | IP: ${ip} | ERRO: ${err.message}`);
      return res.status(500).json({ error: err.message });
    }
    console.log(`📄 GET /api/comment/list/${content_id} | IP: ${ip} | ${rows.length} comentários retornados`);
    res.json(rows);
  });
});

app.listen(PORT, () => {
  console.log(`🚀 API rodando na porta ${PORT}`);
});
