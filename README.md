# Nodrix

Nodrix is a Flutter + Node.js backend project for managing ISP subscribers, payments, towers, sectors, links, and future SAS integrations.

## v1.0.5

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
