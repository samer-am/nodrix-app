# SAS Manager Endpoints

This document records endpoints discovered from the UniqueFi/SAS Manager UI and public Angular bundle. Sensitive values such as passwords, tokens, cookies, and CSRF values must never be pasted here.

## Discovery Status

The in-app browser was open on `https://admin.uniquefi.net/#/dashboard`. The visible Manager navigation confirms these sections:

- Dashboard
- Users List
- Online Users
- Managers
- Profiles list
- Pricing list
- User Invoices
- Reports: Activations, Debts Journal, Managers Journal, Profits, Sessions, Users
- Logs: System Log, User Auth Log
- Tools: Import Data

PowerShell access to the root HTML is blocked by Cloudflare, so request payloads should still be verified later by HAR/cURL export from DevTools. The endpoints below are currently marked as discovered from UI route names and the previously inspected Angular bundle.

## Endpoint Records

### login

```ts
SasDiscoveredEndpoint {
  name: "login"
  url: "/admin/api/index.php/api/login"
  method: "POST"
  authType: "unknown"
  requiredHeaders: ["Content-Type: application/json", "Accept: application/json"]
  requestBodyExample: { payload: "<encrypted login payload>" }
  responseExample: { status: 200, token: "<redacted>" }
  purpose: "Manager authentication"
  notes: "Payload is CryptoJS AES encrypted by the Manager app. Token value must not be logged."
}
```

### users

```ts
SasDiscoveredEndpoint {
  name: "users"
  url: "/admin/api/index.php/api/index/user"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 10, direction: "asc", sortBy: "username", search: "", columns: [] }
  responseExample: { data: [], total: 0, last_page: 1 }
  purpose: "Users list and subscriber fields"
  notes: "Known fields include username, firstname, lastname, expiration, profile details, debt_days, remaining_days, online_status, static_ip."
}
```

### online_users

```ts
SasDiscoveredEndpoint {
  name: "online_users"
  url: "/admin/api/index.php/api/index/online"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "asc", sortBy: "username", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Online users and current IP"
  notes: "Current IP is usually framedipaddress. MAC is callingstationid."
}
```

### user_sessions

```ts
SasDiscoveredEndpoint {
  name: "user_sessions"
  url: "/admin/api/index.php/api/index/UserSessions"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "desc", sortBy: "acctstarttime", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Accounting sessions and last known IP"
  notes: "Known fields include username, framedipaddress, callingstationid, nasipaddress, acctstarttime, acctstoptime, upload/download."
}
```

### user_sessions_by_user

```ts
SasDiscoveredEndpoint {
  name: "user_sessions_by_user"
  url: "/admin/api/index.php/api/index/UserSessions/:id"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "desc", sortBy: "acctstarttime", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Specific user session history"
  notes: "The route expects SAS internal user id, not always username."
}
```

### user_auth_log

```ts
SasDiscoveredEndpoint {
  name: "user_auth_log"
  url: "/admin/api/index.php/api/index/userauthlog"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "desc", sortBy: "created_at", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Authentication log and possible IP/MAC fallback"
  notes: "Known fields include nas_ip_address and mac."
}
```

### managers

```ts
SasDiscoveredEndpoint {
  name: "managers"
  url: "/admin/api/index.php/api/index/manager"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "asc", sortBy: "username", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Managers list"
  notes: "Useful for phase 6 permissions later."
}
```

### profiles

```ts
SasDiscoveredEndpoint {
  name: "profiles"
  url: "/admin/api/index.php/api/index/profile"
  method: "POST"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: { page: 1, count: 100, direction: "asc", sortBy: "name", search: "", columns: [] }
  responseExample: { data: [] }
  purpose: "Profiles/packages"
  notes: "Needs HAR confirmation for the exact path on this installation."
}
```

### nas

```ts
SasDiscoveredEndpoint {
  name: "nas"
  url: "/admin/api/index.php/api/nas"
  method: "GET"
  authType: "bearer"
  requiredHeaders: ["Authorization: Bearer <redacted>"]
  requestBodyExample: null
  responseExample: { data: [] }
  purpose: "NAS/routers metadata"
  notes: "Seen in Manager bundle as api.get(\"nas\")."
}
```

## Not Yet Confirmed

- Dashboard data endpoint
- User invoices endpoint payload
- Payments endpoint payload
- Balance endpoint payload
- Native subscriber login endpoint
- Exact profile/pricing endpoint path on this deployment

If DevTools HAR or cURL is available later, paste only sanitized request structure and never include cookies/tokens/passwords.
