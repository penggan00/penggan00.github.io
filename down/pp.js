addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = 'https://epg.112114.xyz/pp.xml';  // 要抓取的网页URL
  const response = await fetch(url);
  if (response.ok) {
      const text = await response.text();
      // 在这里解析HTML并提取内容
      const content = extractContent(text);
      return new Response(content, {
          headers: { 'content-type': 'text/plain' },
      });
  } else {
      return new Response('Failed to fetch the webpage', { status: 500 });
  }
}

function extractContent(html) {
  // 简单示例：使用正则表达式提取<div id="content">中的内容
  const match = html.match(/<div id="content">([^<]+)<\/div>/);
  return match ? match[1] : 'Content not found';
}
