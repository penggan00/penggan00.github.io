addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
    const url = new URL(request.url);
    url.hostname = 'epg.112114.xyz/pp.xml'; // 替换为你想要代理的网站
    
    // 创建新的请求，保留请求方法和请求头
    const modifiedRequest = new Request(url, {
        method: request.method,
        headers: request.headers,
        body: request.body,
        redirect: 'follow'
    });

    // 发出请求并返回响应
    return fetch(modifiedRequest);
}