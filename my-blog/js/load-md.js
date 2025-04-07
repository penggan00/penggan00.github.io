async function loadArticle(articleId) {
    // 查找文章 - 现在从合并后的数组中查找
    const articleInfo = allArticles.find(a => {
        const match = a.link.match(/\/(\d+)\.html$/);
        return match && match[1] === articleId;
    });
    
    if (!articleInfo) {
        document.getElementById('article-content').innerHTML = '<p>文章未找到</p>';
        return;
    }

    // 获取文章基本路径（去掉.html）
    const basePath = articleInfo.link.replace('.html', '');
    
    // 尝试加载Markdown版本
    try {
        const mdResponse = await fetch(`${basePath}.md`);
        if (mdResponse.ok) {
            const mdText = await mdResponse.text();
            document.getElementById('article-content').innerHTML = marked.parse(mdText);
            document.title = `${articleInfo.title} - 我的博客`;
            
            // 应用你现有的样式和功能
            if(window.applyPostStyles) applyPostStyles();
            return;
        }
    } catch (e) {
        console.log('Markdown加载失败，尝试HTML版本');
    }

    // 回退到HTML版本
    try {
        const htmlResponse = await fetch(`${basePath}.html`);
        if (htmlResponse.ok) {
            const htmlText = await htmlResponse.text();
            document.getElementById('article-content').innerHTML = htmlText;
            document.title = `${articleInfo.title} - 我的博客`;
            
            // 应用你现有的样式和功能
            if(window.applyPostStyles) applyPostStyles();
        } else {
            throw new Error('HTML版本也不存在');
        }
    } catch (e) {
        document.getElementById('article-content').innerHTML = `
            <div class="error">
                <p>文章加载失败</p>
                <p><a href="/" class="btn">返回首页</a></p>
            </div>
        `;
    }
}