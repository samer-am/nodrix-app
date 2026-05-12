export class SasManagerSyncService {
  constructor({ clientFactory, mapper }) {
    this.clientFactory = clientFactory;
    this.mapper = mapper;
  }

  async syncCompanySas(config) {
    const client = this.clientFactory(config);
    const users = await client.getUsers();
    const online = await client.getOnlineUsers();
    const sessions = await client.getActiveSessions();
    return { users, online, sessions };
  }
}
