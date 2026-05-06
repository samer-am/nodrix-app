# Nodrix

Nodrix is a starter UI/UX build for an ISP/SAS management app.

## Structure

```text
backend/          Node.js Express API
mobile_flutter/   Flutter app
package.json      Root package for Railway deployment
railway.json      Railway deployment config
```

## Backend local run

From the project root:

```cmd
npm install
copy backend\.env.example .env
npm run dev
```

Or from the backend folder:

```cmd
cd backend
npm install
copy .env.example .env
npm run dev
```

Health check:

```text
http://localhost:3000/health
```

## Flutter local run

```cmd
cd mobile_flutter
flutter create .
flutter pub get
flutter run -d edge
```

Demo credentials inside the app:

```text
Backend URL: http://localhost:3000
SAS Type: mock
SAS URL: https://demo.local
Username: admin
Password: admin123
```

## Railway deployment

This zip includes a root `package.json` and `railway.json`, so Railway can deploy directly from the repository root.

Use:

```text
Build: automatic
Start command: npm start
Health check: /health
```

If you prefer Railway root directory settings, set:

```text
Root Directory: backend
Start Command: npm start
```

But with the root files included, this is optional.

Environment variables on Railway:

```text
APP_SECRET=change-this-secret
```

Do not set `PORT` manually on Railway unless Railway requires it. The server uses `process.env.PORT` automatically.

After Railway gives you a public URL, use it in the app as `Backend URL`.

## Build Android APK

Inside `mobile_flutter`:

```cmd
flutter create .
flutter pub get
flutter build apk --debug
```

APK output:

```text
mobile_flutter\build\app\outputs\flutter-apk\app-debug.apk
```
