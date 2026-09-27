import { getCustomer, pageCustomers } from '../customers/service.ts';
import { pageParams } from '../pagination.ts';
import type { Route } from '../router.ts';
import { idParam } from '../validate.ts';

/** GET /customers and GET /customers/:id. */
export const customerRoutes: Route[] = [
  {
    method: 'GET',
    pattern: '/customers',
    handle: ({ db, accountId, query }) => {
      const { limit, after } = pageParams(query);
      return { status: 200, body: pageCustomers(db, accountId, limit, after) };
    },
  },
  {
    method: 'GET',
    pattern: '/customers/:id',
    handle: ({ db, accountId, params }) => {
      const id = idParam(params.id ?? '', 'id');
      return { status: 200, body: getCustomer(db, accountId, id) };
    },
  },
];
