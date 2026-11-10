const staffPlanTerms = Object.freeze({
  Monthly: { price: 800, days: 30 },
  'Half Month': { price: 400, days: 15 },
  'Walk-in': { price: 80, days: 1 },
});

export function isValidDateOnly(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

export function manilaBusinessDate(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en', {
    timeZone: 'Asia/Manila', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now);
  return ['year', 'month', 'day'].map(type => parts.find(part => part.type === type).value).join('-');
}

export function addDateOnlyDays(dateOnly, days) {
  if (!isValidDateOnly(dateOnly) || !Number.isInteger(days)) return null;
  const [year, month, day] = dateOnly.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

export function validateStaffMembershipTerms({ plan, price, startDate, expiryDate, now = new Date() }) {
  const terms = staffPlanTerms[plan];
  const today = manilaBusinessDate(now);
  return Boolean(terms)
    && Number(price) === terms.price
    && startDate === today
    && expiryDate === addDateOnlyDays(today, terms.days);
}
