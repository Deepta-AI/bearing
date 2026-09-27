export async function signUp(db, analytics, { email, phone, requestId }) {
  const user = await db.createUser({ email, phone });
  analytics.identify(user.id);
  analytics.track('signed_up', { method: email ? 'email' : 'phone', email }, { userId: user.id, requestId });
  return user;
}
