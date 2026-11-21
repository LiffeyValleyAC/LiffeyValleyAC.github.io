/* Search results page: builds the lunr index over search.json and renders hits. */
(function () {
  'use strict';

  function getParameterByName(name) {
    var match = new RegExp('[?&]' + name + '=([^&#]*)').exec(window.location.search);
    return match === null ? '' : decodeURIComponent(match[1].replace(/\+/g, ' '));
  }

  function el(tag, className, html) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (html) node.innerHTML = html;
    return node;
  }

  function renderTypeLabel(item) {
    if (item.type === 'race') {
      return '<span class="result-label label-race">Race Results</span>';
    }
    return '<span class="result-label label-news">News Item</span>';
  }

  document.addEventListener('DOMContentLoaded', function () {
    var resultsEl = document.querySelector('.search-results');
    var countEl = document.querySelector('.search-results-count');
    if (!resultsEl) {
      return;
    }

    var query = getParameterByName('query');
    var heading = document.querySelector('.content h3');
    if (heading && query) {
      heading.append(' for "' + query + '"');
    }

    fetch('/search.json')
      .then(function (response) { return response.json(); })
      .then(function (data) {
        var items = Object.keys(data).map(function (key) {
          data[key].id = key;
          return data[key];
        });

        var searchIndex = lunr(function () {
          this.field('title');
          this.field('content');
          this.field('results');
          this.ref('id');
          // lunr 2.x: documents are added inside the builder callback.
          items.forEach(function (item) { this.add(item); }, this);
        });

        var hits = searchIndex.search(query);
        // Latest first: sort matched items by date, relevance as tiebreaker
        hits.sort(function (a, b) {
          var ta = data[a.ref].date_ts || 0;
          var tb = data[b.ref].date_ts || 0;
          return tb - ta || b.score - a.score;
        });
        if (countEl) {
          countEl.textContent = hits.length === 1
            ? '1 result found'
            : hits.length + ' results found';
        }

        hits.forEach(function (hit) {
          var item = data[hit.ref];
          var li = el('li', null,
            '<h4>' + renderTypeLabel(item) +
            ' <a href="' + item.url + '">' + item.title + '</a>' +
            '<br><small>' + (item.date || '') + '</small></h4>' +
            (item.excerpt || '') +
            '<hr>');
          resultsEl.appendChild(li);
        });

        if (hits.length === 0) {
          resultsEl.appendChild(el('li', null, '<p>No results found.</p>'));
        }
      });
  });
})();
