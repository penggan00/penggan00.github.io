---
layout: blog
title: Blog
permalink: /blog/
---

<div class="search-container">
  <input id="search-input" placeholder="Search articles..." style="width:100%;max-width:800px;padding:9px;font-size:15px;margin-top:6px;margin-bottom:6px">
</div>

<div id="articles" style="margin:0 auto;padding:0 10px;max-width:800px"></div>

<div class="pagination" style="display:flex;justify-content:center;margin:20px 0"></div>

<script>
  // Static articles data (can be moved to external .js file if preferred)
  const articles1 = [
    { title: "无", link: "articles/post/1.html", lastModified: "2024-06-07 21:03:00" }, 
    { title: "Ventoy-PE", link: "articles/post/2.html", lastModified: "2024-06-07 22:30:00" }, 
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "Ventoy-PE", link: "articles/post/2.html", lastModified: "2024-06-07 22:30:00" }, 
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "Ventoy-PE", link: "articles/post/2.html", lastModified: "2024-06-07 22:30:00" }, 
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    { title: "serv00恢复初始", link: "articles/post/3.html", lastModified: "2024-06-06 10:17:00" }
    
  ];

  // Combine Jekyll posts with static articles
  let articles = [
    {% for post in site.posts %}
    {
      title: "{{ post.title | escape }}",
      link: "{{ post.url | relative_url }}",
      lastModified: "{{ post.date | date_to_xmlschema }}"
    }{% unless forloop.last %},{% endunless %}
    {% endfor %}
  ].concat(articles1);

  // Blog functionality
  let currentPage = 1;
  const articlesPerPage = 10;

  function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString("en-CA", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    });
  }

  function displayArticles(filteredArticles, page) {
    const startIndex = (page - 1) * articlesPerPage;
    const paginatedArticles = filteredArticles.slice(startIndex, startIndex + articlesPerPage);
    const articlesContainer = document.getElementById('articles');
    
    articlesContainer.innerHTML = '';
    
    paginatedArticles.forEach(article => {
      const articleElement = document.createElement('div');
      articleElement.className = 'post';
      articleElement.style = "background-color:#fff;margin-bottom:9px;border-radius:5px;box-shadow:0 2px 4px rgba(0,0,0,.1);padding:12px 20px;font-size:1.1em;color:#888;display:flex;justify-content:space-between;align-items:center";
      
      articleElement.innerHTML = `
        <h2 style="font-size:16px;text-align:left;margin:0;padding:0">
          <a href="${article.link}" style="color:#000;text-decoration:none" 
             onmouseover="this.style.textDecoration='underline'" 
             onmouseout="this.style.textDecoration='none'">
            ${article.title}
          </a>
        </h2>
        <span class="timestamp" style="font-size:.7em;color:#888;margin-left:auto;white-space:nowrap">
          ${formatDate(article.lastModified)}
        </span>
      `;
      
      articlesContainer.appendChild(articleElement);
    });
    
    updatePagination(filteredArticles, page);
  }

  function updatePagination(allArticles, currentPage) {
    const totalPages = Math.ceil(allArticles.length / articlesPerPage);
    const paginationContainer = document.querySelector('.pagination');
    
    paginationContainer.innerHTML = '';
    
    // Previous button
    const prevButton = document.createElement('button');
    prevButton.textContent = '<';
    prevButton.onclick = () => {
      if (currentPage > 1) {
        currentPage--;
        displayArticles(allArticles, currentPage);
      }
    };
    paginationContainer.appendChild(prevButton);
    
    // Page numbers
    const maxVisiblePages = 5;
    let startPage = Math.max(1, currentPage - Math.floor(maxVisiblePages / 2));
    let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);
    
    if (endPage - startPage + 1 < maxVisiblePages) {
      startPage = Math.max(1, endPage - maxVisiblePages + 1);
    }
    
    if (startPage > 1) {
      const firstPageButton = document.createElement('button');
      firstPageButton.textContent = '1';
      firstPageButton.onclick = () => displayArticles(allArticles, 1);
      paginationContainer.appendChild(firstPageButton);
      
      if (startPage > 2) {
        const ellipsis = document.createElement('span');
        ellipsis.textContent = '...';
        paginationContainer.appendChild(ellipsis);
      }
    }
    
    for (let i = startPage; i <= endPage; i++) {
      const pageButton = document.createElement('button');
      pageButton.textContent = i;
      if (i === currentPage) {
        pageButton.classList.add('active');
        pageButton.style = "background-color:#000;color:#fff";
      }
      pageButton.onclick = () => displayArticles(allArticles, i);
      paginationContainer.appendChild(pageButton);
    }
    
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        const ellipsis = document.createElement('span');
        ellipsis.textContent = '...';
        paginationContainer.appendChild(ellipsis);
      }
      
      const lastPageButton = document.createElement('button');
      lastPageButton.textContent = totalPages;
      lastPageButton.onclick = () => displayArticles(allArticles, totalPages);
      paginationContainer.appendChild(lastPageButton);
    }
    
    // Next button
    const nextButton = document.createElement('button');
    nextButton.textContent = '>';
    nextButton.onclick = () => {
      if (currentPage < totalPages) {
        currentPage++;
        displayArticles(allArticles, currentPage);
      }
    };
    paginationContainer.appendChild(nextButton);
    
    // Page jump input
    const pageInput = document.createElement('input');
    pageInput.type = 'number';
    pageInput.min = 1;
    pageInput.max = totalPages;
    pageInput.value = currentPage;
    pageInput.style = "width:36px;height:25px;text-align:center;margin-left:3px;position:relative;left:15px";
    pageInput.onchange = (e) => {
      const newPage = parseInt(e.target.value);
      if (newPage >= 1 && newPage <= totalPages) {
        currentPage = newPage;
        displayArticles(allArticles, currentPage);
      } else {
        e.target.value = currentPage;
      }
    };
    paginationContainer.appendChild(pageInput);
  }

  function searchArticles() {
    const searchTerm = document.getElementById('search-input').value.toLowerCase();
    const filteredArticles = articles.filter(article => 
      article.title.toLowerCase().includes(searchTerm)
    );
    currentPage = 1;
    displayArticles(filteredArticles, currentPage);
  }

  // Initialize
  document.addEventListener('DOMContentLoaded', () => {
    displayArticles(articles, 1);
    document.getElementById('search-input').addEventListener('input', searchArticles);
  });
</script>