export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const query = req.query.q || req.query.query;
  if (!query || query.trim() === '') {
    return res.status(200).json([]);
  }

  try {
    const url = 'https://www.youtube.com/youtubei/v1/search?prettyPrint=false';
    const body = {
      context: {
        client: {
          clientName: 'WEB',
          clientVersion: '2.20231201.00.00',
          hl: 'pt',
          gl: 'BR',
        }
      },
      query: query.trim()
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      return res.status(response.status).json({ error: 'Erro ao consultar YouTube' });
    }

    const json = await response.json();
    const results = [];

    const contents = json.contents?.twoColumnSearchResultsRenderer?.primaryContents?.sectionListRenderer?.contents;
    if (contents) {
      for (const section of contents) {
        const items = section.itemSectionRenderer?.contents;
        if (items) {
          for (const item of items) {
            const video = item.videoRenderer;
            if (video && video.videoId) {
              const title = video.title?.runs?.map(r => r.text).join('') || '';
              const author = video.ownerText?.runs?.map(r => r.text).join('') || '';
              const duration = video.lengthText?.simpleText || '';
              results.push({
                title,
                author,
                url: `https://www.youtube.com/watch?v=${video.videoId}`,
                duration
              });
              if (results.length >= 15) break;
            }
          }
        }
        if (results.length >= 15) break;
      }
    }

    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate');
    return res.status(200).json(results);
  } catch (error) {
    return res.status(500).json({ error: error.toString() });
  }
}
