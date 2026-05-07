import { MockSasAdapter } from './MockSasAdapter.js';

export function createAdapter(type) {
  switch ((type || '').toLowerCase()) {
    case 'mock':
      return new MockSasAdapter();
    default:
      throw new Error(`Unsupported SAS type: ${type}. Currently only mock is implemented.`);
  }
}
