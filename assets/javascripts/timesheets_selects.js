// plugins/redmine_lite_timesheets/assets/javascripts/timesheets_selects.js
document.addEventListener('DOMContentLoaded', function() {
  // Necesitamos jQuery y Select2
  if (typeof $ === 'undefined' || !$.fn.select2) { return; }

  // Todos los selects marcados con esta clase tendrán buscador
  $('select.timesheets-select').select2({
    width: 'resolve',
    allowClear: true,
    placeholder: ''
  });
});
