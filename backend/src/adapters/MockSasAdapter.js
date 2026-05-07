const todayIso = () => new Date().toISOString().slice(0, 10);

let nextCustomerId = 6;
let nextPaymentId = 1;

const payments = [];

const customers = [
  {
    id: 1,
    name: 'أحمد علي',
    phone: '07700000001',
    package: '25 ميغابت',
    price: 35000,
    status: 'active',
    tower: 'برج النصر',
    sector: 'سكتر A',
    username: 'ahmed.ali',
    address: 'شارع 12 - قرب الصيدلية',
    startedAt: '2026-04-20',
    expiresAt: '2026-05-20',
    lastPaymentAt: '2026-04-20',
    notes: 'مشترك منتظم. لا توجد مشاكل حالية.',
  },
  {
    id: 2,
    name: 'حسين كريم',
    phone: '07700000002',
    package: '15 ميغابت',
    price: 25000,
    status: 'expires_soon',
    tower: 'برج النصر',
    sector: 'سكتر B',
    username: 'hussein.k',
    address: 'منطقة السوق',
    startedAt: '2026-04-08',
    expiresAt: '2026-05-08',
    lastPaymentAt: '2026-04-08',
    notes: 'يرسل له تنبيه قبل الانتهاء.',
  },
  {
    id: 3,
    name: 'سارة محمد',
    phone: '07700000003',
    package: '10 ميغابت',
    price: 20000,
    status: 'expired',
    tower: 'البرج الشرقي',
    sector: 'سكتر C',
    username: 'sara.m',
    address: 'شارع المدرسة',
    startedAt: '2026-04-01',
    expiresAt: '2026-05-01',
    lastPaymentAt: '2026-04-01',
    notes: 'تحتاج متابعة للتجديد.',
  },
  {
    id: 4,
    name: 'مصطفى رعد',
    phone: '07700000004',
    package: '50 ميغابت',
    price: 55000,
    status: 'active',
    tower: 'البرج الغربي',
    sector: 'سكتر D',
    username: 'mustafa.r',
    address: 'طريق الجسر',
    startedAt: '2026-04-18',
    expiresAt: '2026-05-18',
    lastPaymentAt: '2026-04-18',
    notes: 'باقة عالية السرعة.',
  },
  {
    id: 5,
    name: 'زينب حسن',
    phone: '07700000005',
    package: '20 ميغابت',
    price: 30000,
    status: 'expires_soon',
    tower: 'البرج الشرقي',
    sector: 'سكتر C',
    username: 'zainab.h',
    address: 'بلوك 4',
    startedAt: '2026-04-07',
    expiresAt: '2026-05-07',
    lastPaymentAt: '2026-04-07',
    notes: '',
  },
];

const sectors = [
  { id: 1, name: 'سكتر A', tower: 'برج النصر', ip: '192.168.10.2', type: 'Ubiquiti', status: 'online', clients: 44, signal: '-61 dBm', uptime: '18 يوم 4 ساعة' },
  { id: 2, name: 'سكتر B', tower: 'برج النصر', ip: '192.168.10.3', type: 'MikroTik', status: 'online', clients: 38, signal: '-64 dBm', uptime: '9 أيام 2 ساعة' },
  { id: 3, name: 'سكتر C', tower: 'البرج الشرقي', ip: '192.168.10.4', type: 'Mimosa', status: 'offline', clients: 0, signal: 'N/A', uptime: 'متوقف' },
  { id: 4, name: 'سكتر D', tower: 'البرج الغربي', ip: '192.168.10.5', type: 'Cambium', status: 'online', clients: 21, signal: '-58 dBm', uptime: '31 يوم 7 ساعة' }
];

const links = [
  { id: 1, name: 'النك الرئيسي', from: 'الكور', to: 'برج النصر', ip: '192.168.20.2', type: 'Ubiquiti', status: 'online', capacity: '450 Mbps', traffic: '128 Mbps', uptime: '45 يوم 1 ساعة' },
  { id: 2, name: 'النك الاحتياطي', from: 'الكور', to: 'البرج الشرقي', ip: '192.168.20.3', type: 'MikroTik', status: 'online', capacity: '250 Mbps', traffic: '72 Mbps', uptime: '12 يوم 9 ساعة' },
  { id: 3, name: 'النك الغربي', from: 'الكور', to: 'البرج الغربي', ip: '192.168.20.4', type: 'Mimosa', status: 'offline', capacity: '300 Mbps', traffic: '0 Mbps', uptime: 'متوقف' }
];

function normalizeCustomer(input, existing = {}) {
  const price = Number(input.price ?? existing.price ?? 0);
  return {
    ...existing,
    name: String(input.name ?? existing.name ?? '').trim(),
    phone: String(input.phone ?? existing.phone ?? '').trim(),
    username: String(input.username ?? existing.username ?? '').trim(),
    package: String(input.package ?? existing.package ?? '').trim(),
    price: Number.isFinite(price) ? price : 0,
    status: String(input.status ?? existing.status ?? 'active'),
    tower: String(input.tower ?? existing.tower ?? '').trim(),
    sector: String(input.sector ?? existing.sector ?? '').trim(),
    address: String(input.address ?? existing.address ?? '').trim(),
    startedAt: String(input.startedAt ?? existing.startedAt ?? todayIso()),
    expiresAt: String(input.expiresAt ?? existing.expiresAt ?? todayIso()),
    lastPaymentAt: String(input.lastPaymentAt ?? existing.lastPaymentAt ?? ''),
    notes: String(input.notes ?? existing.notes ?? '').trim(),
  };
}

function validateCustomer(customer) {
  if (!customer.name) return 'اسم المشترك مطلوب';
  if (!customer.phone) return 'رقم الهاتف مطلوب';
  if (!customer.package) return 'الباقة مطلوبة';
  return null;
}

export class MockSasAdapter {
  async login({ sasUrl, username, password }) {
    if (!sasUrl || username !== 'admin' || password !== 'admin123') {
      return { ok: false, message: 'بيانات التجربة غير صحيحة. استخدم admin / admin123' };
    }
    return { ok: true, message: 'تم الاتصال بمحول الساس التجريبي بنجاح' };
  }

  async getDashboard() {
    const activeCustomers = customers.filter((c) => c.status === 'active').length;
    const expiresSoon = customers.filter((c) => c.status === 'expires_soon').length;
    const expiredCustomers = customers.filter((c) => c.status === 'expired').length;
    const incomeToday = payments
      .filter((p) => p.date === todayIso())
      .reduce((sum, p) => sum + Number(p.amount || 0), 0) || 185000;
    const incomeMonth = payments.reduce((sum, p) => sum + Number(p.amount || 0), 0) || 4250000;

    return {
      activeCustomers,
      expiresSoon,
      expiredCustomers,
      totalCustomers: customers.length,
      towers: new Set(customers.map((c) => c.tower).filter(Boolean)).size || 3,
      sectorsOnline: sectors.filter((s) => s.status === 'online').length,
      sectorsOffline: sectors.filter((s) => s.status === 'offline').length,
      linksOnline: links.filter((l) => l.status === 'online').length,
      linksOffline: links.filter((l) => l.status === 'offline').length,
      incomeToday,
      incomeMonth,
      openTickets: 7,
      whatsappDue: expiresSoon,
    };
  }

  async getCustomers() {
    return customers;
  }

  async getCustomer(id) {
    return customers.find((c) => Number(c.id) === Number(id)) || null;
  }

  async addCustomer(input) {
    const customer = normalizeCustomer(input);
    const error = validateCustomer(customer);
    if (error) return { ok: false, message: error };
    customer.id = nextCustomerId++;
    customers.unshift(customer);
    return { ok: true, customer, message: 'تمت إضافة المشترك بنجاح' };
  }

  async updateCustomer(id, input) {
    const index = customers.findIndex((c) => Number(c.id) === Number(id));
    if (index === -1) return { ok: false, message: 'المشترك غير موجود' };
    const customer = normalizeCustomer(input, customers[index]);
    const error = validateCustomer(customer);
    if (error) return { ok: false, message: error };
    customer.id = customers[index].id;
    customers[index] = customer;
    return { ok: true, customer, message: 'تم تعديل بيانات المشترك' };
  }

  async addPayment(id, input) {
    const customer = await this.getCustomer(id);
    if (!customer) return { ok: false, message: 'المشترك غير موجود' };
    const amount = Number(input.amount ?? customer.price ?? 0);
    if (!Number.isFinite(amount) || amount <= 0) return { ok: false, message: 'المبلغ غير صحيح' };

    const payment = {
      id: nextPaymentId++,
      customerId: customer.id,
      amount,
      date: String(input.date || todayIso()),
      note: String(input.note || '').trim(),
    };
    payments.unshift(payment);
    customer.lastPaymentAt = payment.date;
    if (input.expiresAt) customer.expiresAt = String(input.expiresAt);
    customer.status = 'active';
    return { ok: true, payment, customer, message: 'تم تسجيل الدفعة' };
  }

  async getPayments(id) {
    return payments.filter((p) => Number(p.customerId) === Number(id));
  }

  async getSectors() {
    return sectors;
  }

  async getLinks() {
    return links;
  }
}
