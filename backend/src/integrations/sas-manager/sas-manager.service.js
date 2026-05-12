export class SasManagerService {
  constructor({ clientFactory }) {
    this.clientFactory = clientFactory;
  }

  client(config) {
    return this.clientFactory(config);
  }
}
