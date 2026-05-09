import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pg from 'pg';
import { randomUUID, createHash, randomBytes, createCipheriv, createDecipheriv } from 'crypto';
import { createAdapter } from './adapters/index.js';

const { Pool } = pg;
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const publicBaseUrl = process.env.PUBLIC_BASE_URL || 'https://nodrix-app-production.up.railway.app';
const defaultCompanyId = process.env.DEFAULT_COMPANY_ID || 'demo-company';
const UNIQUEFI_AES_PASSPHRASE = 'abcdefghijuklmno0123456789012345';
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
app.use(express.json({ limit: '8mb' }));
app.use('/downloads', express.static('public/downloads'));

function id(prefix) {
  return `${prefix}_${randomUUID().replaceAll('-', '').slice(0, 18)}`;
}


function normalizeBaseUrl(value) {
  const raw = String(value || '').trim().replace(/\/+$/, '');
  if (!raw) return '';
  return raw.startsWith('http://') || raw.startsWith('https://') ? raw : `https://${raw}`;
}

function uniqueFiApiBase(baseUrl) {
  return `${normalizeBaseUrl(baseUrl)}/admin/api/index.php/api/`;
}

function evpBytesToKey(password, salt, keyLen = 32, ivLen = 16) {
  let data = Buffer.alloc(0);
  let prev = Buffer.alloc(0);
  while (data.length < keyLen + ivLen) {
    prev = createHash('md5').update(Buffer.concat([prev, Buffer.from(password, 'utf8'), salt])).digest();
    data = Buffer.concat([data, prev]);
  }
  return { key: data.subarray(0, keyLen), iv: data.subarray(keyLen, keyLen + ivLen) };
}

function cryptoJsAesEncrypt(obj) {
  const salt = randomBytes(8);
  const { key, iv } = evpBytesToKey(UNIQUEFI_AES_PASSPHRASE, salt);
  const cipher = createCipheriv('aes-256-cbc', key, iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(obj), 'utf8'), cipher.final()]);
  return Buffer.concat([Buffer.from('Salted__'), salt, encrypted]).toString('base64');
}

function appSecretKey() {
  return createHash('sha256').update(process.env.APP_SECRET || databaseUrl || 'nodrix-local-secret').digest();
}

function encryptSecret(value) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', appSecretKey(), iv);
  const encrypted = Buffer.concat([cipher.update(String(value || ''), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

function decryptSecret(value) {
  if (!value) return '';
  try {
    const raw = Buffer.from(value, 'base64');
    const iv = raw.subarray(0, 12);
    const tag = raw.subarray(12, 28);
    const encrypted = raw.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', appSecretKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  } catch (_) {
    return '';
  }
}

function uniqueFiBrowserHeaders(baseUrl, token = '') {
  const normalized = normalizeBaseUrl(baseUrl);
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/plain, */*',
    Origin: normalized,
    Referer: `${normalized}/`,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': 'Windows',
  };
  if (token) headers.authorization = `Bearer ${token}`;
  return headers;
}

async function postJson(url, body, headers = {}) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/plain, */*', ...headers },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : {}; } catch (_) { data = { raw: text }; }
  if (!response.ok) {
    const msg = data?.message || data?.error || data?.raw || `HTTP ${response.status}`;
    const err = new Error(String(msg).slice(0, 500));
    err.status = response.status;
    err.url = url;
    err.data = data;
    err.bodyPreview = String(text || '').slice(0, 800);
    throw err;
  }
  return data;
}

async function uniqueFiEncryptedPost(baseUrl, endpoint, payload, token = '') {
  const url = `${uniqueFiApiBase(baseUrl)}${endpoint}`;
  return postJson(url, { payload: cryptoJsAesEncrypt(payload) }, uniqueFiBrowserHeaders(baseUrl, token));
}

function extractSasToken(data) {
  return data?.token || data?.access_token || data?.data?.token || data?.data?.access_token || '';
}

function safeSasError(prefix, error) {
  const status = error?.status ? `HTTP ${error.status}` : '';
  const body = error?.data?.message || error?.data?.error || error?.bodyPreview || error?.message || '';
  const isCloudflare = /cloudflare|cf-|attention required|just a moment|forbidden/i.test(String(body));
  if (isCloudflare) return `${prefix}: Cloudflare/Firewall ${status}`.trim();
  return `${prefix}: ${status || ''} ${String(body).slice(0, 220)}`.trim();
}

async function uniqueFiLoadPublicConfig(baseUrl) {
  try {
    const r = await fetch(`${uniqueFiApiBase(baseUrl)}resources/login`, { headers: uniqueFiBrowserHeaders(baseUrl) });
    const text = await r.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (_) { data = { raw: text }; }
    return { ok: r.ok, status: r.status, data, blocked: !r.ok };
  } catch (error) {
    return { ok: false, status: null, error: error.message, blocked: true };
  }
}

async function uniqueFiLogin({ sasUrl, username, password, language = 'en' }) {
  const baseUrl = normalizeBaseUrl(sasUrl);
  if (!baseUrl || !username || !password) return { ok: false, message: 'الرابط واليوزر والباسورد مطلوبة' };

  // Do not fail when resources/login is blocked by Cloudflare.
  // The SAS frontend only uses it to read public UI settings; the real login is POST /login.
  const resources = await uniqueFiLoadPublicConfig(baseUrl);
  const resolvedLanguage = language || resources?.data?.data?.site_language || 'en';

  const loginPayload = {
    username,
    password,
    language: resolvedLanguage,
    otp: null,
    captcha_text: null,
    session_id: randomUUID(),
  };
  try {
    const login = await uniqueFiEncryptedPost(baseUrl, 'login', loginPayload);
    const token = extractSasToken(login);
    if (!token || login.status !== 200) {
      return {
        ok: false,
        message: login?.message || 'فشل تسجيل الدخول إلى SAS',
        responseStatus: login?.status,
        phase: 'login',
        resourcesStatus: resources?.status || null,
      };
    }
    return {
      ok: true,
      token,
      site: resources?.data?.data?.site?.title || 'SAS Radius',
      language: loginPayload.language,
      resourcesStatus: resources?.status || null,
      resourcesBlocked: Boolean(resources?.blocked),
    };
  } catch (error) {
    return {
      ok: false,
      message: safeSasError('فشل تسجيل الدخول إلى SAS', error),
      responseStatus: error.status,
      phase: 'login',
      resourcesStatus: resources?.status || null,
      resourcesBlocked: Boolean(resources?.blocked),
    };
  }
}

function userIndexPayload(page = 1, rowsPerPage = 10) {
  // Keep this payload identical to the SAS Radius users table request.
  // Important: the original Angular table sends page/count/direction/sortBy/search/columns only;
  // no rowsPerPage and no ?page= query string. Some SAS builds reject extra fields.
  return {
    page,
    count: rowsPerPage,
    direction: 'asc',
    sortBy: 'username',
    search: '',
    columns: ['idx', 'username', 'firstname', 'lastname', 'expiration', 'parent_username', 'name', 'loan_balance', 'traffic', 'remaining_days', 'static_ip', 'ip', 'ip_address', 'framed_ip_address'],
  };
}

async function uniqueFiFetchUsers(config) {
  let token = String(config?.token || '').trim();
  let tokenSource = token ? 'browser' : 'login';
  if (!token) {
    const login = await uniqueFiLogin(config);
    if (!login.ok) return { ok: false, message: login.message, phase: login.phase || 'login' };
    token = login.token;
  }
  const all = [];
  let lastPage = 1;
  let total = 0;
  try {
    for (let page = 1; page <= lastPage && page <= 200; page++) {
      const response = await uniqueFiEncryptedPost(config.sasUrl, 'index/user', userIndexPayload(page, 10), token);
      const rows = Array.isArray(response?.data) ? response.data : [];
      all.push(...rows);
      lastPage = Number(response?.last_page || lastPage || 1);
      total = Number(response?.total || total || all.length);
      if (!response?.next_page_url && page >= lastPage) break;
    }
  } catch (error) {
    const expired = error?.status === 401 || error?.status === 403;
    const extra = tokenSource === 'browser' && expired ? ' — الجلسة المحفوظة قد تكون منتهية. أعد تسجيل الدخول عبر المتصفح.' : '';
    return { ok: false, message: `${safeSasError('فشل جلب المستخدمين من SAS', error)}${extra}`, phase: 'users', status: error.status };
  }
  return { ok: true, users: all, total, pages: lastPage, syncedAt: new Date().toISOString(), tokenSource };
}

function bytesToGb(value) {
  const n = Number(value || 0);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.round((n / 1024 / 1024 / 1024) * 100) / 100;
}

function firstText(...values) {
  for (const value of values) {
    const text = String(value ?? '').trim();
    if (text && text !== 'null' && text !== 'undefined' && text !== '—') return text;
  }
  return '';
}

function extractUniqueFiIp(user) {
  return firstText(
    user?.static_ip,
    user?.ip,
    user?.ip_address,
    user?.framed_ip_address,
    user?.framed_ip,
    user?.current_ip,
    user?.last_ip,
    user?.ipv4,
    user?.static_ip_details?.ip,
    user?.static_ip_details?.static_ip,
    user?.online_info?.ip,
    user?.connection_details?.ip,
    user?.status?.ip
  );
}

function mapUniqueFiStatus(user) {
  if (Number(user?.enabled) !== 1) return 'paused';
  if (user?.status?.expiration === false) return 'expired';
  if (Number(user?.remaining_days) <= 0) return 'expired';
  if (Number(user?.remaining_days) <= 3) return 'expires_soon';
  return 'active';
}

function mapUniqueFiUser(user) {
  const first = String(user?.firstname || '').trim();
  const last = String(user?.lastname || '').trim();
  const fullName = `${first} ${last}`.trim() || String(user?.username || 'مشترك SAS');
  const traffic = user?.daily_traffic_details?.traffic || 0;
  return {
    sasId: String(user?.id || user?.username || ''),
    sasUsername: String(user?.username || ''),
    name: fullName,
    phone: user?.phone || '',
    package: user?.profile_details?.name || '',
    status: mapUniqueFiStatus(user),
    expiresAt: cleanDate(user?.expiration),
    expiryRaw: user?.expiration || '',
    lastOnline: user?.last_online || null,
    parentUsername: user?.parent_username || '',
    debtDays: toInt(user?.debt_days),
    remainingDays: toInt(user?.remaining_days),
    onlineStatus: toInt(user?.online_status),
    dailyTrafficGb: bytesToGb(traffic),
    staticIp: extractUniqueFiIp(user),
  };
}

function toInt(value, fallback = 0) {
  const n = Number(String(value ?? '').replaceAll(',', ''));
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function baghdadDateIso(date = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Baghdad', year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
}

function addDays(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

function cleanDate(value) {
  if (value === undefined || value === null) return null;
  const raw = String(value).trim();
  if (!raw || raw === '—' || raw.toLowerCase() === 'invalid date') return null;
  const iso = raw.match(/^(\d{4}-\d{2}-\d{2})/);
  if (iso) return iso[1];
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

function displayDate(value, fallback = '') {
  return cleanDate(value) || fallback;
}

function statusFromExpiry(expiresAt, savedStatus = 'active') {
  if (savedStatus === 'paused') return 'paused';
  const clean = cleanDate(expiresAt);
  if (!clean) return savedStatus || 'unknown';
  const today = new Date(`${baghdadDateIso()}T00:00:00Z`);
  const exp = new Date(`${clean}T00:00:00Z`);
  const diffDays = Math.ceil((exp.getTime() - today.getTime()) / 86400000);
  if (diffDays < 0) return 'expired';
  if (diffDays <= 3) return 'expires_soon';
  return 'active';
}

function normalizeCustomer(row) {
  if (!row) return null;
  const expiresAt = displayDate(row.sas_expiry_date || row.expires_at || row.expiresAt);
  const startAt = displayDate(row.sas_start_date || row.start_at || row.startAt);
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    address: row.address || '',
    package: row.sas_package || row.package_name || row.package || '',
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
    source: row.source || 'manual',
    sasId: row.sas_id || '',
    sasUsername: row.sas_username || '',
    sasStatus: row.sas_status || '',
    sasPhone: row.sas_phone || '',
    sasIp: row.sas_ip || '',
    sasExpiryRaw: row.sas_expiry_raw || '',
    sasMac: row.sas_mac || '',
    lastSyncedAt: row.last_synced_at ? new Date(row.last_synced_at).toISOString() : '',
    sasRemainingDays: row.sas_remaining_days ?? null,
    sasOnlineStatus: row.sas_online_status ?? null,
    sasLastOnline: row.sas_last_online || '',
    sasDailyTrafficGb: row.sas_daily_traffic_gb ?? null,
    sasParentUsername: row.sas_parent_username || '',
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

  await pool.query(`
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_id TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_username TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_package TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_status TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_start_date DATE;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_expiry_date DATE;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_phone TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_ip TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_mac TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_customers_company_sas_id ON customers(company_id, sas_id) WHERE sas_id IS NOT NULL;
  `);

  await pool.query(
    `INSERT INTO companies (id, name) VALUES ($1, $2) ON CONFLICT (id) DO NOTHING`,
    [defaultCompanyId, 'Nodrix Demo']
  );

  await pool.query(`
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_remaining_days INTEGER;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_online_status INTEGER;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_last_online TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_daily_traffic_gb NUMERIC;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_parent_username TEXT;
    ALTER TABLE customers ADD COLUMN IF NOT EXISTS sas_expiry_raw TEXT;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS sas_panels (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      provider TEXT NOT NULL DEFAULT 'uniquefi',
      name TEXT NOT NULL DEFAULT 'SAS Radius',
      base_url TEXT NOT NULL,
      username TEXT NOT NULL,
      password_enc TEXT NOT NULL,
      token_enc TEXT,
      token_updated_at TIMESTAMPTZ,
      active BOOLEAN NOT NULL DEFAULT TRUE,
      last_test_at TIMESTAMPTZ,
      last_synced_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    ALTER TABLE sas_panels ADD COLUMN IF NOT EXISTS token_enc TEXT;
    ALTER TABLE sas_panels ADD COLUMN IF NOT EXISTS token_updated_at TIMESTAMPTZ;
  `);
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
  const today = baghdadDateIso();
  const monthStart = today.slice(0, 8) + '01';
  const paymentsToday = await pool.query(
    `SELECT COALESCE(SUM(amount),0)::int AS total FROM payments WHERE company_id = $1 AND paid_at = $2::date`,
    [defaultCompanyId, today]
  );
  const paymentsMonth = await pool.query(
    `SELECT COALESCE(SUM(amount),0)::int AS total FROM payments
     WHERE company_id = $1 AND paid_at >= $2::date`,
    [defaultCompanyId, monthStart]
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
  const startAt = cleanDate(body.startAt || body.start_at);
  const expiresAt = cleanDate(body.expiresAt || body.expires_at);
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
      cleanDate(body.startAt ?? current.startAt),
      cleanDate(body.expiresAt ?? current.expiresAt),
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
  const paidAt = cleanDate(body.date || body.paidAt) || baghdadDateIso();
  const expiresAt = cleanDate(body.expiresAt || body.expires_at || customer.expiresAt);
  const amount = toInt(body.amount);
  await pool.query(
    `INSERT INTO payments (id, company_id, customer_id, amount, paid_at, expires_at, note)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [paymentId, defaultCompanyId, customerId, amount, paidAt, expiresAt || null, body.note || '']
  );
  const updated = await pool.query(
    `UPDATE customers SET expires_at=$3, debt=GREATEST(debt - $4, 0), updated_at=NOW()
     WHERE company_id=$1 AND id=$2
     RETURNING *`,
    [defaultCompanyId, customerId, expiresAt || null, amount]
  );
  return { ok: true, message: 'تم تسجيل الدفعة', paymentId, customer: normalizeCustomer(updated.rows[0]) };
}


async function getSavedSasConfig() {
  if (!pool) return savedConfig;
  const result = await pool.query(
    `SELECT * FROM sas_panels WHERE company_id=$1 AND active=TRUE ORDER BY updated_at DESC LIMIT 1`,
    [defaultCompanyId]
  );
  const panel = result.rows[0];
  if (!panel) return savedConfig;
  return {
    type: panel.provider,
    sasUrl: panel.base_url,
    username: panel.username,
    password: decryptSecret(panel.password_enc),
    token: decryptSecret(panel.token_enc),
    hasToken: Boolean(panel.token_enc),
    tokenUpdatedAt: panel.token_updated_at,
    panelId: panel.id,
    name: panel.name,
  };
}

async function saveSasPanel({ type, sasUrl, username, password, name }) {
  if (!pool) {
    savedConfig = { type, sasUrl: normalizeBaseUrl(sasUrl), username, password, name };
    return savedConfig;
  }
  const existing = await pool.query(`SELECT id FROM sas_panels WHERE company_id=$1 AND active=TRUE ORDER BY updated_at DESC LIMIT 1`, [defaultCompanyId]);
  const panelId = existing.rows[0]?.id || id('panel');
  await pool.query(`UPDATE sas_panels SET active=FALSE WHERE company_id=$1`, [defaultCompanyId]);
  await pool.query(
    `INSERT INTO sas_panels (id, company_id, provider, name, base_url, username, password_enc, active, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE,NOW())
     ON CONFLICT (id) DO UPDATE SET provider=$3, name=$4, base_url=$5, username=$6, password_enc=$7, active=TRUE, updated_at=NOW()`,
    [panelId, defaultCompanyId, type || 'uniquefi', name || 'SAS Radius', normalizeBaseUrl(sasUrl), username, encryptSecret(password)]
  );
  return { panelId, type: type || 'uniquefi', sasUrl: normalizeBaseUrl(sasUrl), username, name: name || 'SAS Radius' };
}


async function saveSasBrowserToken(token) {
  const cleanToken = String(token || '').trim();
  if (!cleanToken || cleanToken.length < 20) return { ok: false, message: 'جلسة SAS غير صالحة' };
  if (!pool) {
    savedConfig = { ...(savedConfig || {}), token: cleanToken };
    return { ok: true, message: 'تم حفظ جلسة SAS' };
  }
  const config = await getSavedSasConfig();
  if (!config?.panelId) return { ok: false, message: 'احفظ لوحة SAS أولًا قبل حفظ الجلسة' };
  await pool.query(
    `UPDATE sas_panels SET token_enc=$2, token_updated_at=NOW(), updated_at=NOW() WHERE id=$1 AND company_id=$3`,
    [config.panelId, encryptSecret(cleanToken), defaultCompanyId]
  );
  return { ok: true, message: 'تم حفظ جلسة SAS' };
}

async function logoutSasBrowserSession() {
  if (!pool) {
    if (savedConfig) savedConfig.token = '';
    return { ok: true, message: 'تم حذف جلسة SAS' };
  }
  const config = await getSavedSasConfig();
  if (!config?.panelId) return { ok: false, message: 'لا توجد لوحة SAS محفوظة' };
  await pool.query(
    `UPDATE sas_panels SET token_enc=NULL, token_updated_at=NULL, updated_at=NOW() WHERE id=$1 AND company_id=$2`,
    [config.panelId, defaultCompanyId]
  );
  return { ok: true, message: 'تم حذف جلسة SAS' };
}

async function clearMockData() {
  if (!pool) return { ok: true, deleted: 0 };
  const result = await pool.query(
    `DELETE FROM customers
     WHERE company_id=$1 AND (
       source='mock' OR id IN ('cus_ali','cus_zainab','cus_omar')
       OR sas_id LIKE 'sas_%'
       OR name IN ('علي حسن','زينب محمد','عمر خالد','حسين سعيد')
     )`,
    [defaultCompanyId]
  );
  return { ok: true, deleted: result.rowCount };
}

async function upsertSasCustomers(items, panelId = null) {
  let created = 0;
  let updated = 0;
  for (const item of items) {
    const customerId = id('cus');
    const result = await pool.query(
      `INSERT INTO customers (
        id, company_id, name, phone, package_name, price, start_at, expires_at, status, debt,
        sas_id, sas_username, sas_package, sas_status, sas_start_date, sas_expiry_date, sas_phone, sas_ip, sas_expiry_raw, sas_mac,
        sas_remaining_days, sas_online_status, sas_last_online, sas_daily_traffic_gb, sas_parent_username,
        source, last_synced_at
      ) VALUES ($1,$2,$3,$4,$5,$6,NULL,$7,$8,$9,$10,$11,$12,$13,NULL,$14,$15,$16,$17,'',$18,$19,$20,$21,$22,'sas',NOW())
      ON CONFLICT (company_id, sas_id) WHERE sas_id IS NOT NULL DO UPDATE SET
        name=EXCLUDED.name,
        phone=EXCLUDED.phone,
        package_name=EXCLUDED.package_name,
        expires_at=EXCLUDED.expires_at,
        status=EXCLUDED.status,
        sas_username=EXCLUDED.sas_username,
        sas_package=EXCLUDED.sas_package,
        sas_status=EXCLUDED.sas_status,
        sas_expiry_date=EXCLUDED.sas_expiry_date,
        sas_phone=EXCLUDED.sas_phone,
        sas_ip=EXCLUDED.sas_ip,
        sas_expiry_raw=EXCLUDED.sas_expiry_raw,
        sas_remaining_days=EXCLUDED.sas_remaining_days,
        sas_online_status=EXCLUDED.sas_online_status,
        sas_last_online=EXCLUDED.sas_last_online,
        sas_daily_traffic_gb=EXCLUDED.sas_daily_traffic_gb,
        sas_parent_username=EXCLUDED.sas_parent_username,
        source='sas',
        last_synced_at=NOW(),
        updated_at=NOW()
      RETURNING (xmax = 0) AS inserted`,
      [
        customerId,
        defaultCompanyId,
        item.name,
        item.phone || '',
        item.package || '',
        0,
        cleanDate(item.expiresAt),
        item.status || 'active',
        toInt(item.debtDays),
        item.sasId,
        item.sasUsername || '',
        item.package || '',
        item.status || '',
        cleanDate(item.expiresAt),
        item.phone || '',
        item.staticIp || '',
        item.expiryRaw || item.expiresAt || '',
        toInt(item.remainingDays),
        toInt(item.onlineStatus),
        item.lastOnline || '',
        item.dailyTrafficGb || 0,
        item.parentUsername || '',
      ]
    );
    if (result.rows[0]?.inserted) created += 1;
    else updated += 1;
  }
  if (panelId) await pool.query(`UPDATE sas_panels SET last_synced_at=NOW(), updated_at=NOW() WHERE id=$1`, [panelId]);
  return { created, updated };
}

async function syncCustomersFromSas() {
  if (!pool) return { ok: false, message: 'PostgreSQL غير مفعل' };
  const config = await getSavedSasConfig();
  if (!config || !config.sasUrl || !config.username || !config.password) {
    return { ok: false, message: 'أضف لوحة SAS أولًا من صفحة لوحات الساس' };
  }
  const provider = config.type || 'uniquefi';
  if (!['uniquefi', 'sas_radius', 'sas'].includes(provider)) {
    return { ok: false, message: 'هذا النوع غير مدعوم حاليًا. المتوفر الآن SAS Radius / UniqueFi' };
  }
  const fetched = await uniqueFiFetchUsers(config);
  if (!fetched.ok) return fetched;
  const items = fetched.users.map(mapUniqueFiUser).filter((u) => u.sasId);
  const saved = await upsertSasCustomers(items, config.panelId || null);
  return {
    ok: true,
    source: 'uniquefi',
    created: saved.created,
    updated: saved.updated,
    total: items.length,
    remoteTotal: fetched.total,
    pages: fetched.pages,
    syncedAt: fetched.syncedAt,
  };
}

async function importSasUsersFromClient(rawUsers) {
  if (!pool) return { ok: false, message: 'PostgreSQL غير مفعل' };
  const config = await getSavedSasConfig();
  if (!config?.panelId) return { ok: false, message: 'احفظ لوحة SAS أولًا قبل الاستيراد' };
  const users = Array.isArray(rawUsers) ? rawUsers : [];
  const items = users.map(mapUniqueFiUser).filter((u) => u.sasId);
  const saved = await upsertSasCustomers(items, config.panelId || null);
  return {
    ok: true,
    source: 'uniquefi-webview',
    created: saved.created,
    updated: saved.updated,
    total: items.length,
    remoteTotal: users.length,
    syncedAt: new Date().toISOString(),
  };
}

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'Nodrix Backend', database: pool ? 'postgresql' : 'mock' });
});

app.get('/api/app-version', (req, res) => {
  const latestVersion = process.env.APP_LATEST_VERSION || '1.0.7';
  const apkUrl = process.env.APP_APK_URL || `${publicBaseUrl}/downloads/nodrix-latest.apk`;
  const notes =
    process.env.APP_UPDATE_NOTES ||
    'ربط لوحة SAS Radius / UniqueFi، مزامنة المشتركين الحقيقيين، تنظيف البيانات الوهمية، وإصلاح التحديث المباشر.';

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
    const provider = type || 'uniquefi';
    if (!['uniquefi', 'sas_radius', 'sas'].includes(provider)) {
      return res.status(400).json({ ok: false, message: 'هذا النوع غير مدعوم حاليًا' });
    }
    const result = await uniqueFiLogin({ sasUrl, username, password });
    res.status(result.ok ? 200 : 401).json({ ok: result.ok, message: result.ok ? 'تم الاتصال بلوحة SAS بنجاح' : result.message, site: result.site });
  } catch (error) {
    res.status(400).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/save', async (req, res) => {
  try {
    const { type, sasUrl, username, password, name } = req.body;
    if (!sasUrl || !username || !password) return res.status(400).json({ ok: false, message: 'الرابط واليوزر والباسورد مطلوبة' });
    const saved = await saveSasPanel({ type: type || 'uniquefi', sasUrl, username, password, name });
    res.json({ ok: true, message: 'تم حفظ لوحة الساس', panel: { type: saved.type, sasUrl: saved.sasUrl, username: saved.username, name: saved.name } });
  } catch (error) {
    res.status(400).json({ ok: false, message: error.message });
  }
});


app.post('/api/sas/save-token', async (req, res) => {
  try {
    const result = await saveSasBrowserToken(req.body?.token);
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/logout', async (req, res) => {
  try {
    const result = await logoutSasBrowserSession();
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/sas/status', async (req, res) => {
  try {
    const config = await getSavedSasConfig();
    if (!pool) return res.json({ ok: true, database: 'mock', configured: Boolean(config), source: config?.type || 'none', lastSyncedAt: null, count: 0 });
    const count = await pool.query(`SELECT COUNT(*)::int AS count, MAX(last_synced_at) AS last_synced_at FROM customers WHERE company_id=$1 AND source='sas'`, [defaultCompanyId]);
    res.json({
      ok: true,
      database: 'postgresql',
      configured: Boolean(config),
      source: config?.type || 'none',
      panelUrl: config?.sasUrl || '',
      panelUsername: config?.username || '',
      hasToken: Boolean(config?.hasToken || config?.token),
      tokenUpdatedAt: config?.tokenUpdatedAt || null,
      count: count.rows[0].count,
      lastSyncedAt: count.rows[0].last_synced_at,
    });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});



app.get('/api/sas/diagnose', async (req, res) => {
  try {
    const config = await getSavedSasConfig();
    if (!config || !config.sasUrl || !config.username || !config.password) {
      return res.status(400).json({ ok: false, phase: 'config', message: 'لا توجد لوحة SAS محفوظة' });
    }
    let token = String(config.token || '').trim();
    let tokenSource = token ? 'browser' : 'login';
    let login = null;
    if (!token) {
      login = await uniqueFiLogin(config);
      if (!login.ok) {
        return res.status(200).json({ ok: false, phase: login.phase || 'login', message: login.message, status: login.responseStatus || null, resourcesStatus: login.resourcesStatus || null, resourcesBlocked: Boolean(login.resourcesBlocked), hasToken: false });
      }
      token = login.token;
    }
    try {
      const firstPage = await uniqueFiEncryptedPost(config.sasUrl, 'index/user', userIndexPayload(1, 10), token);
      return res.json({
        ok: true,
        phase: 'users',
        tokenSource,
        message: 'الاتصال والمزامنة التجريبية نجحا',
        total: firstPage?.total || 0,
        pageRows: Array.isArray(firstPage?.data) ? firstPage.data.length : 0,
        lastPage: firstPage?.last_page || 1,
      });
    } catch (error) {
      return res.status(200).json({ ok: false, phase: 'users', message: safeSasError('فشل جلب المستخدمين من SAS', error), status: error.status || null });
    }
  } catch (error) {
    res.status(500).json({ ok: false, phase: 'server', message: error.message });
  }
});


app.post('/api/sas/encrypt-user-index-payload', async (req, res) => {
  try {
    const page = Math.max(1, Number(req.body?.page || 1));
    const count = Math.min(200, Math.max(1, Number(req.body?.count || 10)));
    res.json({ ok: true, payload: cryptoJsAesEncrypt(userIndexPayload(page, count)), page, count });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/import-users', async (req, res) => {
  try {
    const result = await importSasUsersFromClient(req.body?.users);
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/sync', async (req, res) => {
  try {
    const result = await syncCustomersFromSas();
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/sas/clear-mock-data', async (req, res) => {
  try {
    res.json(await clearMockData());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/sas/clear-mock-data', async (req, res) => {
  try {
    res.json(await clearMockData());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
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
app.get('/api/reports/income-month', async (req, res) => {
  try {
    if (!pool) return res.json({ ok: true, days: [] });
    const today = baghdadDateIso();
    const monthStart = today.slice(0, 8) + '01';
    const result = await pool.query(
      `SELECT paid_at::text AS date, COALESCE(SUM(amount),0)::int AS total
       FROM payments
       WHERE company_id = $1 AND paid_at >= $2::date
       GROUP BY paid_at
       HAVING COALESCE(SUM(amount),0) > 0
       ORDER BY paid_at DESC`,
      [defaultCompanyId, monthStart]
    );
    res.json({ ok: true, days: result.rows });
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
