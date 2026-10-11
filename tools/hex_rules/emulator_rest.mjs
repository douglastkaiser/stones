// Real HTTP requests against the Firestore emulator, using unsigned emulator
// identity tokens. No npm packages or production credentials are required.
import assert from 'node:assert/strict';

const project = 'demo-stones-hex';
const address = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088';
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(address)) {
  throw new Error('Rules tests must run against a loopback emulator');
}
const origin = `http://${address}`;
const documents = `${origin}/v1/projects/${project}/databases/(default)/documents`;

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function token(uid) {
  if (uid == null) return null;
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({sub: uid, user_id: uid,
    aud: project, iss: `https://securetoken.google.com/${project}`,
    iat: now, exp: now + 3600, auth_time: now,
    firebase: {identities: {}, sign_in_provider: 'anonymous'}})}.`;
}
async function request(url, method = 'GET', body, uid) {
  const identity = token(uid);
  const response = await fetch(url, {method, headers: {
    'Content-Type': 'application/json', ...(identity ? {Authorization: `Bearer ${identity}`} : {})
  }, ...(body === undefined ? {} : {body: JSON.stringify(body)})});
  const raw = await response.text();
  if (!response.ok) throw new HttpError(response.status, raw);
  return raw ? JSON.parse(raw) : {};
}
function encode(value) {
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (value === null) return {nullValue: null};
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'number') return {integerValue: String(value)};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item)]))}};
}
function decode(value) {
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(decode);
  if ('mapValue' in value) return Object.fromEntries(Object.entries(value.mapValue.fields ?? {}).map(([key, item]) => [key, decode(item)]));
  throw new Error('Unsupported test value');
}
const fields = value => encode(value).mapValue.fields;
export const doc = (uid, path, code) => ({uid, path: `${path}/${code}`});
export const collection = (uid, path) => ({uid, path});
export const setDoc = (ref, value) => request(`${documents}/${ref.path}`, 'PATCH', {fields: fields(value)}, ref.uid);
export async function getDoc(ref) {
  const result = await request(`${documents}/${ref.path}`, 'GET', undefined, ref.uid);
  return {data: () => decode({mapValue: {fields: result.fields}}), updateTime: result.updateTime};
}
export const getDocs = ref => request(`${documents}/${ref.path}`, 'GET', undefined, ref.uid);
function merge(original, changes) {
  const result = structuredClone(original);
  for (const [path, value] of Object.entries(changes)) {
    const keys = path.split('.');
    let cursor = result;
    for (const key of keys.slice(0, -1)) cursor = cursor[key] ??= {};
    cursor[keys.at(-1)] = value;
  }
  return result;
}
export async function updateDoc(ref, changes) {
  const snapshot = await getDoc(ref);
  return setDoc(ref, merge(snapshot.data(), changes));
}
export async function updateWithServerTime(ref, changes, fieldPath) {
  const snapshot = await getDoc(ref);
  const value = merge(snapshot.data(), changes);
  const paths = Array.isArray(fieldPath) ? fieldPath : [fieldPath];
  for (const path of paths) {
    const keys = path.split('.');
    let cursor = value;
    for (const key of keys.slice(0, -1)) cursor = cursor[key];
    delete cursor[keys.at(-1)];
  }
  return request(`${documents}:commit`, 'POST', {writes: [{
    update: {name: `projects/${project}/databases/(default)/documents/${ref.path}`,
      fields: fields(value)},
    updateTransforms: paths.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
    currentDocument: {updateTime: snapshot.updateTime},
  }]}, ref.uid);
}
export async function runTransaction(uid, callback) {
  for (let attempt = 0; attempt < 10; attempt++) {
    let snapshot, target, changes;
    await callback({get: async ref => {
      target = ref; snapshot = await getDoc(ref); return snapshot;
    }, update: (ref, value) => { target = ref; changes = value; }});
    try {
      return await request(`${documents}:commit`, 'POST', {writes: [{
        update: {name: `projects/${project}/databases/(default)/documents/${target.path}`,
          fields: fields(merge(snapshot.data(), changes))},
        currentDocument: {updateTime: snapshot.updateTime},
      }]}, uid);
    } catch (error) {
      const changed = error.status === 403 &&
        (await getDoc(target)).updateTime !== snapshot.updateTime;
      if ((!changed && ![409, 400].includes(error.status)) || attempt === 9) throw error;
      await new Promise(resolve => setTimeout(resolve, 20));
    }
  }
}
export async function assertFails(operation) {
  await assert.rejects(operation, error => [401, 403].includes(error.status));
}
export const assertSucceeds = operation => operation;

export async function initializeHexEmulator({projectId, firestore}) {
  assert.equal(projectId, project);
  await request(`${origin}/emulator/v1/projects/${project}:securityRules`, 'PUT',
    {rules: {files: [{content: firestore.rules}]}});
  return {
    authenticatedContext: uid => ({firestore: () => uid}),
    unauthenticatedContext: () => ({firestore: () => null}),
    clearFirestore: () => request(`${origin}/emulator/v1/projects/${project}/databases/(default)/documents`, 'DELETE'),
    cleanup: async () => {},
  };
}
