export const SAS_MANAGER_ENDPOINT_NAMES = {
  login: 'login',
  dashboard: 'dashboard',
  users: 'users',
  userDetails: 'user_details',
  onlineUsers: 'online_users',
  activeSessions: 'active_sessions',
  userSessions: 'user_sessions',
  profiles: 'profiles',
  invoices: 'invoices',
  payments: 'payments',
  debtsJournal: 'debts_journal',
  userAuthLog: 'user_auth_log',
  managers: 'managers',
  nas: 'nas',
};

export const SAS_MANAGER_AUTH_TYPES = {
  bearer: 'bearer',
  cookie: 'cookie',
  csrfCookie: 'csrf_cookie',
  unknown: 'unknown',
};

export const DEFAULT_SAS_MANAGER_ENDPOINTS = [
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.login,
    urlPath: 'login',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.unknown,
    purpose: 'Authenticate manager credentials and receive a token/session.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.users,
    urlPath: 'index/user',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch manager users list.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.onlineUsers,
    urlPath: 'index/online',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch online users and current Framed-IP-Address.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.userSessions,
    urlPath: 'index/UserSessions',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch accounting/session history and last known IP.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.userAuthLog,
    urlPath: 'index/userauthlog',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch user authentication logs.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.managers,
    urlPath: 'index/manager',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch managers list.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.profiles,
    urlPath: 'index/profile',
    method: 'POST',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch profiles/packages list when available.',
  },
  {
    name: SAS_MANAGER_ENDPOINT_NAMES.nas,
    urlPath: 'nas',
    method: 'GET',
    authType: SAS_MANAGER_AUTH_TYPES.bearer,
    purpose: 'Fetch NAS/routers metadata when available.',
  },
];
