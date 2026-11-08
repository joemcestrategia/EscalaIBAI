/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB5erslXyqBbJdvhRsb5bT5H116XU7KDKE',
  authDomain: 'escalaibai.firebaseapp.com',
  projectId: 'escalaibai',
  storageBucket: 'escalaibai.firebasestorage.app',
  messagingSenderId: '927407539645',
  appId: '1:927407539645:web:777b7e5bdd70b7bc523ed4',
});

const messaging = firebase.messaging();

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Fallback para mensagens data-only (quando o payload não traz bloco `notification`).
// Quando o payload já contém `notification`, o Firebase Messaging SDK exibe automaticamente.
messaging.onBackgroundMessage((payload) => {
  if (!payload || payload.notification || !payload.data) {
    return;
  }

  const title = payload.data.title || payload.data.titulo || 'Escala IBAI';
  const body = payload.data.body || payload.data.corpo || '';
  const options = {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: {
      ...payload.data,
      url: payload.data.url || '/',
    },
  };

  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl =
    (event.notification.data &&
      (event.notification.data.url ||
        (event.notification.data.FCM_MSG &&
          event.notification.data.FCM_MSG.fcmOptions &&
          event.notification.data.FCM_MSG.fcmOptions.link))) ||
    '/';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(targetUrl);
        }
      })
  );
});

