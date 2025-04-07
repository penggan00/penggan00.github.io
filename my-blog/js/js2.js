// 合并所有文章数组
const allArticles = [...articles1, ...articles2];

// 过滤掉标题为"无"的文章
const filteredArticles = allArticles.filter(article => article.title !== "无");

// 按最后修改日期降序排序
const sortedArticles = filteredArticles.sort((a, b) => 
    new Date(b.lastModified) - new Date(a.lastModified));