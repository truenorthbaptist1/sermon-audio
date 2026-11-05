const http = require('http'); const fs = require('fs'); const path = require('path'); let got = [];
const field = (s, n) => { const m = s.match(new RegExp('name="?' + n + '"?\\r\\n(?:[^\\r]*\\r\\n)*\\r\\n([^\\r]*)')); return m ? m[1] : null; };
let size = 0, received = 0; const CH = 1 << 20;
http.createServer((req, res) => { const parts = []; req.on('data', (d) => parts.push(d)); req.on('end', () => {
  const buf = Buffer.concat(parts); const s = buf.toString('latin1');
  const log = (x) => { got.push(req.method + ' ' + req.url.split('?')[0] + ' ' + x); fs.writeFileSync('got.txt', got.join('\n')); };
  const json = (o) => { res.setHeader('content-type', 'application/json'); res.end(JSON.stringify(o)); };
  if (req.url === '/ping') return res.end('ok');
  if (req.url.includes('maxresdefault')) { log('404'); res.statusCode = 404; return res.end('no'); }
  if (req.url.includes('hq720')) { log('thumb'); return res.end(fs.readFileSync(__dirname + '/thumb.jpg')); }
  if (req.url === '/logo.png') return res.end(fs.readFileSync(__dirname + '/logo.png'));
  if (req.url.startsWith('/fonts/')) return res.end(fs.readFileSync(path.join(__dirname, '..', 'reels', 'fonts', path.basename(req.url))));
  if (req.url.endsWith('/PAGE/videos')) {
    if (field(s, 'access_token') !== 'ptok') { res.statusCode = 400; return json({ error: { message: 'bad token' } }); }
    const phase = field(s, 'upload_phase');
    if (phase === 'start') { size = +field(s, 'file_size'); log('start ' + size); return json({ video_id: 'FBV1', upload_session_id: 'S1', start_offset: '0', end_offset: String(Math.min(CH, size)) }); }
    if (phase === 'transfer') {
      const b = s.match(/boundary=?([^\r\n;]*)/) ; const ct = req.headers['content-type']; const bd = '--' + ct.split('boundary=')[1].replace(/"/g, '');
      const i = s.indexOf('name="video_file_chunk"'); const st = s.indexOf('\r\n\r\n', i) + 4; const en = s.indexOf('\r\n' + bd, st);
      const from = +field(s, 'start_offset'); received += en - st; const next = from + (en - st);
      log('transfer ' + from + ' ' + (en - st));
      return json({ start_offset: String(next), end_offset: String(Math.min(next + CH, size)) });
    }
    if (phase === 'finish') { log('finish title=' + JSON.stringify(Buffer.from(field(s, 'title'), 'latin1').toString('utf8')) + ' received=' + received + ' size=' + size + ' desc=' + (s.includes('truenorthbaptist.com/listen') ? 'listen' : 'none')); return json({ success: true }); }
  }
  if (req.url.endsWith('/FBV1/thumbnails')) { log('thumbnail ' + (s.includes('name="is_preferred"') ? 'preferred' : '') + ' ' + buf.length); return json({ success: true }); }
  if (req.url === '/api/fbvideo/done') { log('done ' + s); return json({ ok: true }); }
  log('other'); json({ ok: true });
}); }).listen(8787);
