require('http').createServer((q, r) => {
  if (!/^\/api\/pc\/overview/.test(q.url) || !/Bearer tnbc-/.test(q.headers.authorization || '')) { r.writeHead(401); return r.end('{}'); }
  r.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
  r.end(JSON.stringify({ at: new Date().toISOString(),
    audio: { waiting: 11, next: ['Jonah 2 - The Prayer From the Fish', 'Jonah 3 - A Second Chance', 'Ruth - Redeemed and Restored, Pt. 3', 'The Sermon on the Mount, Pt. 12', 'Mark 1'], making: ['Ruth - Redeemed and Restored, Pt. 4'], failed: 0 },
    reels: { toMake: { count: 2, items: ['Reel #4 · Faith That Works', 'Captions · Hope Anchored'] }, making: { count: 1, items: ['Reel #3 · Faith That Works'] }, failed: 0 },
    posts: { toMake: { count: 0, items: [] }, making: { count: 0, items: [] }, failed: 0 },
    facebook: { waiting: { count: 1, items: ['Ruth - Redeemed and Restored, Pt. 4'] }, making: { count: 0, items: [] } },
    review: { reels: { count: 2, items: ['Reel #1 · Faith That Works', 'Reel #2 · Faith That Works'] }, posts: { count: 1, items: ['Question carousel · 2026-11-10'] } },
    approved: 4 }));
}).listen(8787, '127.0.0.1');
