export class MockSasAdapter {
  async login({ sasUrl, username, password }) {
    if (!sasUrl || username !== 'admin' || password !== 'admin123') {
      return { ok: false, message: 'Invalid demo credentials. Use admin / admin123' };
    }
    return { ok: true, message: 'Connected to mock SAS successfully' };
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
        name: 'Ahmed Ali',
        phone: '07700000001',
        package: '25 Mbps',
        price: 35000,
        status: 'active',
        tower: 'Al-Nasr Tower',
        sector: 'Sector A',
        username: 'ahmed.ali',
        address: 'Street 12 - near pharmacy',
        startedAt: '2026-04-20',
        expiresAt: '2026-05-20',
        lastPaymentAt: '2026-04-20',
      },
      {
        id: 2,
        name: 'Hussein Kareem',
        phone: '07700000002',
        package: '15 Mbps',
        price: 25000,
        status: 'expires_soon',
        tower: 'Al-Nasr Tower',
        sector: 'Sector B',
        username: 'hussein.k',
        address: 'Market area',
        startedAt: '2026-04-08',
        expiresAt: '2026-05-08',
        lastPaymentAt: '2026-04-08',
      },
      {
        id: 3,
        name: 'Sara Mohammed',
        phone: '07700000003',
        package: '10 Mbps',
        price: 20000,
        status: 'expired',
        tower: 'East Tower',
        sector: 'Sector C',
        username: 'sara.m',
        address: 'School street',
        startedAt: '2026-04-01',
        expiresAt: '2026-05-01',
        lastPaymentAt: '2026-04-01',
      },
      {
        id: 4,
        name: 'Mustafa Raad',
        phone: '07700000004',
        package: '50 Mbps',
        price: 55000,
        status: 'active',
        tower: 'West Tower',
        sector: 'Sector D',
        username: 'mustafa.r',
        address: 'Bridge road',
        startedAt: '2026-04-18',
        expiresAt: '2026-05-18',
        lastPaymentAt: '2026-04-18',
      },
      {
        id: 5,
        name: 'Zainab Hassan',
        phone: '07700000005',
        package: '20 Mbps',
        price: 30000,
        status: 'expires_soon',
        tower: 'East Tower',
        sector: 'Sector C',
        username: 'zainab.h',
        address: 'Block 4',
        startedAt: '2026-04-07',
        expiresAt: '2026-05-07',
        lastPaymentAt: '2026-04-07',
      }
    ];
  }

  async getSectors() {
    return [
      { id: 1, name: 'Sector A', tower: 'Al-Nasr Tower', ip: '192.168.10.2', type: 'Ubiquiti', status: 'online', clients: 44, signal: '-61 dBm', uptime: '18d 4h' },
      { id: 2, name: 'Sector B', tower: 'Al-Nasr Tower', ip: '192.168.10.3', type: 'MikroTik', status: 'online', clients: 38, signal: '-64 dBm', uptime: '9d 2h' },
      { id: 3, name: 'Sector C', tower: 'East Tower', ip: '192.168.10.4', type: 'Mimosa', status: 'offline', clients: 0, signal: 'N/A', uptime: 'offline' },
      { id: 4, name: 'Sector D', tower: 'West Tower', ip: '192.168.10.5', type: 'Cambium', status: 'online', clients: 21, signal: '-58 dBm', uptime: '31d 7h' }
    ];
  }

  async getLinks() {
    return [
      { id: 1, name: 'Main Link', from: 'Core', to: 'Al-Nasr Tower', ip: '192.168.20.2', type: 'Ubiquiti', status: 'online', capacity: '450 Mbps', traffic: '128 Mbps', uptime: '45d 1h' },
      { id: 2, name: 'Backup Link', from: 'Core', to: 'East Tower', ip: '192.168.20.3', type: 'MikroTik', status: 'online', capacity: '250 Mbps', traffic: '72 Mbps', uptime: '12d 9h' },
      { id: 3, name: 'West Link', from: 'Core', to: 'West Tower', ip: '192.168.20.4', type: 'Mimosa', status: 'offline', capacity: '300 Mbps', traffic: '0 Mbps', uptime: 'offline' }
    ];
  }
}
