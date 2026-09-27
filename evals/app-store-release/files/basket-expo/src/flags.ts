// Feature flags compiled into the build. Server config can turn a flag on
// later; a flag that is false here ships dark.
export const flags = {
  barcodeScan: true,
  // Shared lists ship dark in 2.4.0; the sync backend goes live with 2.5.
  sharedLists: false,
  nearbySortByDistance: true,
};
