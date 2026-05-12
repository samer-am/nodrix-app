function readPath(input, path) {
  let current = input;
  for (const part of path.split('.')) {
    if (current === null || current === undefined) return undefined;
    current = current[part];
  }
  return current;
}

export function firstValue(input, keys) {
  for (const key of keys) {
    const value = key.includes('.') ? readPath(input, key) : input?.[key];
    const text = String(value ?? '').trim();
    if (text && text !== 'null' && text !== 'undefined' && text !== '—') return value;
  }
  return '';
}

export function firstIp(input) {
  return String(firstValue(input, [
    'ip',
    'user_ip',
    'current_ip',
    'framed_ip',
    'framed_ip_address',
    'framedIPAddress',
    'Framed-IP-Address',
    'framedipaddress',
    'address',
    'remote_address',
    'lastip',
    'last_ip',
    'ipaddr',
    'ipAddress',
    'remote.ip',
    'sta_ip',
    'online_details.framedipaddress',
    'last_session_details.framedipaddress',
  ]) || '').trim();
}

export function firstMac(input) {
  return String(firstValue(input, [
    'mac',
    'mac_address',
    'calling_station_id',
    'Calling-Station-Id',
    'callingstationid',
    'online_details.callingstationid',
    'last_session_details.callingstationid',
  ]) || '').trim();
}

export function mapSasManagerUser(raw) {
  const first = String(firstValue(raw, ['firstname', 'first_name', 'user_details.firstname']) || '').trim();
  const last = String(firstValue(raw, ['lastname', 'last_name', 'user_details.lastname']) || '').trim();
  const fullName = String(firstValue(raw, ['full_name', 'name']) || `${first} ${last}`.trim()).trim();
  const statusRaw = firstValue(raw, ['status', 'status.status', 'enable', 'enabled']);
  const remainingDays = Number(firstValue(raw, ['remaining_days']));
  const onlineStatus = Number(firstValue(raw, ['online_status']));
  return {
    username: String(firstValue(raw, ['username', 'user_details.username']) || '').trim(),
    fullName,
    phone: String(firstValue(raw, ['phone', 'mobile', 'user_details.phone']) || '').trim(),
    profile: String(firstValue(raw, ['profile_details.name', 'user_profile_name', 'profile_name', 'name']) || '').trim(),
    status: Number(statusRaw) === 0 ? 'paused' : remainingDays <= 0 ? 'expired' : 'active',
    expiration: String(firstValue(raw, ['expiration', 'user_details.expiration', 'expiresAt']) || '').trim(),
    balance: Number(firstValue(raw, ['balance', 'loan_balance']) || 0),
    debt: Number(firstValue(raw, ['debt', 'debt_days', 'loan_balance']) || 0),
    online: onlineStatus === 1,
    currentIp: firstIp(raw),
    mac: firstMac(raw),
    nasName: String(firstValue(raw, ['nas_name', 'nas_details.shortname', 'nasipaddress']) || '').trim(),
    lastSeen: String(firstValue(raw, ['last_online', 'acctstarttime']) || '').trim(),
    raw,
  };
}

export function mapSasManagerOnlineUser(raw) {
  return {
    username: String(firstValue(raw, ['username', 'user_details.username']) || '').trim(),
    fullName: String(firstValue(raw, ['name', 'full_name']) || '').trim(),
    ip: firstIp(raw),
    framedIpAddress: String(firstValue(raw, ['framedipaddress', 'framed_ip_address']) || '').trim(),
    nasIp: String(firstValue(raw, ['nasipaddress', 'nas_ip_address']) || '').trim(),
    nasName: String(firstValue(raw, ['nas_details.shortname', 'nas_name']) || '').trim(),
    macAddress: firstMac(raw),
    callingStationId: String(firstValue(raw, ['callingstationid', 'calling_station_id']) || '').trim(),
    sessionId: String(firstValue(raw, ['radacctid', 'acctsessionid', 'session_id']) || '').trim(),
    sessionStart: String(firstValue(raw, ['acctstarttime', 'session_start']) || '').trim(),
    upload: Number(firstValue(raw, ['acctinputoctets', 'upload']) || 0),
    download: Number(firstValue(raw, ['acctoutputoctets', 'download']) || 0),
    uptime: String(firstValue(raw, ['acctsessiontime', 'uptime']) || '').trim(),
    raw,
  };
}
