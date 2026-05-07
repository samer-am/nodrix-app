# Nodrix

Nodrix is a Flutter + Node.js backend project for managing ISP subscribers, payments, towers, sectors, links, and future SAS integrations.

## v1.0.6

- UI polish with smaller icons and cleaner button layout.
- PostgreSQL foundation for persistent customers and payments.
- SaaS-ready `company_id` structure.
- No real SAS or WhatsApp integration in this release.

## Backend

```bash
cd backend
npm install
npm run dev
```

Railway should provide `DATABASE_URL` in the backend service variables.

## Mobile

```bash
cd mobile_flutter
flutter pub get
flutter build apk --debug
```

Keep APK files outside the project, e.g. `Desktop/Nodrix-Releases`.


## v1.0.6 - SAS Sync Foundation

- Added SAS synchronization foundation through `/api/sas/sync`.
- Added `/api/sas/status` to inspect sync source and last sync time.
- Added PostgreSQL SAS fields on customers: `sas_id`, `sas_username`, `sas_package`, `sas_status`, `sas_start_date`, `sas_expiry_date`, `sas_phone`, `sas_ip`, `sas_mac`, `source`, `last_synced_at`.
- Dates are now sanitized to prevent invalid date errors.
- Manual date entry was removed from the Flutter customer/payment forms. Dates are expected to come from SAS in future integrations.
- Kept update flow unchanged.

Important: do not commit `package-lock.json` generated with a private registry. This repository includes `.npmrc` pointing to the public npm registry for Railway.
