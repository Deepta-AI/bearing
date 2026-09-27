// User records for inspectors. Kept in memory until the database lands.

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function normaliseEmail(raw) {
  const email = String(raw || "").trim().toLowerCase();
  if (!EMAIL.test(email)) {
    throw new Error(`invalid email: ${raw}`);
  }
  return email;
}

export function createUser(store, { email, name }) {
  const key = normaliseEmail(email);
  if (store.has(key)) {
    throw new Error(`user exists: ${key}`);
  }
  const user = { email: key, name: String(name || "").trim() };
  store.set(key, user);
  return user;
}
