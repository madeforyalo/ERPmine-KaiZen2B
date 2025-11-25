# 1. Ruta Global (Menú superior)
# Esta es la que responde a: http://tu-redmine/timesheets
get 'timesheets', to: 'timesheets#index'

# NUEVO: pantalla de edición semanal
get 'timesheets/edit', to: 'timesheets#edit', as: 'edit_timesheet'
post 'timesheets/save', to: 'timesheets#save', as: 'timesheets_save'

# 2. Rutas para acciones futuras (Guardar, Enviar, Aprobar)
# Las usaremos cuando programemos los botones de la tabla

post 'timesheets/submit', to: 'timesheets#submit'
post 'timesheets/approve', to: 'timesheets#approve'
post 'timesheets/reject', to: 'timesheets#reject'
