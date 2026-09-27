import { LoginPage } from './pages/LoginPage.js';
import { SignupPage } from './pages/SignupPage.js';
import { SchedulePage } from './pages/SchedulePage.js';
import { MembersPage } from './pages/MembersPage.js';
import { BillingPage } from './pages/BillingPage.js';

// Client routes. Anything signed-in lives under the app shell (top bar with
// the workspace name, left nav: Schedule, Members, Billing).
export const ROUTES = [
  { path: '/login', page: LoginPage, public: true },
  { path: '/signup', page: SignupPage, public: true },
  { path: '/schedule', page: SchedulePage },
  { path: '/settings/members', page: MembersPage, adminOnlyControls: true },
  { path: '/settings/billing', page: BillingPage, adminOnly: true },
];
