importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC89dCMuTOETtpjJbGj2ZvVA6tdvGaxzZY',
  appId: '1:453696388011:web:089e90e69035e8cee3f0ee',
  messagingSenderId: '453696388011',
  projectId: 'vista-jklu',
  authDomain: 'vista-jklu.firebaseapp.com',
  storageBucket: 'vista-jklu.firebasestorage.app',
  measurementId: 'G-F4L0EFZCDS',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
