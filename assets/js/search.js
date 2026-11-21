/* Site search box: submits the footer search form to /search?query=... */
(function () {
  'use strict';

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('form.search').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        var input = form.querySelector('.search-box');
        var query = input ? input.value.trim() : '';
        if (query) {
          window.location.href = '/search/?query=' + encodeURIComponent(query);
        }
      });
    });
  });
})();
