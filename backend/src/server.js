import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pg from 'pg';
import { randomUUID } from 'crypto';
import { createAdapter } from './adapters/index.js';

const { Pool } = pg;
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const publicBaseUrl = process.env.PUBLIC_BASE_URL || 'https://nodrix-app-production.up.railway.app';
const defaultCompanyId = process.env.DEFAULT_COMPANY_ID || 'demo-company';
const databaseUrl = process.env.DATABASE_URL || '';

let savedConfig = null;
let reminderSettings = {
  enabled: true,
  beforeHours: [72, 48, 24],
  messageTemplate:
    'عزيزي {name}، اشتراكك سينتهي بتاريخ {expiresAt}. يرجى التجديد لتجنب توقف الخدمة. الباقة: {package}',
};

const pool = databaseUrl
  ? new Pool({
      connectionString: databaseUrl,
      ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : false,
    })
  : null;

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use('/downloads', express.static('public/downloads'));

function id(prefix) {
  return `${prefix}_${randomUUID().replaceAll('-', '').slice(0, 18)}`;
}

function toInt(value, fallback = 0) {
  const n = Number(String(value ?? '').replaceAll(',', ''));
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function addDays(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function statusFromExpiry(expiresAt, savedStatus = 'active') {
  if (savedStatus === 'paused') return 'paused';
  if (!expiresAt) return savedStatus || 'active';
  const today = new Date(`${todayIso()}T00:00:00Z`);
  const exp = new Date(`${expiresAt}T00:00:00Z`);
  const diffDays = Math.ceil((exp.getTime() - today.getTime()) / 86400000);
  if (diffDays < 0) return 'expired';
  if (diffDays <= 3) return 'expires_soon';
  return 'active';
}

function normalizeCustomer(row) {
  if (!row) return null;
  const expiresAt = row.expires_at ? String(row.expires_at).slice(0, 10) : row.expiresAt;
  const startAt = row.start_at ? String(row.start_at).slice(0, 10) : row.startAt;
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    address: row.address || '',
    package: row.package_name || row.package || '',
    speed: row.speed || '',
    price: row.price ?? 0,
    startAt,
    expiresAt,
    status: statusFromExpiry(expiresAt, row.status),
    tower: row.tower || '',
    sector: row.sector || '',
    notes: row.notes || '',
    debt: row.debt ?? 0,
    companyId: row.company_id || row.companyId || defaultCompanyId,
  };
}

async function migrateDatabase() {
  if (!pool) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS companies (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      plan TEXT NOT NULL DEFAULT 'starter',
      subscription_status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      email TEXT,
      role TEXT NOT NULL DEFAULT 'owner',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS packages (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      speed TEXT,
      price INTEGER NOT NULL DEFAULT 0,
      days INTEGER NOT NULL DEFAULT 30,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      phone TEXT,
      address TEXT,
      package_name TEXT,
      speed TEXT,
      price INTEGER NOT NULL DEFAULT 0,
      start_at DATE,
      expires_at DATE,
      status TEXT NOT NULL DEFAULT 'active',
      tower TEXT,
      sector TEXT,
      notes TEXT,
      debt INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL DEFAULT 0,
      paid_at DATE NOT NULL DEFAULT CURRENT_DATE,
      expires_at DATE,
      note TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS towers (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      location TEXT,
      notes TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sectors (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      tower_id TEXT,
      name TEXT NOT NULL,
      ip_address TEXT,
      status TEXT NOT NULL DEFAULT 'offline',
      device_type TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS links (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      source TEXT,
      destination TEXT,
      ip_address TEXT,
      status TEXT NOT NULL DEFAULT 'offline',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(
    `INSERT INTO companies (id, name) VALUES ($1, $2) ON CONFLICT (id) DO NOTHING`,
    [defaultCompanyId, 'Nodrix Demo']
  );

  const customers = await pool.query('SELECT COUNT(*)::int AS count FROM customers WHERE company_id = $1', [defaultCompanyId]);
  if (customers.rows[0].count === 0) {
    await pool.query(
      `INSERT INTO packages (id, company_id, name, speed, price, days)
       VALUES ($1,$2,'باقة منزلي','25 Mbps',25000,30), ($3,$2,'باقة أعمال','50 Mbps',45000,30)
       ON CONFLICT (id) DO NOTHING`,
      [id('pkg'), defaultCompanyId, id('pkg')]
    );

    const seed = [
      ['cus_ali', 'علي حسن', '07700000001', 'باقة منزلي', '25 Mbps', 25000, addDays(21), 'برج الكرادة', 'Sector A', 0],
      ['cus_zainab', 'زينب محمد', '07700000002', 'باقة أعمال', '50 Mbps', 45000, addDays(2), 'برج المنصور', 'Sector B', 15000],
      ['cus_omar', 'عمر خالد', '07700000003', 'باقة منزلي', '25 Mbps', 25000, addDays(-4), 'برج الدورة', 'Sector C', 25000],
    ];
    for (const c of seed) {
      await pool.query(
        `INSERT INTO customers (id, company_id, name, phone, package_name, speed, price, start_at, expires_at, tower, sector, debt)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         ON CONFLICT (id) DO NOTHING`,
        [c[0], defaultCompanyId, c[1], c[2], c[3], c[4], c[5], todayIso(), c[6], c[7], c[8], c[9]]
      );
    }
  }
}

function getAdapterOrError(res) {
  if (!savedConfig) {
    res.status(400).json({ ok: false, message: 'SAS is not configured yet' });
    return null;
  }
  return createAdapter(savedConfig.type);
}

function fillTemplate(template, customer) {
  return template
    .replaceAll('{name}', customer.name ?? '')
    .replaceAll('{phone}', customer.phone ?? '')
    .replaceAll('{package}', customer.package ?? '')
    .replaceAll('{expiresAt}', customer.expiresAt ?? '');
}

function hoursUntil(dateText) {
  const target = new Date(`${dateText}T23:59:59`);
  const now = new Date();
  return Math.ceil((target.getTime() - now.getTime()) / (1000 * 60 * 60));
}

function shouldSendReminder(remainingHours, beforeHours) {
  return beforeHours.some((h) => remainingHours > 0 && remainingHours <= h);
}

async function dbCustomers() {
  const result = await pool.query(
    `SELECT * FROM customers WHERE company_id = $1 ORDER BY created_at DESC`,
    [defaultCompanyId]
  );
  return result.rows.map(normalizeCustomer);
}

async function dbCustomer(customerId) {
  const result = await pool.query('SELECT * FROM customers WHERE company_id = $1 AND id = $2', [defaultCompanyId, customerId]);
  return normalizeCustomer(result.rows[0]);
}

async function dbDashboard() {
  const customers = await dbCustomers();
  const paymentsToday = await pool.query(
    `SELECT COALESCE(SUM(amount),0)::int AS total FROM payments WHERE company_id = $1 AND paid_at = CURRENT_DATE`,
    [defaultCompanyId]
  );
  const paymentsMonth = await pool.query(
    `SELECT COALESCE(SUM(amount),0)::int AS total FROM payments
     WHERE company_id = $1 AND paid_at >= DATE_TRUNC('month', CURRENT_DATE)::date`,
    [defaultCompanyId]
  );
  return {
    ok: true,
    totalCustomers: customers.length,
    activeCustomers: customers.filter((c) => c.status === 'active').length,
    expiresSoon: customers.filter((c) => c.status === 'expires_soon').length,
    expiredCustomers: customers.filter((c) => c.status === 'expired').length,
    totalDebt: customers.reduce((sum, c) => sum + toInt(c.debt), 0),
    incomeToday: paymentsToday.rows[0].total,
    incomeMonth: paymentsMonth.rows[0].total,
    database: 'postgresql',
  };
}

async function dbAddCustomer(body) {
  const customerId = id('cus');
  const startAt = body.startAt || body.start_at || todayIso();
  const expiresAt = body.expiresAt || body.expires_at || addDays(30);
  const result = await pool.query(
    `INSERT INTO customers (id, company_id, name, phone, address, package_name, speed, price, start_at, expires_at, status, tower, sector, notes, debt)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
     RETURNING *`,
    [
      customerId,
      defaultCompanyId,
      body.name || 'مشترك جديد',
      body.phone || '',
      body.address || '',
      body.package || body.packageName || '',
      body.speed || '',
      toInt(body.price),
      startAt,
      expiresAt,
      body.status || 'active',
      body.tower || '',
      body.sector || '',
      body.notes || '',
      toInt(body.debt),
    ]
  );
  return { ok: true, message: 'تمت إضافة المشترك', customer: normalizeCustomer(result.rows[0]) };
}

async function dbUpdateCustomer(customerId, body) {
  const current = await dbCustomer(customerId);
  if (!current) return { ok: false, message: 'المشترك غير موجود' };
  const result = await pool.query(
    `UPDATE customers SET
      name=$3, phone=$4, address=$5, package_name=$6, speed=$7, price=$8,
      start_at=$9, expires_at=$10, status=$11, tower=$12, sector=$13, notes=$14, debt=$15,
      updated_at=NOW()
     WHERE company_id=$1 AND id=$2
     RETURNING *`,
    [
      defaultCompanyId,
      customerId,
      body.name ?? current.name,
      body.phone ?? current.phone,
      body.address ?? current.address,
      body.package ?? current.package,
      body.speed ?? current.speed,
      toInt(body.price ?? current.price),
      body.startAt ?? current.startAt,
      body.expiresAt ?? current.expiresAt,
      body.status ?? current.status,
      body.tower ?? current.tower,
      body.sector ?? current.sector,
      body.notes ?? current.notes,
      toInt(body.debt ?? current.debt),
    ]
  );
  return { ok: true, message: 'تم حفظ التعديل', customer: normalizeCustomer(result.rows[0]) };
}

async function dbPayments(customerId) {
  const result = await pool.query(
    `SELECT * FROM payments WHERE company_id=$1 AND customer_id=$2 ORDER BY created_at DESC`,
    [defaultCompanyId, customerId]
  );
  return result.rows.map((r) => ({
    id: r.id,
    amount: r.amount,
    date: String(r.paid_at).slice(0, 10),
    expiresAt: r.expires_at ? String(r.expires_at).slice(0, 10) : '',
    note: r.note || '',
  }));
}

async function dbAddPayment(customerId, body) {
  const customer = await dbCustomer(customerId);
  if (!customer) return { ok: false, message: 'المشترك غير موجود' };
  const paymentId = id('pay');
  const paidAt = body.date || body.paidAt || todayIso();
  const expiresAt = body.expiresAt || body.expires_at || customer.expiresAt;
  const amount = toInt(body.amount);
  await pool.query(
    `INSERT INTO payments (id, company_id, customer_id, amount, paid_at, expires_at, note)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [paymentId, defaultCompanyId, customerId, amount, paidAt, expiresAt || null, body.note || '']
  );
  await pool.query(
    `UPDATE customers SET expires_at=$3, debt=GREATEST(debt - $4, 0), updated_at=NOW()
     WHERE company_id=$1 AND id=$2`,
    [defaultCompanyId, customerId, expiresAt || null, amount]
  );
  return { ok: true, message: 'تم تسجيل الدفعة', paymentId };
}

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'Nodrix Backend', database: pool ? 'postgresql' : 'mock' });
});

app.get('/api/app-version', (req, res) => {
  const latestVersion = process.env.APP_LATEST_VERSION || '1.0.5';
  const apkUrl = process.env.APP_APK_URL || `${publicBaseUrl}/downloads/nodrix-latest.apk`;
  const notes =
    process.env.APP_UPDATE_NOTES ||
    'تحسين احترافي للواجهة، تصغير الأيقونات، تنظيم الأزرار، وربط PostgreSQL لحفظ المشتركين والدفعات.';

  res.json({
    ok: true,
    app: 'Nodrix',
    latestVersion,
    minSupportedVersion: process.env.APP_MIN_SUPPORTED_VERSION || '0.1.0',
    apkUrl,
    notes,
    updatedAt: new Date().toISOString(),
  });
});

app.post('/api/sas/test-connection', async (req, res) => {
  try {
    const { type, sasUrl, username, password } = req.body;
    if (type === 'postgres' || type === 'mock') {
      return res.json({ ok: true, message: pool ? 'تم الاتصال بقاعدة PostgreSQL' : 'تم الاتصال التجريبي' });
    }
    const adapter = createAdapter(type);
    const result = await adapter.login({ sasUrl, username, password });
    res.status(result.ok ? 200 : 401).json(result);
  } catch (error) {
    res.status(400).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/save', async (req, res) => {
  const { type, sasUrl, username, password } = req.body;
  savedConfig = { type, sasUrl, username, password };
  res.json({ ok: true, message: pool ? 'تم حفظ الإعدادات، البيانات محفوظة في PostgreSQL' : 'SAS config saved in memory for demo only' });
});

app.get('/api/dashboard', async (req, res) => {
  try {
    if (pool) return res.json(await dbDashboard());
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    res.json(await adapter.getDashboard());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/customers', async (req, res) => {
  try {
    if (pool) return res.json(await dbCustomers());
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    res.json(await adapter.getCustomers());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/customers/:id', async (req, res) => {
  try {
    if (pool) {
      const customer = await dbCustomer(req.params.id);
      if (!customer) return res.status(404).json({ ok: false, message: 'المشترك غير موجود' });
      return res.json({ ok: true, customer });
    }
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    const customer = await adapter.getCustomer(req.params.id);
    if (!customer) return res.status(404).json({ ok: false, message: 'المشترك غير موجود' });
    res.json({ ok: true, customer });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/customers', async (req, res) => {
  try {
    if (pool) return res.status(201).json(await dbAddCustomer(req.body));
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    const result = await adapter.addCustomer(req.body);
    res.status(result.ok ? 201 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.put('/api/customers/:id', async (req, res) => {
  try {
    if (pool) return res.json(await dbUpdateCustomer(req.params.id, req.body));
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    const result = await adapter.updateCustomer(req.params.id, req.body);
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/customers/:id/payments', async (req, res) => {
  try {
    if (pool) return res.json({ ok: true, payments: await dbPayments(req.params.id) });
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    res.json({ ok: true, payments: await adapter.getPayments(req.params.id) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/customers/:id/payments', async (req, res) => {
  try {
    if (pool) return res.status(201).json(await dbAddPayment(req.params.id, req.body));
    const adapter = getAdapterOrError(res);
    if (!adapter) return;
    const result = await adapter.addPayment(req.params.id, req.body);
    res.status(result.ok ? 201 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/sectors', async (req, res) => {
  const adapter = savedConfig ? createAdapter(savedConfig.type) : createAdapter('mock');
  res.json(await adapter.getSectors());
});

app.get('/api/links', async (req, res) => {
  const adapter = savedConfig ? createAdapter(savedConfig.type) : createAdapter('mock');
  res.json(await adapter.getLinks());
});

app.get('/api/reminders/settings', (req, res) => res.json(reminderSettings));

app.post('/api/reminders/settings', (req, res) => {
  const { enabled, beforeHours, messageTemplate } = req.body;
  reminderSettings = {
    enabled: Boolean(enabled),
    beforeHours: Array.isArray(beforeHours) ? beforeHours.map(Number).filter(Boolean) : [72, 48, 24],
    messageTemplate: messageTemplate || reminderSettings.messageTemplate,
  };
  res.json({ ok: true, settings: reminderSettings });
});

app.get('/api/reminders/preview', async (req, res) => {
  try {
    const customers = pool ? await dbCustomers() : await createAdapter(savedConfig?.type || 'mock').getCustomers();
    const reminders = customers
      .map((customer) => {
        const remainingHours = hoursUntil(customer.expiresAt);
        return {
          customerId: customer.id,
          name: customer.name,
          phone: customer.phone,
          package: customer.package,
          expiresAt: customer.expiresAt,
          remainingHours,
          shouldSend: reminderSettings.enabled && shouldSendReminder(remainingHours, reminderSettings.beforeHours),
          message: fillTemplate(reminderSettings.messageTemplate, customer),
        };
      })
      .filter((item) => item.shouldSend);
    res.json({ ok: true, count: reminders.length, reminders });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/reminders/send-demo', async (req, res) => {
  try {
    const customers = pool ? await dbCustomers() : await createAdapter(savedConfig?.type || 'mock').getCustomers();
    const sent = customers
      .map((customer) => {
        const remainingHours = hoursUntil(customer.expiresAt);
        return {
          customerId: customer.id,
          name: customer.name,
          phone: customer.phone,
          sent: reminderSettings.enabled && shouldSendReminder(remainingHours, reminderSettings.beforeHours),
          message: fillTemplate(reminderSettings.messageTemplate, customer),
        };
      })
      .filter((item) => item.sent);
    res.json({ ok: true, provider: 'demo-only', sentCount: sent.length, sent });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

migrateDatabase()
  .then(() => {
    app.listen(port, () => {
      console.log(`Nodrix backend running on http://localhost:${port}`);
      console.log(`Database: ${pool ? 'postgresql' : 'mock'}`);
    });
  })
  .catch((error) => {
    console.error('Failed to start Nodrix backend:', error);
    process.exit(1);
  });
