import "server-only";

// Set once per request by the (app) layout so deep components need not
// thread the organisation through props.
let currentOrgId = "";

export function setCurrentOrg(orgId: string) {
  currentOrgId = orgId;
}

export function getCurrentOrg(): string {
  return currentOrgId;
}
