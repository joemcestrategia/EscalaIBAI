export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const targetUrl = req.headers['x-target-url'];
  if (!targetUrl) {
    return res.status(400).send('Missing x-target-url header');
  }

  try {
    const headers = new Headers();
    for (const [key, value] of Object.entries(req.headers)) {
      if (['host', 'connection', 'x-target-url', 'accept-encoding'].includes(key.toLowerCase())) continue;
      headers.set(key, value);
    }
    
    // Set a solid User-Agent to avoid blocks if empty
    if (!headers.has('user-agent')) {
        headers.set('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36');
    }

    const init = {
      method: req.method,
      headers: headers,
    };

    if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
      init.body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    }

    const response = await fetch(targetUrl, init);
    const data = await response.arrayBuffer();

    for (const [key, value] of response.headers) {
      if (['transfer-encoding', 'content-encoding'].includes(key.toLowerCase())) continue;
      res.setHeader(key, value);
    }

    res.status(response.status).send(Buffer.from(data));
  } catch (error) {
    res.status(500).send(error.toString());
  }
}
