// Push-only registration. No fetch interception or asset caching.
let messaging, registration;
const sdk = 'https://www.gstatic.com/firebasejs/11.9.1/';
const config = {apiKey:'AIzaSyDU8twgc4E0ZR-pcIBHwIqMx0Wdty1_LwM',appId:'1:984712752792:web:eda06c6c598e3971e96aed',messagingSenderId:'984712752792',projectId:'stones-9a6a0'};
async function ready() {
  if (!messaging) {
    const [app, fcm] = await Promise.all([import(sdk+'firebase-app.js'), import(sdk+'firebase-messaging.js')]);
    messaging = {instance:fcm.getMessaging(app.initializeApp(config,'stones-turn-alerts')),fcm};
    registration = await navigator.serviceWorker.register(new URL('turn-push-sw.js',document.baseURI),{scope:new URL('./',document.baseURI).pathname});
    messaging.fcm.onMessage(messaging.instance,payload=>window.dispatchEvent(new CustomEvent('stones-turn-foreground',{detail:JSON.stringify(payload.data)})));
  }
}
window.stonesPush = {
 async permission() {
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform==='MacIntel' && navigator.maxTouchPoints>1);
  if(ios && !navigator.standalone && !matchMedia('(display-mode: standalone)').matches) return 'installRequired';
  if(!('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) return 'unsupported';
  return Notification.permission==='granted'?'enabled':Notification.permission==='denied'?'denied':'available';
 },
 async enable(vapidKey) {
  if(await Notification.requestPermission()!=='granted') return '';
  return this.refresh(vapidKey);
 },
 async refresh(vapidKey) {await ready();return messaging.fcm.getToken(messaging.instance,{vapidKey,serviceWorkerRegistration:registration});},
 async disable() {if(messaging) await messaging.fcm.deleteToken(messaging.instance);},
 async bind(uid) {
  await ready();
  const worker=registration.active || registration.waiting || registration.installing;
  if(worker) worker.postMessage({type:'stones-bind',uid});
 }
};
navigator.serviceWorker?.addEventListener('message',event=>{
 if(event.data?.type==='stones-turn-open') window.dispatchEvent(new CustomEvent('stones-turn-open',{detail:JSON.stringify(event.data.data)}));
});
