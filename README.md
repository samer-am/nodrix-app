# Nodrix

Nodrix is a starter UI/UX build for an ISP/SAS management app.

## Structure

```text
backend/          Node.js Express API
mobile_flutter/   Flutter app
```

## Backend local run

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

Deploy the `backend` folder as the Railway service root.

Start command:

```cmd
npm start
```

Environment variables:

```text
PORT=3000
APP_SECRET=change-this-secret
```

After Railway gives you a public URL, use it in the app as `Backend URL`.
