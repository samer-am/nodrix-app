export class SasManagerAuthService {
  constructor(clientFactory) {
    this.clientFactory = clientFactory;
  }

  async test(config) {
    const client = this.clientFactory(config);
    return client.login();
  }
}
