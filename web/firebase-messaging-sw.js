// Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB4zR2gH97nx2p34tqNorqKMKwL4OAS9-g',
  authDomain: 'pokefinanzas.firebaseapp.com',
  databaseURL: 'https://pokefinanzas-default-rtdb.europe-west1.firebasedatabase.app',
  projectId: 'pokefinanzas',
  storageBucket: 'pokefinanzas.firebasestorage.app',
  messagingSenderId: '655817236653',
  appId: '1:655817236653:web:1c53e33333333333333333',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message:', payload);

  const notificationTitle = payload.notification?.title || 'PokeFinanzas';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.tag || 'pokefinanzas',
    data: payload.data || {},
    actions: [
      { action: 'open', title: 'Abrir' },
      { action: 'dismiss', title: 'Cerrar' },
    ],
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click:', event);

  event.notification.close();

  if (event.action === 'dismiss') return;

  // Open the app
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If app is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open new window
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

// Handle push events (for custom data)
self.addEventListener('push', (event) => {
  console.log('[firebase-messaging-sw.js] Push received:', event);

  let data = { title: 'PokeFinanzas', body: '' };

  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body || data.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.tag || 'pokefinanzas',
    data: data.data || {},
  };

  event.waitUntil(
    self.registration.showNotification(data.title || data.notification?.title || 'PokeFinanzas', options)
  );
});
