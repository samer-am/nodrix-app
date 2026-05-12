import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pg from 'pg';
import { randomUUID, createHash, randomBytes, createCipheriv, createDecipheriv } from 'crypto';
import { createAdapter } from './adapters/index.js';
import { DEFAULT_SAS_MANAGER_ENDPOINTS } from './integrations/sas-manager/sas-manager.types.js';
import { mapSasManagerOnlineUser, mapSasManagerUser, firstIp, firstMac, firstValue } from './integrations/sas-manager/sas-manager.mapper.js';

const NETWORK_DEVICE_TIMEOUT_MS = Number(process.env.NETWORK_DEVICE_TIMEOUT_MS || 5000);

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
    columns: ['idx', 'status', 'enable', 'enabled', 'online_status', 'username', 'firstname', 'lastname', 'expiration', 'parent_username', 'name', 'loan_balance', 'traffic', 'remaining_days', 'static_ip', 'ip', 'ip_address', 'framed_ip_address'],
  };
}

function onlineUsersPayload(page = 1, rowsPerPage = 100) {
  return {
    page,
    count: rowsPerPage,
    direction: 'asc',
    sortBy: 'username',
    search: '',
    columns: ['username', 'acctoutputoctets', 'acctinputoctets', 'name', 'framedipaddress', 'callingstationid', 'acctsessiontime', 'oui'],
  };
}

function userSessionsPayload(page = 1, rowsPerPage = 100) {
  return {
    page,
    count: rowsPerPage,
    direction: 'desc',
    sortBy: 'acctstarttime',
    search: '',
    columns: [
      'username',
      'acctstarttime',
      'acctstoptime',
      'framedipaddress',
      'nasipaddress',
      'callingstationid',
      'acctinputoctets',
      'acctoutputoctets',
      'calledstationid',
      'acctterminatecause',
    ],
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

async function uniqueFiFetchOnlineUsers(config) {
  let token = String(config?.token || '').trim();
  if (!token) {
    const login = await uniqueFiLogin(config);
    if (!login.ok) return { ok: false, users: [], message: login.message };
    token = login.token;
  }
  const all = [];
  let lastPage = 1;
  try {
    for (let page = 1; page <= lastPage && page <= 200; page++) {
      const response = await uniqueFiEncryptedPost(config.sasUrl, 'index/online', onlineUsersPayload(page, 100), token);
      const rows = Array.isArray(response?.data) ? response.data : [];
      all.push(...rows);
      lastPage = Number(response?.last_page || lastPage || 1);
      if (!response?.next_page_url && page >= lastPage) break;
    }
  } catch (error) {
    return { ok: false, users: all, message: safeSasError('فشل جلب المتصلين من SAS', error) };
  }
  return { ok: true, users: all };
}

async function uniqueFiFetchUserSessions(config) {
  let token = String(config?.token || '').trim();
  if (!token) {
    const login = await uniqueFiLogin(config);
    if (!login.ok) return { ok: false, sessions: [], message: login.message };
    token = login.token;
  }
  const all = [];
  let lastPage = 1;
  try {
    for (let page = 1; page <= lastPage && page <= 200; page++) {
      const response = await uniqueFiEncryptedPost(config.sasUrl, 'index/UserSessions', userSessionsPayload(page, 100), token);
      const rows = Array.isArray(response?.data) ? response.data : [];
      all.push(...rows);
      lastPage = Number(response?.last_page || lastPage || 1);
      if (!response?.next_page_url && page >= lastPage) break;
    }
  } catch (error) {
    return { ok: false, sessions: all, message: safeSasError('فشل جلب آخر جلسات المستخدمين من SAS', error) };
  }
  return { ok: true, sessions: all };
}

function mergeLastSessions(users, sessions) {
  const latestByUsername = new Map();
  for (const row of sessions || []) {
    const username = String(row?.username || '').trim();
    if (!username || latestByUsername.has(username)) continue;
    latestByUsername.set(username, row);
  }
  return (users || []).map((user) => {
    const session = latestByUsername.get(String(user?.username || '').trim());
    if (!session) return user;
    return {
      ...user,
      last_session_details: session,
      last_session_ip: session.framedipaddress,
      last_session_mac: session.callingstationid,
      last_online: user?.last_online || session.acctstarttime,
    };
  });
}

function mergeOnlineUsers(users, onlineUsers) {
  const onlineByUsername = new Map();
  for (const row of onlineUsers || []) {
    const username = String(row?.username || row?.user_details?.username || '').trim();
    if (username) onlineByUsername.set(username, row);
  }
  return (users || []).map((user) => {
    const online = onlineByUsername.get(String(user?.username || '').trim());
    if (!online) return user;
    return {
      ...user,
      online_status: 1,
      framedipaddress: online.framedipaddress,
      callingstationid: online.callingstationid,
      last_online: online.acctstarttime || user?.last_online,
      online_details: online,
    };
  });
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
    user?.framedipaddress,
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
    user?.online_details?.framedipaddress,
    user?.last_session_ip,
    user?.last_session_details?.framedipaddress,
    user?.connection_details?.ip,
    user?.status?.ip
  );
}

function mapUniqueFiStatus(user) {
  const enabled = user?.enabled ?? user?.enable ?? 1;
  if (Number(enabled) !== 1) return 'paused';
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
    mac: firstText(user?.callingstationid, user?.mac, user?.mac_address, user?.online_details?.callingstationid, user?.last_session_mac, user?.last_session_details?.callingstationid),
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

  await pool.query(`
    CREATE TABLE IF NOT EXISTS network_devices (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'sector',
      vendor TEXT NOT NULL DEFAULT 'ubiquiti',
      tower TEXT,
      ip_address TEXT NOT NULL,
      username TEXT,
      password_enc TEXT,
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'unknown',
      last_seen_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'sector';
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS vendor TEXT NOT NULL DEFAULT 'ubiquiti';
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS tower TEXT;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS ip_address TEXT;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS port INTEGER;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS username TEXT;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS password_enc TEXT;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS connection_method TEXT NOT NULL DEFAULT 'web_api';
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT TRUE;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS notes TEXT;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'unknown';
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
    ALTER TABLE network_devices ADD COLUMN IF NOT EXISTS last_error TEXT;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS sas_manager_configs (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      base_url TEXT NOT NULL,
      username TEXT NOT NULL,
      encrypted_password TEXT NOT NULL,
      login_method TEXT NOT NULL DEFAULT 'unknown',
      enabled BOOLEAN NOT NULL DEFAULT TRUE,
      last_login_at TIMESTAMPTZ,
      last_sync_at TIMESTAMPTZ,
      last_error TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sas_manager_endpoint_map (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      endpoint_name TEXT NOT NULL,
      url_path TEXT NOT NULL,
      method TEXT NOT NULL DEFAULT 'POST',
      auth_type TEXT NOT NULL DEFAULT 'unknown',
      payload_template_json JSONB,
      response_mapping_json JSONB,
      enabled BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sas_users_cache (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      sas_user_id TEXT,
      username TEXT NOT NULL,
      full_name TEXT,
      phone TEXT,
      profile_name TEXT,
      status TEXT,
      expiration TEXT,
      balance NUMERIC,
      debt NUMERIC,
      online BOOLEAN NOT NULL DEFAULT FALSE,
      current_ip TEXT,
      mac TEXT,
      nas_name TEXT,
      last_seen TEXT,
      raw_json JSONB,
      synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sas_sessions_cache (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      username TEXT NOT NULL,
      ip TEXT,
      mac TEXT,
      nas_name TEXT,
      session_id TEXT,
      started_at TEXT,
      uptime TEXT,
      upload NUMERIC,
      download NUMERIC,
      online BOOLEAN NOT NULL DEFAULT FALSE,
      raw_json JSONB,
      synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_ip_sources (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      username TEXT NOT NULL,
      ip TEXT NOT NULL,
      mac TEXT,
      source TEXT NOT NULL,
      confidence INTEGER NOT NULL DEFAULT 50,
      raw_json JSONB,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS uq_sas_manager_configs_company ON sas_manager_configs(company_id) WHERE enabled=TRUE;
    CREATE UNIQUE INDEX IF NOT EXISTS uq_sas_manager_endpoint_company_name ON sas_manager_endpoint_map(company_id, endpoint_name);
    CREATE UNIQUE INDEX IF NOT EXISTS uq_sas_users_cache_company_username ON sas_users_cache(company_id, username);
    CREATE INDEX IF NOT EXISTS idx_sas_sessions_cache_company_username ON sas_sessions_cache(company_id, username);
    CREATE UNIQUE INDEX IF NOT EXISTS uq_user_ip_sources_company_username_source ON user_ip_sources(company_id, username, source);
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

function customerRemainingHours(customer) {
  const clean = cleanDate(customer?.sasExpiryRaw || customer?.expiresAt);
  if (!clean) return null;
  const target = new Date(`${clean}T23:59:59`);
  const now = new Date();
  return Math.floor((target.getTime() - now.getTime()) / (1000 * 60 * 60));
}

function dashboardCustomerIsExpired(customer) {
  const hours = customerRemainingHours(customer);
  if (hours !== null) return hours < 0;
  return customer?.status === 'expired';
}

function dashboardCustomerExpiresSoon(customer) {
  const hours = customerRemainingHours(customer);
  if (hours !== null) return hours >= 0 && hours <= 72;
  const days = Number(customer?.sasRemainingDays);
  return Number.isFinite(days) && days > 0 && days <= 3;
}

function dashboardCustomerIsActive(customer) {
  return !dashboardCustomerIsExpired(customer) && customer?.status !== 'paused';
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
    activeCustomers: customers.filter(dashboardCustomerIsActive).length,
    expiresSoon: customers.filter(dashboardCustomerExpiresSoon).length,
    expiredCustomers: customers.filter(dashboardCustomerIsExpired).length,
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

function normalizeNetworkDevice(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name || '',
    role: row.role || 'sector',
    vendor: row.vendor || 'ubiquiti',
    tower: row.tower || '',
    ip: row.ip_address || row.ip || '',
    port: row.port ?? null,
    username: row.username || '',
    connectionMethod: row.connection_method || 'web_api',
    enabled: row.enabled !== false,
    status: row.status || 'unknown',
    notes: row.notes || '',
    lastError: row.last_error || '',
    lastSeenAt: row.last_seen_at ? new Date(row.last_seen_at).toISOString() : '',
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : '',
  };
}

async function dbNetworkDevices(role = '') {
  const params = [defaultCompanyId];
  let where = 'company_id=$1';
  if (role) {
    params.push(role);
    where += ' AND role=$2';
  }
  const result = await pool.query(
    `SELECT * FROM network_devices WHERE ${where} ORDER BY role, name`,
    params
  );
  return result.rows.map(normalizeNetworkDevice);
}

async function dbAddNetworkDevice(body) {
  const deviceId = id('dev');
  const role = ['sector', 'link', 'switch'].includes(String(body.role || '').toLowerCase())
    ? String(body.role).toLowerCase()
    : 'sector';
  const vendor = String(body.vendor || 'ubiquiti').trim().toLowerCase();
  const name = String(body.name || '').trim();
  const ipAddress = String(body.ip || body.ipAddress || '').trim();
  const port = toInt(body.port || body.hostPort, 0) || null;
  const connectionMethod = String(body.connectionMethod || body.connection_method || 'web_api').trim().toLowerCase();
  if (!name || !ipAddress) return { ok: false, message: 'اسم الجهاز والـ IP مطلوبان' };
  const result = await pool.query(
    `INSERT INTO network_devices
      (id, company_id, name, role, vendor, tower, ip_address, port, username, password_enc, connection_method, notes, status, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'configured',NOW())
     RETURNING *`,
    [
      deviceId,
      defaultCompanyId,
      name,
      role,
      vendor,
      String(body.tower || '').trim(),
      ipAddress,
      port,
      String(body.username || '').trim(),
      body.password ? encryptSecret(body.password) : '',
      connectionMethod,
      String(body.notes || '').trim(),
    ]
  );
  return { ok: true, device: normalizeNetworkDevice(result.rows[0]), message: 'تم ربط الجهاز' };
}

function deviceImageFor(device) {
  const vendor = String(device.vendor || '').toLowerCase();
  if (vendor.includes('ubiquiti')) return 'ubiquiti-radio';
  if (vendor.includes('mikrotik')) return 'mikrotik-router';
  if (vendor.includes('mimosa')) return 'mimosa-radio';
  if (vendor.includes('cisco')) return 'cisco-switch';
  if (vendor.includes('ruijie')) return 'ruijie-device';
  return 'network-device';
}

function simulatedDeviceStats(device, clientsCount = 0) {
  const seed = Math.abs(createHash('md5').update(`${device.id}-${Date.now() / 3000 | 0}`).digest()[0]);
  const rx = Math.round(((seed % 90) / 10 + clientsCount * 0.35) * 10) / 10;
  const tx = Math.round(((seed % 35) / 10 + clientsCount * 0.08) * 10) / 10;
  const uptimeHours = 72 + (seed % 300);
  return {
    connected: true,
    image: deviceImageFor(device),
    clients: clientsCount,
    ccq: clientsCount ? 82 + (seed % 14) : null,
    rxMbps: rx,
    txMbps: tx,
    ethernet: '100 Mbps',
    noise: -88 - (seed % 8),
    uptime: `${Math.floor(uptimeHours / 24)}d ${uptimeHours % 24}h`,
    distance: 900 + (seed % 900),
    frequency: 5800 + (seed % 95),
    cpu: 4 + (seed % 22),
    memory: 28 + (seed % 40),
    rxRate: 40 + (seed % 90),
    txRate: 60 + (seed % 120),
    txLatency: 1 + (seed % 8),
    txPower: 18 + (seed % 10),
    channelWidth: 20,
    essid: `${device.name}-${String(device.ip || '').split('.').pop()}`,
    lanSpeed: '100Mbps-Full',
    sampledAt: new Date().toISOString(),
  };
}

function networkDeviceBaseUrl(device) {
  const host = String(device.ip || '').trim();
  const port = device.port ? `:${device.port}` : '';
  return host.startsWith('http://') || host.startsWith('https://')
    ? host.replace(/\/+$/, '')
    : `http://${host}${port}`;
}

function authHeader(username, password) {
  if (!username && !password) return {};
  return { Authorization: `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}` };
}

async function fetchTextWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), NETWORK_DEVICE_TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    const text = await response.text();
    return { ok: response.ok, status: response.status, text, headers: response.headers };
  } finally {
    clearTimeout(timeout);
  }
}

function parseMaybeJson(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

function walkValues(value, visit) {
  if (Array.isArray(value)) {
    visit(value);
    for (const item of value) walkValues(item, visit);
  } else if (value && typeof value === 'object') {
    for (const item of Object.values(value)) walkValues(item, visit);
  }
}

function normalizeClientCandidate(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const ip = firstIp(raw) || String(firstValue(raw, [
    'lastip',
    'last_ip',
    'ipaddr',
    'ipAddress',
    'remote.ip',
    'sta_ip',
  ]) || '').trim();
  const mac = firstMac(raw);
  const name = String(firstValue(raw, ['name', 'hostname', 'host', 'aprepeater', 'remote', 'station', 'comment']) || '').trim();
  const signal = firstValue(raw, ['signal', 'signal_strength', 'rssi', 'tx_signal', 'rx_signal']);
  if (!ip && !mac && !name) return null;
  return {
    ip,
    mac,
    name,
    signal: String(signal ?? '').trim(),
    ccq: firstValue(raw, ['ccq', 'airmax.quality', 'quality']),
    uptime: String(firstValue(raw, ['uptime', 'assoc_time', 'connected_time']) || '').trim(),
    raw,
  };
}

function extractClientCandidates(raw) {
  const clients = [];
  const seen = new Set();
  walkValues(raw, (array) => {
    if (!array.length || array.length > 500) return;
    for (const item of array) {
      const client = normalizeClientCandidate(item);
      if (!client) continue;
      const key = `${client.ip}|${client.mac}|${client.name}`;
      if (seen.has(key)) continue;
      seen.add(key);
      clients.push(client);
    }
  });
  return clients;
}

function extractUbntStats(raw, device, clients) {
  const wireless = raw?.wireless || raw?.wireless_details || raw?.host || raw;
  return {
    connected: true,
    real: true,
    image: deviceImageFor(device),
    clients: clients.length,
    ccq: firstValue(raw, ['ccq', 'airmax.quality', 'wireless.ccq']) || null,
    rxMbps: Number(firstValue(raw, ['rx', 'rx_rate', 'rxrate', 'throughput.rx']) || 0),
    txMbps: Number(firstValue(raw, ['tx', 'tx_rate', 'txrate', 'throughput.tx']) || 0),
    ethernet: String(firstValue(raw, ['lan.speed', 'eth.speed', 'ethernet']) || ''),
    noise: firstValue(raw, ['noise', 'noisefloor', 'wireless.noise']) || null,
    uptime: String(firstValue(raw, ['uptime', 'host.uptime']) || ''),
    distance: firstValue(wireless, ['distance']) || null,
    frequency: firstValue(raw, ['frequency', 'freq', 'wireless.frequency']) || null,
    cpu: firstValue(raw, ['cpu', 'cpu_usage', 'host.cpu']) || null,
    memory: firstValue(raw, ['memory', 'mem', 'memory_usage', 'host.mem']) || null,
    rxRate: firstValue(raw, ['rx_rate', 'rxrate']) || null,
    txRate: firstValue(raw, ['tx_rate', 'txrate']) || null,
    txLatency: firstValue(raw, ['tx_latency', 'latency']) || null,
    txPower: firstValue(raw, ['txpower', 'tx_power']) || null,
    channelWidth: firstValue(raw, ['channel_width', 'chanbw']) || null,
    essid: String(firstValue(raw, ['essid', 'ssid', 'wireless.essid']) || ''),
    lanSpeed: String(firstValue(raw, ['lanSpeed', 'lan.speed', 'eth.speed']) || ''),
    sampledAt: new Date().toISOString(),
  };
}

async function readUbntDevice(device, password) {
  const baseUrl = networkDeviceBaseUrl(device);
  const username = String(device.username || '').trim();
  const headers = {
    Accept: 'application/json, text/plain, */*',
    ...authHeader(username, password),
  };
  const tried = [];
  const paths = ['/status.cgi', '/sta.cgi', '/stations.cgi', '/api/status', '/api/stations'];
  let cookie = '';

  try {
    const login = await fetchTextWithTimeout(`${baseUrl}/login.cgi`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: '*/*' },
      body: new URLSearchParams({ username, password }).toString(),
    });
    const setCookie = login.headers?.get?.('set-cookie');
    if (setCookie) cookie = setCookie.split(';')[0];
  } catch (_) {
    // Some airOS builds use Basic Auth or block login.cgi. Continue with direct endpoints.
  }

  for (const path of paths) {
    try {
      tried.push(path);
      const response = await fetchTextWithTimeout(`${baseUrl}${path}`, {
        headers: cookie ? { ...headers, Cookie: cookie } : headers,
      });
      if (!response.ok) continue;
      const json = parseMaybeJson(response.text);
      if (!json) continue;
      const clients = extractClientCandidates(json);
      return {
        ok: true,
        path,
        raw: json,
        clients,
        stats: extractUbntStats(json, device, clients),
      };
    } catch (_) {
      // Try next known endpoint.
    }
  }
  return {
    ok: false,
    message: `تعذر قراءة UBNT عبر endpoints: ${tried.join(', ')}`,
    clients: [],
  };
}

async function readNetworkDevice(deviceRow) {
  const device = normalizeNetworkDevice(deviceRow);
  const password = decryptSecret(deviceRow.password_enc || '');
  const vendor = String(device.vendor || '').toLowerCase();
  if (vendor.includes('ubiquiti') || vendor.includes('ubnt')) {
    return readUbntDevice(device, password);
  }
  return {
    ok: false,
    message: `Adapter ${vendor || 'unknown'} غير مفعل بعد. ابدأ بـ UBNT/Ubiquiti أو أضف SNMP/SSH لاحقًا.`,
    clients: [],
  };
}

function normalizeMac(value) {
  return String(value || '').trim().toLowerCase().replace(/[^a-f0-9]/g, '');
}

function matchDeviceClientsToCustomers(clients, customers, device) {
  return clients.map((client) => {
    const clientMac = normalizeMac(client.mac);
    const clientIp = String(client.ip || '').trim();
    const clientName = String(client.name || '').trim().toLowerCase();
    const customer = customers.find((item) => {
      const mac = normalizeMac(item.sasMac || item.mac);
      const ip = String(item.sasIp || '').trim();
      const username = String(item.sasUsername || item.username || '').trim().toLowerCase();
      return (clientMac && mac && clientMac === mac)
        || (clientIp && ip && clientIp === ip)
        || (clientName && username && clientName.includes(username));
    });
    return { ...client, customer: customer || null };
  });
}

async function dbNetworkDeviceDetails(deviceId) {
  const result = await pool.query(
    `SELECT * FROM network_devices WHERE company_id=$1 AND id=$2`,
    [defaultCompanyId, deviceId]
  );
  const deviceRow = result.rows[0];
  const device = normalizeNetworkDevice(deviceRow);
  if (!device) return null;
  const customers = await dbCustomers();
  const related = customers.filter((customer) => {
    const sector = String(customer.sector || '').trim().toLowerCase();
    const tower = String(customer.tower || '').trim().toLowerCase();
    return sector && sector === String(device.name).trim().toLowerCase()
      || tower && tower === String(device.tower).trim().toLowerCase();
  });

  const read = await readNetworkDevice(deviceRow);
  const deviceClients = matchDeviceClientsToCustomers(read.clients || [], customers, device);
  const matchedCustomers = deviceClients
    .map((client) => client.customer)
    .filter(Boolean);
  const uniqueCustomers = Array.from(
    new Map([...matchedCustomers, ...related].map((customer) => [customer.id, customer])).values()
  );

  if (read.ok) {
    for (const client of deviceClients) {
      const username = String(
        client.customer?.sasUsername || client.customer?.username || client.customer?.name || ''
      ).trim();
      if (username && client.ip) {
        await upsertUserIpSource(
          defaultCompanyId,
          username,
          client.ip,
          client.mac || '',
          'network_device',
          90,
          { deviceId, deviceName: device.name, client: client.raw || client }
        );
      }
    }
    const stats = read.stats || simulatedDeviceStats(device, deviceClients.length);
    await pool.query(
      `UPDATE network_devices
       SET status='online', last_error=NULL, last_seen_at=NOW(), updated_at=NOW()
       WHERE company_id=$1 AND id=$2`,
      [defaultCompanyId, deviceId]
    );
    return {
      ok: true,
      real: true,
      adapter: read.path || 'network-device',
      device: { ...device, status: 'online', lastError: '' },
      stats: { ...stats, clients: deviceClients.length },
      customers: uniqueCustomers,
      deviceClients,
    };
  }

  const message = read.message || 'تعذر قراءة الجهاز';
  await pool.query(
    `UPDATE network_devices
     SET status='offline', last_error=$3, updated_at=NOW()
     WHERE company_id=$1 AND id=$2`,
    [defaultCompanyId, deviceId, message]
  );
  return {
    ok: true,
    real: true,
    adapter: 'unavailable',
    message,
    device: { ...device, status: 'offline', lastError: message },
    stats: {
      connected: false,
      real: true,
      image: deviceImageFor(device),
      clients: 0,
      sampledAt: new Date().toISOString(),
    },
    customers: related,
    deviceClients: [],
  };
}

async function seedSasManagerEndpoints(companyId = defaultCompanyId) {
  for (const endpoint of DEFAULT_SAS_MANAGER_ENDPOINTS) {
    await pool.query(
      `INSERT INTO sas_manager_endpoint_map
        (id, company_id, endpoint_name, url_path, method, auth_type, payload_template_json, response_mapping_json, enabled, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,TRUE,NOW())
       ON CONFLICT (company_id, endpoint_name) DO UPDATE SET
        url_path=EXCLUDED.url_path,
        method=EXCLUDED.method,
        auth_type=EXCLUDED.auth_type,
        updated_at=NOW()`,
      [
        id('sme'),
        companyId,
        endpoint.name,
        endpoint.urlPath,
        endpoint.method,
        endpoint.authType,
        JSON.stringify({}),
        JSON.stringify({ purpose: endpoint.purpose }),
      ]
    );
  }
}

async function getSasManagerConfig(companyId = defaultCompanyId) {
  if (!pool) return null;
  const result = await pool.query(
    `SELECT * FROM sas_manager_configs WHERE company_id=$1 AND enabled=TRUE ORDER BY updated_at DESC LIMIT 1`,
    [companyId]
  );
  const row = result.rows[0];
  if (row) {
    return {
      id: row.id,
      companyId: row.company_id,
      sasUrl: row.base_url,
      baseUrl: row.base_url,
      username: row.username,
      password: decryptSecret(row.encrypted_password),
      loginMethod: row.login_method,
    };
  }
  const fallback = await getSavedSasConfig();
  if (!fallback?.sasUrl) return null;
  return {
    id: fallback.panelId || '',
    companyId,
    sasUrl: fallback.sasUrl,
    baseUrl: fallback.sasUrl,
    username: fallback.username,
    password: fallback.password,
    token: fallback.token,
    loginMethod: fallback.hasToken ? 'token' : 'unknown',
  };
}

async function saveSasManagerConfig(companyId, body) {
  const configId = id('smc');
  const baseUrl = normalizeBaseUrl(body.baseUrl || body.base_url || body.sasUrl);
  const username = String(body.username || '').trim();
  const password = String(body.password || '').trim();
  if (!baseUrl || !username || !password) return { ok: false, message: 'baseUrl واليوزر والباسورد مطلوبة' };
  await pool.query(`UPDATE sas_manager_configs SET enabled=FALSE, updated_at=NOW() WHERE company_id=$1`, [companyId]);
  const result = await pool.query(
    `INSERT INTO sas_manager_configs
      (id, company_id, base_url, username, encrypted_password, login_method, enabled, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,TRUE,NOW())
     RETURNING *`,
    [configId, companyId, baseUrl, username, encryptSecret(password), body.loginMethod || body.login_method || 'unknown']
  );
  await seedSasManagerEndpoints(companyId);
  return { ok: true, config: { id: result.rows[0].id, companyId, baseUrl, username, loginMethod: result.rows[0].login_method } };
}

async function listSasManagerEndpoints(companyId = defaultCompanyId) {
  await seedSasManagerEndpoints(companyId);
  const result = await pool.query(
    `SELECT * FROM sas_manager_endpoint_map WHERE company_id=$1 ORDER BY endpoint_name`,
    [companyId]
  );
  return result.rows.map((row) => ({
    id: row.id,
    name: row.endpoint_name,
    urlPath: row.url_path,
    method: row.method,
    authType: row.auth_type,
    payloadTemplate: row.payload_template_json || {},
    responseMapping: row.response_mapping_json || {},
    enabled: row.enabled,
  }));
}

async function addSasManagerEndpoint(companyId, body) {
  const endpointId = id('sme');
  const endpointName = String(body.name || body.endpointName || '').trim();
  const urlPath = String(body.urlPath || body.url || '').trim().replace(/^\/+/, '');
  if (!endpointName || !urlPath) return { ok: false, message: 'اسم endpoint والمسار مطلوبان' };
  const result = await pool.query(
    `INSERT INTO sas_manager_endpoint_map
      (id, company_id, endpoint_name, url_path, method, auth_type, payload_template_json, response_mapping_json, enabled, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,TRUE,NOW())
     ON CONFLICT (company_id, endpoint_name) DO UPDATE SET
      url_path=EXCLUDED.url_path,
      method=EXCLUDED.method,
      auth_type=EXCLUDED.auth_type,
      payload_template_json=EXCLUDED.payload_template_json,
      response_mapping_json=EXCLUDED.response_mapping_json,
      enabled=TRUE,
      updated_at=NOW()
     RETURNING *`,
    [
      endpointId,
      companyId,
      endpointName,
      urlPath,
      String(body.method || 'POST').toUpperCase(),
      body.authType || body.auth_type || 'unknown',
      JSON.stringify(body.payloadTemplate || body.payload_template_json || {}),
      JSON.stringify(body.responseMapping || body.response_mapping_json || {}),
    ]
  );
  return { ok: true, endpoint: result.rows[0] };
}

async function upsertSasManagerUserCache(companyId, user) {
  if (!user.username) return;
  await pool.query(
    `INSERT INTO sas_users_cache
      (id, company_id, sas_user_id, username, full_name, phone, profile_name, status, expiration, balance, debt, online, current_ip, mac, nas_name, last_seen, raw_json, synced_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,NOW())
     ON CONFLICT (company_id, username) DO UPDATE SET
      full_name=EXCLUDED.full_name,
      phone=EXCLUDED.phone,
      profile_name=EXCLUDED.profile_name,
      status=EXCLUDED.status,
      expiration=EXCLUDED.expiration,
      balance=EXCLUDED.balance,
      debt=EXCLUDED.debt,
      online=EXCLUDED.online,
      current_ip=COALESCE(NULLIF(EXCLUDED.current_ip,''), sas_users_cache.current_ip),
      mac=COALESCE(NULLIF(EXCLUDED.mac,''), sas_users_cache.mac),
      nas_name=COALESCE(NULLIF(EXCLUDED.nas_name,''), sas_users_cache.nas_name),
      last_seen=COALESCE(NULLIF(EXCLUDED.last_seen,''), sas_users_cache.last_seen),
      raw_json=EXCLUDED.raw_json,
      synced_at=NOW()`,
    [
      id('suc'),
      companyId,
      String(user.raw?.id || user.username),
      user.username,
      user.fullName || '',
      user.phone || '',
      user.profile || '',
      user.status || '',
      user.expiration || '',
      user.balance || 0,
      user.debt || 0,
      Boolean(user.online),
      user.currentIp || '',
      user.mac || '',
      user.nasName || '',
      user.lastSeen || '',
      JSON.stringify(user.raw || {}),
    ]
  );
}

async function upsertSasManagerSessionCache(companyId, session, source = 'sas_manager_session', confidence = 75) {
  if (!session.username) return;
  const sessionId = session.sessionId || `${session.username}-${session.sessionStart || Date.now()}`;
  await pool.query(
    `INSERT INTO sas_sessions_cache
      (id, company_id, username, ip, mac, nas_name, session_id, started_at, uptime, upload, download, online, raw_json, synced_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW())`,
    [
      id('ssc'),
      companyId,
      session.username,
      session.ip || session.framedIpAddress || '',
      session.macAddress || session.callingStationId || '',
      session.nasName || session.nasIp || '',
      sessionId,
      session.sessionStart || '',
      String(session.uptime || ''),
      session.upload || 0,
      session.download || 0,
      source === 'sas_manager_online',
      JSON.stringify(session.raw || {}),
    ]
  );
  const ip = session.ip || session.framedIpAddress || '';
  if (ip) await upsertUserIpSource(companyId, session.username, ip, session.macAddress || session.callingStationId || '', source, confidence, session.raw);
}

async function upsertUserIpSource(companyId, username, ip, mac, source, confidence, raw) {
  if (!username || !ip) return;
  await pool.query(
    `INSERT INTO user_ip_sources
      (id, company_id, username, ip, mac, source, confidence, raw_json, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
     ON CONFLICT (company_id, username, source) DO UPDATE SET
      ip=EXCLUDED.ip,
      mac=COALESCE(NULLIF(EXCLUDED.mac,''), user_ip_sources.mac),
      confidence=EXCLUDED.confidence,
      raw_json=EXCLUDED.raw_json,
      updated_at=NOW()`,
    [id('uis'), companyId, username, ip, mac || '', source, confidence, JSON.stringify(raw || {})]
  );
}

async function syncCompanySasManager(companyId = defaultCompanyId) {
  const config = await getSasManagerConfig(companyId);
  if (!config) return { ok: false, message: 'لا توجد إعدادات SAS Manager محفوظة' };
  const fetched = await uniqueFiFetchUsers(config);
  if (!fetched.ok) {
    await pool.query(`UPDATE sas_manager_configs SET last_error=$2, updated_at=NOW() WHERE company_id=$1 AND enabled=TRUE`, [companyId, fetched.message || 'users failed']);
    return fetched;
  }
  const sessions = await uniqueFiFetchUserSessions(config);
  const online = await uniqueFiFetchOnlineUsers(config);
  const usersWithSessions = sessions.ok ? mergeLastSessions(fetched.users, sessions.sessions) : fetched.users;
  const mergedUsers = online.ok ? mergeOnlineUsers(usersWithSessions, online.users) : usersWithSessions;
  const mappedUsers = mergedUsers.map(mapSasManagerUser).filter((user) => user.username);
  const mappedOnline = (online.users || []).map(mapSasManagerOnlineUser).filter((session) => session.username);
  const mappedSessions = (sessions.sessions || []).map(mapSasManagerOnlineUser).filter((session) => session.username);
  for (const user of mappedUsers) {
    await upsertSasManagerUserCache(companyId, user);
    if (user.currentIp) await upsertUserIpSource(companyId, user.username, user.currentIp, user.mac, 'sas_manager_accounting', 70, user.raw);
  }
  for (const session of mappedSessions) await upsertSasManagerSessionCache(companyId, session, 'sas_manager_session', 80);
  for (const session of mappedOnline) await upsertSasManagerSessionCache(companyId, session, 'sas_manager_online', 95);
  const items = mergedUsers.map(mapUniqueFiUser).filter((u) => u.sasId);
  const saved = await upsertSasCustomers(items, config.id || null);
  await pool.query(
    `UPDATE sas_manager_configs SET last_sync_at=NOW(), last_error=NULL, updated_at=NOW() WHERE company_id=$1 AND enabled=TRUE`,
    [companyId]
  );
  return {
    ok: true,
    source: 'sas-manager',
    users: mappedUsers.length,
    onlineUsers: mappedOnline.length,
    sessions: mappedSessions.length,
    created: saved.created,
    updated: saved.updated,
    remoteTotal: fetched.total,
    pages: fetched.pages,
  };
}

async function getCachedSasManagerUsers(companyId = defaultCompanyId) {
  const result = await pool.query(
    `SELECT * FROM sas_users_cache WHERE company_id=$1 ORDER BY username`,
    [companyId]
  );
  return result.rows;
}

async function getCachedSasManagerUser(companyId, username) {
  const result = await pool.query(
    `SELECT * FROM sas_users_cache WHERE company_id=$1 AND lower(username)=lower($2) LIMIT 1`,
    [companyId, username]
  );
  return result.rows[0] || null;
}

async function getCachedOnlineUsers(companyId = defaultCompanyId) {
  const result = await pool.query(
    `SELECT * FROM sas_users_cache WHERE company_id=$1 AND online=TRUE ORDER BY username`,
    [companyId]
  );
  return result.rows;
}

async function getCurrentIpForUsername(companyId, username) {
  const result = await pool.query(
    `SELECT * FROM user_ip_sources WHERE company_id=$1 AND lower(username)=lower($2) ORDER BY confidence DESC, updated_at DESC LIMIT 1`,
    [companyId, username]
  );
  const row = result.rows[0];
  if (!row) return { ok: false, username, ip: '', source: '', confidence: 0 };
  return { ok: true, username: row.username, ip: row.ip, mac: row.mac || '', source: row.source, confidence: row.confidence, updatedAt: row.updated_at };
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
      ) VALUES ($1,$2,$3,$4,$5,$6,NULL,$7,$8,$9,$10,$11,$12,$13,NULL,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,'sas',NOW())
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
        sas_mac=EXCLUDED.sas_mac,
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
        item.mac || '',
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
  const sessions = await uniqueFiFetchUserSessions(config);
  const online = await uniqueFiFetchOnlineUsers(config);
  const usersWithSessions = sessions.ok ? mergeLastSessions(fetched.users, sessions.sessions) : fetched.users;
  const mergedUsers = online.ok ? mergeOnlineUsers(usersWithSessions, online.users) : usersWithSessions;
  const items = mergedUsers.map(mapUniqueFiUser).filter((u) => u.sasId);
  const saved = await upsertSasCustomers(items, config.panelId || null);
  return {
    ok: true,
    source: 'uniquefi',
    created: saved.created,
    updated: saved.updated,
    total: items.length,
    remoteTotal: fetched.total,
    pages: fetched.pages,
    onlineTotal: online.ok ? online.users.length : 0,
    sessionsTotal: sessions.ok ? sessions.sessions.length : 0,
    syncedAt: fetched.syncedAt,
  };
}

async function importSasUsersFromClient(rawUsers) {
  if (!pool) return { ok: false, message: 'PostgreSQL غير مفعل' };
  const config = await getSavedSasConfig();
  if (!config?.panelId) return { ok: false, message: 'احفظ لوحة SAS أولًا قبل الاستيراد' };
  const users = Array.isArray(rawUsers) ? rawUsers : [];
  const sessions = await uniqueFiFetchUserSessions(config);
  const online = await uniqueFiFetchOnlineUsers(config);
  const usersWithSessions = sessions.ok ? mergeLastSessions(users, sessions.sessions) : users;
  const mergedUsers = online.ok ? mergeOnlineUsers(usersWithSessions, online.users) : usersWithSessions;
  const items = mergedUsers.map(mapUniqueFiUser).filter((u) => u.sasId);
  const saved = await upsertSasCustomers(items, config.panelId || null);
  return {
    ok: true,
    source: 'uniquefi-webview',
    created: saved.created,
    updated: saved.updated,
    total: items.length,
    remoteTotal: users.length,
    onlineTotal: online.ok ? online.users.length : 0,
    sessionsTotal: sessions.ok ? sessions.sessions.length : 0,
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
  try {
    if (pool) return res.json(await dbNetworkDevices('sector'));
    const adapter = savedConfig ? createAdapter(savedConfig.type) : createAdapter('mock');
    res.json(await adapter.getSectors());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/links', async (req, res) => {
  try {
    if (pool) return res.json(await dbNetworkDevices('link'));
    const adapter = savedConfig ? createAdapter(savedConfig.type) : createAdapter('mock');
    res.json(await adapter.getLinks());
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/network-devices', async (req, res) => {
  try {
    if (!pool) return res.json({ ok: true, devices: [] });
    res.json({ ok: true, devices: await dbNetworkDevices(String(req.query.role || '')) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/network-devices', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const result = await dbAddNetworkDevice(req.body);
    res.status(result.ok ? 201 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/api/network-devices/:id/live', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const result = await dbNetworkDeviceDetails(req.params.id);
    if (!result) return res.status(404).json({ ok: false, message: 'الجهاز غير موجود' });
    res.json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/companies/:companyId/sas-manager/config', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    res.json(await saveSasManagerConfig(req.params.companyId || defaultCompanyId, req.body || {}));
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/sas-manager/test', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const companyId = req.params.companyId || defaultCompanyId;
    const config = await getSasManagerConfig(companyId);
    if (!config) return res.status(400).json({ ok: false, message: 'لا توجد إعدادات SAS Manager' });
    const result = await uniqueFiLogin(config);
    if (result.ok) {
      await pool.query(`UPDATE sas_manager_configs SET last_login_at=NOW(), last_error=NULL, updated_at=NOW() WHERE company_id=$1 AND enabled=TRUE`, [companyId]);
    } else {
      await pool.query(`UPDATE sas_manager_configs SET last_error=$2, updated_at=NOW() WHERE company_id=$1 AND enabled=TRUE`, [companyId, result.message || 'login failed']);
    }
    res.status(result.ok ? 200 : 400).json({ ok: result.ok, message: result.message || 'تم الاتصال', authType: result.token ? 'bearer' : 'unknown', resourcesBlocked: Boolean(result.resourcesBlocked) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/sas-manager/endpoints', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    res.json({ ok: true, endpoints: await listSasManagerEndpoints(req.params.companyId || defaultCompanyId) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/companies/:companyId/sas-manager/endpoints', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    res.status(201).json(await addSasManagerEndpoint(req.params.companyId || defaultCompanyId, req.body || {}));
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/companies/:companyId/sas-manager/sync', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const result = await syncCompanySasManager(req.params.companyId || defaultCompanyId);
    res.status(result.ok ? 200 : 400).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/companies/:companyId/sas-manager/sync-user/:username', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const companyId = req.params.companyId || defaultCompanyId;
    const sync = await syncCompanySasManager(companyId);
    const user = await getCachedSasManagerUser(companyId, req.params.username);
    res.status(user ? 200 : 404).json({ ok: Boolean(user), sync, user });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/sas-manager/users', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    res.json({ ok: true, users: await getCachedSasManagerUsers(req.params.companyId || defaultCompanyId) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/sas-manager/users/:username', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const user = await getCachedSasManagerUser(req.params.companyId || defaultCompanyId, req.params.username);
    res.status(user ? 200 : 404).json({ ok: Boolean(user), user });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/sas-manager/online-users', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    res.json({ ok: true, users: await getCachedOnlineUsers(req.params.companyId || defaultCompanyId) });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/companies/:companyId/users/:username/current-ip', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const result = await getCurrentIpForUsername(req.params.companyId || defaultCompanyId, req.params.username);
    res.status(result.ok ? 200 : 404).json(result);
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

function createNodrixToken(companyId, username) {
  const payload = Buffer.from(JSON.stringify({ companyId, username, iat: Date.now() })).toString('base64url');
  const sig = createHash('sha256').update(`${payload}.${process.env.APP_SECRET || databaseUrl || 'nodrix-local-secret'}`).digest('base64url');
  return `${payload}.${sig}`;
}

function verifyNodrixToken(token) {
  const [payload, sig] = String(token || '').split('.');
  if (!payload || !sig) return null;
  const expected = createHash('sha256').update(`${payload}.${process.env.APP_SECRET || databaseUrl || 'nodrix-local-secret'}`).digest('base64url');
  if (sig !== expected) return null;
  try {
    return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch (_) {
    return null;
  }
}

async function currentUserFromRequest(req) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const session = verifyNodrixToken(token);
  if (!session?.username) return null;
  const user = await getCachedSasManagerUser(session.companyId || defaultCompanyId, session.username);
  return user ? { session, user } : null;
}

app.post('/auth/sas-login', async (req, res) => {
  try {
    if (!pool) return res.status(400).json({ ok: false, message: 'PostgreSQL غير مفعل' });
    const companyId = req.body?.companyId || req.body?.companyCode || defaultCompanyId;
    const username = String(req.body?.username || '').trim();
    const password = String(req.body?.password || '').trim();
    if (!username || !password) return res.status(400).json({ ok: false, message: 'اليوزر والباسورد مطلوبان' });
    const user = await getCachedSasManagerUser(companyId, username);
    if (!user) return res.status(404).json({ ok: false, message: 'المستخدم غير موجود في cache. نفذ sync أولًا.' });
    return res.status(501).json({
      ok: false,
      message: 'لم يتم اكتشاف endpoint آمن لتسجيل دخول المشترك من SAS Manager بعد. لن يتم قبول الباسورد بالتخمين.',
      user: { username: user.username, fullName: user.full_name, status: user.status, currentIp: user.current_ip },
    });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/me', async (req, res) => {
  try {
    const current = await currentUserFromRequest(req);
    if (!current) return res.status(401).json({ ok: false, message: 'جلسة Nodrix غير صالحة' });
    res.json({ ok: true, user: current.user });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/me/sync', async (req, res) => {
  try {
    const current = await currentUserFromRequest(req);
    if (!current) return res.status(401).json({ ok: false, message: 'جلسة Nodrix غير صالحة' });
    const sync = await syncCompanySasManager(current.session.companyId || defaultCompanyId);
    const user = await getCachedSasManagerUser(current.session.companyId || defaultCompanyId, current.session.username);
    res.status(sync.ok ? 200 : 400).json({ ok: sync.ok, sync, user });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/me/session', async (req, res) => {
  try {
    const current = await currentUserFromRequest(req);
    if (!current) return res.status(401).json({ ok: false, message: 'جلسة Nodrix غير صالحة' });
    const result = await pool.query(
      `SELECT * FROM sas_sessions_cache WHERE company_id=$1 AND lower(username)=lower($2) ORDER BY synced_at DESC LIMIT 1`,
      [current.session.companyId || defaultCompanyId, current.session.username]
    );
    res.json({ ok: true, session: result.rows[0] || null });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get('/me/invoices', async (req, res) => {
  res.status(501).json({ ok: false, invoices: [], message: 'Endpoint الفواتير من SAS Manager غير مؤكد بعد ويحتاج HAR/cURL.' });
});

app.get('/me/payments', async (req, res) => {
  res.status(501).json({ ok: false, payments: [], message: 'Endpoint الدفعات من SAS Manager غير مؤكد بعد ويحتاج HAR/cURL.' });
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
