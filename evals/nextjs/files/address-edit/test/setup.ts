// Test values so modules that read lib/env.server.ts load under vitest.
// Real values live in .env.local and never in the repository.
process.env.API_TOKEN ??= "test-token";
process.env.SESSION_SECRET ??= "test-session-secret-of-32-characters";
