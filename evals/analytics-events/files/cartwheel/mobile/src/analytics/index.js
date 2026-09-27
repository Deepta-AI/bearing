import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import { APP_VERSION, COLLECTOR_URL } from '../config';

const QUEUE_KEY = 'analytics.queue';
let consent = false;

export function setConsent(value) {
  consent = value;
}

// Queues the event and flushes when online. Dropped before consent.
export async function track(event, props = {}) {
  if (!consent) return;
  const queue = JSON.parse((await AsyncStorage.getItem(QUEUE_KEY)) ?? '[]');
  queue.push({ event, props, context: { platform: Platform.OS, app_version: APP_VERSION }, sent_at: new Date().toISOString() });
  await AsyncStorage.setItem(QUEUE_KEY, JSON.stringify(queue.slice(-500)));
  flush();
}

export function screen(name) {
  return track('screen_viewed', { screen: name });
}

async function flush() {
  const queue = JSON.parse((await AsyncStorage.getItem(QUEUE_KEY)) ?? '[]');
  if (!queue.length) return;
  try {
    await fetch(COLLECTOR_URL, { method: 'POST', body: JSON.stringify(queue) });
    await AsyncStorage.setItem(QUEUE_KEY, '[]');
  } catch {
    // stays queued
  }
}
