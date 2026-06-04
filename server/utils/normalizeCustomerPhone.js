/**
 * Normalize pasted or stored phone values to a 10-digit Indian mobile string (no country prefix).
 */
export function normalizeCustomerPhone(raw) {
  let s = String(raw ?? "").trim();
  s = s.replace(/^(\+91|0091|\+)/i, "");
  s = s.replace(/\D/g, "");
  if (s.length === 12 && s.startsWith("91")) s = s.slice(2);
  if (s.length === 11 && s.startsWith("0")) s = s.slice(1);
  return s;
}

export function isValidIndianMobile(digits) {
  return /^[6-9]\d{9}$/.test(digits);
}
