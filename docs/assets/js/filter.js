(function () {
  'use strict';

  var input = document.getElementById('coordinate-filter');
  var grid = document.getElementById('coordinates-grid');
  var counter = document.getElementById('filter-count');
  var emptyState = document.getElementById('no-results');

  if (!input || !grid) {
    return;
  }

  var tiles = Array.prototype.slice.call(grid.querySelectorAll('.tile'));
  var totalLabel = tiles.length + ' coordinate' + (tiles.length === 1 ? '' : 's');

  function applyFilter() {
    var raw = input.value || '';
    var terms = raw.toLowerCase().split(/\s+/).filter(Boolean);
    var visible = 0;

    tiles.forEach(function (tile) {
      var haystack = tile.getAttribute('data-search') || '';
      var match = terms.every(function (term) {
        return haystack.indexOf(term) !== -1;
      });
      tile.hidden = !match;
      if (match) { visible += 1; }
    });

    if (counter) {
      counter.textContent = terms.length === 0
        ? totalLabel
        : visible + ' of ' + tiles.length + ' shown';
    }

    if (emptyState) {
      emptyState.hidden = visible !== 0;
    }
  }

  input.addEventListener('input', applyFilter);

  // Honour the URL hash to allow deep-linking to a filtered view, e.g.
  // /#kafka.
  if (window.location.hash && window.location.hash.length > 1) {
    input.value = decodeURIComponent(window.location.hash.slice(1));
  }
  applyFilter();
}());
