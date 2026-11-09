importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');
firebase.initializeApp({apiKey:'AIzaSyDU8twgc4E0ZR-pcIBHwIqMx0Wdty1_LwM',appId:'1:984712752792:web:eda06c6c598e3971e96aed',messagingSenderId:'984712752792',projectId:'stones-9a6a0'});
function binding(value) {
 return new Promise((resolve,reject)=>{
  const request=indexedDB.open('stones-turn-push',1);
  request.onupgradeneeded=()=>request.result.createObjectStore('binding');
  request.onerror=()=>reject(request.error);
  request.onsuccess=()=>{
   const db=request.result, tx=db.transaction('binding',value===undefined?'readonly':'readwrite');
   const op=value===undefined?tx.objectStore('binding').get('uid'):tx.objectStore('binding').put(value,'uid');
   tx.oncomplete=()=>{resolve(op.result);db.close();};tx.onerror=()=>{reject(tx.error);db.close();};
  };
 });
}
self.addEventListener('message',event=>{if(event.data?.type==='stones-bind')event.waitUntil(binding(event.data.uid));});
firebase.messaging().onBackgroundMessage(async payload=>{
 const data=payload.data||{};
 if(!data.uid || data.uid!==await binding())return;
 await self.registration.showNotification('Stones',{body:'It’s your turn in Stones.',tag:'stones-turn-'+data.code,data});
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 const data=event.notification.data;
 event.waitUntil((async()=>{
  if(data.uid!==await binding() || !/^([UH][A-Z]{6}|[A-Z]{6})$/.test(data.code))return;
  const url=new URL('./',self.registration.scope);url.searchParams.set('room',data.code);url.searchParams.set('resume','1');
  await self.clients.openWindow(url.href);
 })());
});
