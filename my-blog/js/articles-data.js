function renderArticleList() {
    const listContainer = document.getElementById('article-list');
    listContainer.innerHTML = ''; // 清空容器
    
    sortedArticles.forEach(article => {
        const articleId = article.link.match(/\/(\d+)\.html$/)[1];
        const listItem = document.createElement('div');
        listItem.className = 'article-item';
        
        listItem.innerHTML = `
            <h3><a href="article.html?id=${articleId}">${article.title}</a></h3>
            <div class="article-meta">
                <span>最后更新: ${formatDate(article.lastModified)}</span>
                <span class="read-time">${getRandomReadTime()}分钟阅读</span>
            </div>
            <p class="article-excerpt">${generateExcerpt(article.title)}</p>
        `;
        
        listContainer.appendChild(listItem);
    });
}

// 辅助函数
function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString();
}

function getRandomReadTime() {
    return Math.floor(Math.random() * 5) + 3; // 3-7分钟
}

function generateExcerpt(title) {
    // 这里可以根据标题生成简短的描述
    return `点击阅读关于${title}的详细内容...`;
}