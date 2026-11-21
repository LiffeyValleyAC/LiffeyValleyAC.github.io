/* Lightbox for photo albums.
   Intercepts clicks on .photo-item links (full-size images) and shows them
   in an overlay with keyboard support: Esc closes, arrows navigate. */
(function () {
  'use strict';

  var overlay, img, counter, currentIndex;
  var links = [];

  function build() {
    overlay = document.createElement('div');
    overlay.className = 'lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Photo viewer');
    overlay.innerHTML =
      '<button type="button" class="lightbox-close" aria-label="Close">&times;</button>' +
      '<button type="button" class="lightbox-nav lightbox-prev" aria-label="Previous photo">&#8249;</button>' +
      '<button type="button" class="lightbox-nav lightbox-next" aria-label="Next photo">&#8250;</button>' +
      '<img src="" alt="">' +
      '<div class="lightbox-counter"></div>';
    document.body.appendChild(overlay);

    img = overlay.querySelector('img');
    counter = overlay.querySelector('.lightbox-counter');

    overlay.addEventListener('click', function (event) {
      if (event.target === overlay || event.target.classList.contains('lightbox-close')) {
        close();
      } else if (event.target.classList.contains('lightbox-prev')) {
        show(currentIndex - 1);
      } else if (event.target.classList.contains('lightbox-next')) {
        show(currentIndex + 1);
      }
    });

    document.addEventListener('keydown', function (event) {
      if (!overlay.classList.contains('open')) return;
      if (event.key === 'Escape') close();
      else if (event.key === 'ArrowLeft') show(currentIndex - 1);
      else if (event.key === 'ArrowRight') show(currentIndex + 1);
    });
  }

  function show(index) {
    if (links.length === 0) return;
    currentIndex = (index + links.length) % links.length;
    img.src = links[currentIndex].getAttribute('href');
    img.alt = links[currentIndex].getAttribute('title') || '';
    counter.textContent = (currentIndex + 1) + ' / ' + links.length;
    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function close() {
    overlay.classList.remove('open');
    document.body.style.overflow = '';
  }

  document.addEventListener('DOMContentLoaded', function () {
    links = Array.prototype.slice.call(document.querySelectorAll('.photo-item a[href]'));
    if (links.length === 0) return;
    build();
    links.forEach(function (link, index) {
      link.addEventListener('click', function (event) {
        event.preventDefault();
        show(index);
      });
    });
  });
})();
