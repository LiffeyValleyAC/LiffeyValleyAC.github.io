(function () {
  var ballImageSrc = '/assets/images/pngtree-fifa-world-cup-soccer-ball-2026-trionda-png-small.png';
  var activeBalls = 3;

  function randomBetween(min, max) {
    return Math.random() * (max - min) + min;
  }

  function randomDirection() {
    return Math.random() < 0.5 ? -1 : 1;
  }

  // Simula la caída física de la pelota: gravedad real, rebotes con
  // pérdida de energía (restitución) y rebotes contra los bordes laterales
  // de la pantalla, bajando "escalón a escalón" hasta el fondo.
  function simulateTrajectory(startX, size, viewportWidth, viewportHeight) {
    var g = 2600;              // gravedad, px/s^2 3600
    var dt = 1 / 45;           // paso de simulación
    var restitution = 0.6;     // energía vertical conservada tras cada rebote
    var friction = 1.1;       // pérdida de velocidad horizontal por rebote 0.94
    var totalSteps = 8;        // número de "escalones" del descenso

    var x = startX;
    var y = -size;             // arranca fuera de la pantalla, arriba
    var vx = randomBetween(70, 150) * randomDirection();
    var vy = 0;
    var rotation = 0;
    var t = 0;

    var frames = [{ t: t, x: x, y: y, rotation: rotation }];

    for (var step = 1; step <= totalSteps; step++) {
      // cada escalón está más abajo que el anterior (efecto escalera)
      var floorY = size * 0.4 + (viewportHeight - size) * (step / totalSteps);

      while (y < floorY) {
        vy += g * dt;
        x += vx * dt;
        y += vy * dt;
        t += dt;

        // rotación proporcional a la velocidad horizontal (efecto de rodar/girar)
        rotation += vx * dt * 0.9;

        // rebote contra los bordes de la pantalla -> traslación lado a lado
        if (x < size / 2) {
          x = size / 2;
          vx = Math.abs(vx);
        } else if (x > viewportWidth - size / 2) {
          x = viewportWidth - size / 2;
          vx = -Math.abs(vx);
        }

        if (y >= floorY) {
          y = floorY;
        }

        frames.push({ t: t, x: x, y: y, rotation: rotation });
      }

      // rebote vertical: pierde energía y algo de velocidad horizontal
      vy = -vy * restitution;
      vx *= friction;
      // pequeña variación aleatoria para que no se vea mecánico
      vx += randomBetween(-8, 8);

      frames.push({ t: t, x: x, y: y, rotation: rotation });
    }

    return frames;
  }

  function framesToKeyframes(frames) {
    var totalTime = frames[frames.length - 1].t || 1;

    return frames.map(function (f) {
      return {
        offset: Math.min(1, f.t / totalTime),
        transform: 'translate3d(' + f.x + 'px, ' + f.y + 'px, 0) rotate(' + f.rotation + 'deg)'
      };
    });
  }

  function animateBall(ball, index) {
    var viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
    var viewportHeight = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);
    var size = Number(ball.dataset.size);
    var startX = randomBetween(size, Math.max(size, viewportWidth - size));

    var frames = simulateTrajectory(startX, size, viewportWidth, viewportHeight);
    var keyframes = framesToKeyframes(frames);

    var totalSeconds = frames[frames.length - 1].t;
    var duration = Math.max(4000, totalSeconds * 1000);
    var delay = index * 420 + randomBetween(0, 900);

    ball.animate(keyframes, {
      duration: duration,
      delay: delay,
      iterations: Infinity,
      easing: 'linear'
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (window.location.pathname !== '/') {
      return;
    }

    var fragment = document.createDocumentFragment();
    var balls = [];

    for (var i = 0; i < activeBalls; i++) {
      var ball = document.createElement('span');
      var image = document.createElement('img');
      var sizePx = Math.floor(randomBetween(52, 67));

      ball.className = 'snowflake trionda-ball';
      ball.dataset.size = String(sizePx);
      ball.style.setProperty('--size', sizePx + 'px');
      ball.style.position = 'fixed';
      ball.style.top = '0';
      ball.style.left = '0';
      ball.style.width = sizePx + 'px';
      ball.style.height = sizePx + 'px';
      ball.style.willChange = 'transform';

      // Clave para que la imagen NUNCA se deforme: tamaño fijo cuadrado
      // + object-fit: contain, sin ningún scaleX/scaleY en la animación.
      image.src = ballImageSrc;
      image.alt = '';
      image.decoding = 'async';
      image.loading = 'eager';
      image.draggable = false;
      image.className = 'trionda-ball-image';
      image.style.width = '100%';
      image.style.height = '100%';
      image.style.objectFit = 'contain';
      image.style.display = 'block';

      ball.appendChild(image);
      balls.push(ball);
      fragment.appendChild(ball);
    }

    document.body.appendChild(fragment);
    balls.forEach(animateBall);
  });
})();