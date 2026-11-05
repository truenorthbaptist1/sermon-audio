const http = require('http'); const fs = require('fs'); let got = [];
http.createServer((req, res) => { let n = 0; req.on('data', (d) => (n += d.length)); req.on('end', () => { got.push(req.method + ' ' + req.url + ' ' + n + ' ' + req.headers['content-type']); fs.writeFileSync('got.txt', got.join('\n'));
  if (req.url.includes('maxresdefault')) { res.statusCode = 404; return res.end('no'); }
  if (req.url.includes('hq720')) { res.setHeader('content-type', 'image/jpeg'); return res.end(fs.readFileSync(__dirname + '/thumb.jpg')); }
  res.setHeader('content-type', 'application/json'); res.end('{"ok":true}'); }); }).listen(8787);
