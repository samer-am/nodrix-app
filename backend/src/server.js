import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createAdapter } from './adapters/index.js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const publicBaseUrl = process.env.PUBLIC_BASE_URL || 'https://nodrix-app-production.up.railway.app';

let savedConfig = null;
let reminderSettings = {
  enabled: true,
  beforeHours: [72, 48, 24],
  messageTemplate:
    'عزيزي {name}، اشتراكك سينتهي بتاريخ {expiresAt}. يرجى التجديد لتجنب توقف الخدمة. الباقة: {package}',
};

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'Nodrix Backend' });
});

app.use('/downloads', express.static('public/downloads'));

app.get('/api/app-version', (req, res) => {
  const latestVersion = process.env.APP_LATEST_VERSION || '1.0.3';
  const apkUrl = process.env.APP_APK_URL || `${publicBaseUrl}/downloads/nodrix-latest.apk`;
  const notes =
    process.env.APP_UPDATE_NOTES ||
    'تحسين واجهة المستخدم، إصلاح رقم النسخة، إضافة وتعديل المشتركين، وتسجيل دفعة مبدئي.';

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
  res.json({ ok: true, message: 'SAS config saved in memory for demo only' });
});

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

app.get('/api/dashboard', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  res.json(await adapter.getDashboard());
});

app.get('/api/customers', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  res.json(await adapter.getCustomers());
});


app.get('/api/customers/:id', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  const customer = await adapter.getCustomer(req.params.id);
  if (!customer) return res.status(404).json({ ok: false, message: 'المشترك غير موجود' });
  res.json({ ok: true, customer });
});

app.post('/api/customers', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  const result = await adapter.addCustomer(req.body);
  res.status(result.ok ? 201 : 400).json(result);
});

app.put('/api/customers/:id', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  const result = await adapter.updateCustomer(req.params.id, req.body);
  res.status(result.ok ? 200 : 400).json(result);
});

app.get('/api/customers/:id/payments', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  res.json({ ok: true, payments: await adapter.getPayments(req.params.id) });
});

app.post('/api/customers/:id/payments', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  const result = await adapter.addPayment(req.params.id, req.body);
  res.status(result.ok ? 201 : 400).json(result);
});

app.get('/api/sectors', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  res.json(await adapter.getSectors());
});

app.get('/api/links', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;
  res.json(await adapter.getLinks());
});

app.get('/api/reminders/settings', (req, res) => {
  res.json(reminderSettings);
});

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
  const adapter = getAdapterOrError(res);
  if (!adapter) return;

  const customers = await adapter.getCustomers();
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
});

app.post('/api/reminders/send-demo', async (req, res) => {
  const adapter = getAdapterOrError(res);
  if (!adapter) return;

  const customers = await adapter.getCustomers();
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

  res.json({
    ok: true,
    provider: 'demo-only',
    note: 'No real WhatsApp message was sent. This is a simulation endpoint.',
    sentCount: sent.length,
    sent,
  });
});

app.listen(port, () => {
  console.log(`Nodrix backend running on http://localhost:${port}`);
});
