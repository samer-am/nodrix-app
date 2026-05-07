export class MockSasAdapter {
  async login({ sasUrl, username, password }) {
    if (!sasUrl || username !== 'admin' || password !== 'admin123') {
      return { ok: false, message: 'بيانات التجربة غير صحيحة. استخدم admin / admin123' };
    }
    return { ok: true, message: 'تم الاتصال بمحول الساس التجريبي بنجاح' };
  }

  async getDashboard() {
    return {
      activeCustomers: 124,
      expiresSoon: 18,
      expiredCustomers: 9,
      towers: 3,
      sectorsOnline: 6,
      sectorsOffline: 1,
      linksOnline: 3,
      linksOffline: 1,
      incomeToday: 185000,
      incomeMonth: 4250000,
      openTickets: 7,
      whatsappDue: 5,
    };
  }

  async getCustomers() {
    return [
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
      }
    ];
  }

  async getSectors() {
    return [
      { id: 1, name: 'سكتر A', tower: 'برج النصر', ip: '192.168.10.2', type: 'Ubiquiti', status: 'online', clients: 44, signal: '-61 dBm', uptime: '18 يوم 4 ساعة' },
      { id: 2, name: 'سكتر B', tower: 'برج النصر', ip: '192.168.10.3', type: 'MikroTik', status: 'online', clients: 38, signal: '-64 dBm', uptime: '9 أيام 2 ساعة' },
      { id: 3, name: 'سكتر C', tower: 'البرج الشرقي', ip: '192.168.10.4', type: 'Mimosa', status: 'offline', clients: 0, signal: 'N/A', uptime: 'متوقف' },
      { id: 4, name: 'سكتر D', tower: 'البرج الغربي', ip: '192.168.10.5', type: 'Cambium', status: 'online', clients: 21, signal: '-58 dBm', uptime: '31 يوم 7 ساعة' }
    ];
  }

  async getLinks() {
    return [
      { id: 1, name: 'النك الرئيسي', from: 'الكور', to: 'برج النصر', ip: '192.168.20.2', type: 'Ubiquiti', status: 'online', capacity: '450 Mbps', traffic: '128 Mbps', uptime: '45 يوم 1 ساعة' },
      { id: 2, name: 'النك الاحتياطي', from: 'الكور', to: 'البرج الشرقي', ip: '192.168.20.3', type: 'MikroTik', status: 'online', capacity: '250 Mbps', traffic: '72 Mbps', uptime: '12 يوم 9 ساعة' },
      { id: 3, name: 'النك الغربي', from: 'الكور', to: 'البرج الغربي', ip: '192.168.20.4', type: 'Mimosa', status: 'offline', capacity: '300 Mbps', traffic: '0 Mbps', uptime: 'متوقف' }
    ];
  }
}
