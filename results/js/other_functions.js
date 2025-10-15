<!-- ========= ORDENACIÓN DE TABLA ========= -->
<script>
(function makeTableSortable() {
  'use strict';

  /* Esperamos a que tu hoja se haya renderizado (ajusta selector si usas otro) */
  const table = document.querySelector('table');   // <-- primera tabla del DOM
  if (!table) return;

  /* Si tu tabla no tiene thead/tbody, se los generamos rápidamente */
  if (!table.tHead) {
    const firstRow = table.rows[0];
    if (firstRow) {
      const thead = table.createTHead();
      thead.appendChild(firstRow);
    }
  }
  if (!table.tBodies.length) {
    const tbody = document.createElement('tbody');
    while (table.rows.length) tbody.appendChild(table.rows[0]);
    table.appendChild(tbody);
  }

  const headers = Array.from(table.tHead.rows[0].cells);
  const tbody   = table.tBodies[0];
  const store   = [];                     // guarda el orden original
  let lastCol   = -1, lastDir = 0;        // 1=asc, -1=desc, 0=original

  /* Guardamos el índice original para poder restaurarlo */
  Array.from(tbody.rows).forEach((r, i) => store[i] = r);

  headers.forEach((th, idx) => {
    th.style.cursor = 'pointer';
    th.addEventListener('click', () => sortColumn(idx));
  });

  function sortColumn(idx) {
    let dir = 1;
    if (idx === lastCol) {
      dir = lastDir === 1 ? -1 : (lastDir === -1 ? 0 : 1);
    }
    lastCol = idx;
    lastDir = dir;

    /* Restaurar orden original */
    if (dir === 0) {
      store.forEach(r => tbody.appendChild(r));
      return;
    }

    const rows = Array.from(tbody.rows);
    rows.sort((a, b) => {
      const A = getValue(a.cells[idx]);
      const B = getValue(b.cells[idx]);

      /* Orden numérico o alfabético */
      const cmp = A > B ? 1 : (A < B ? -1 : 0);
      return dir === 1 ? cmp : -cmp;
    });

    /* Volver a insertar filas en el nuevo orden */
    rows.forEach(r => tbody.appendChild(r));
  }

  /* Extrae texto o número de la celda */
  function getValue(cell) {
    const txt = cell.textContent.trim();
    const num = parseFloat(txt.replace(/[$,%]/g, ''));
    return isNaN(num) ? txt.toLowerCase() : num;
  }
})();
</script>