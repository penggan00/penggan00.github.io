document.getElementById('search-input').addEventListener('input', function() {
    const term = this.value.toLowerCase();
    const results = articles.filter(post => 
      post.title.toLowerCase().includes(term)
    );
    renderArticles(results);
  });
  
  function renderArticles(articles) {
    const container = document.getElementById('articles');
    container.innerHTML = articles.map(post => `
      <div class="post">
        <h2><a href="${post.link}">${post.title}</a></h2>
        <span class="timestamp">${formatDate(post.lastModified)}</span>
      </div>
    `).join('');
  }
  
  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString("en-CA", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    });
  }