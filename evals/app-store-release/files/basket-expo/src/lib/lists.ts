import { getJson } from './api';
import { getToken } from './session';

export async function addItemByBarcode(listId: string, barcode: string) {
  return getJson(`/v1/lists/${listId}/items/by-barcode/${encodeURIComponent(barcode)}`, await getToken());
}
