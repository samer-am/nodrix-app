# Nodrix

Nodrix is a starter network/SAS management app.

## Structure

- `backend/` Node.js Express API
- `mobile_flutter/` Flutter mobile app

## Railway deployment

Railway should deploy from the repository root. The root `package.json` starts the backend with:

```bash
npm start
```

Health endpoint:

```text
/health
```

Expected response:

```json
{"ok":true,"service":"Nodrix Backend"}
```

Important: this package intentionally does **not** include a `railway.json` region or multi-region configuration. If Railway shows an error about `CONFIGURE_NETWORK` and invalid region `ams`, remove the multi-region/network region setting from the Railway service dashboard, then redeploy.

## Local backend

```bash
npm install
npm start
```

or:

```bash
cd backend
npm install
npm start
```
