export class SasManagerClient {
  constructor({ config, endpoints = {}, transport }) {
    this.config = config;
    this.endpoints = endpoints;
    this.transport = transport;
    this.token = config?.token || '';
  }

  async login() {
    return this.transport.login(this.config);
  }

  async logout() {
    this.token = '';
    return { ok: true };
  }

  async ensureAuthenticated() {
    if (this.token) return { ok: true, token: this.token, reused: true };
    const result = await this.login();
    if (result?.ok && result.token) this.token = result.token;
    return result;
  }

  async requestEndpoint(endpointName, payload = undefined) {
    const auth = await this.ensureAuthenticated();
    if (!auth.ok) return auth;
    return this.transport.request(this.config, endpointName, payload, auth.token || this.token);
  }

  getDashboard() {
    return this.requestEndpoint('dashboard');
  }

  getUsers() {
    return this.requestEndpoint('users');
  }

  getUserByUsername(username) {
    return this.requestEndpoint('user_details', { username });
  }

  getOnlineUsers() {
    return this.requestEndpoint('online_users');
  }

  getActiveSessions() {
    return this.requestEndpoint('active_sessions');
  }

  getUserSessions(username) {
    return this.requestEndpoint('user_sessions', { username });
  }

  getUserInvoices(username) {
    return this.requestEndpoint('invoices', { username });
  }

  getUserPayments(username) {
    return this.requestEndpoint('payments', { username });
  }

  getUserBalance(username) {
    return this.requestEndpoint('balance', { username });
  }

  getUserCurrentIp(username) {
    return this.requestEndpoint('current_ip', { username });
  }
}
