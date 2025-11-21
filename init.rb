Redmine::Plugin.register :redmine_lite_timesheets do
  name 'Redmine Lite Timesheets'
  author 'Gonzalo Rojas'
  description 'Gestión de tiempos global estilo ERPmine'
  version '0.0.2'
  requires_redmine version_or_higher: '5.0.0'

  settings default: {
    'submission_deadline_day' => 'Friday',
    'submission_deadline_time' => '18:00',
    'auto_approve' => false
  }, partial: 'settings/timesheet_settings'

  # --- CAMBIOS AQUÍ ---
  
  # 1. Permisos (Se mantienen igual)
  project_module :timesheets do
    permission :view_timesheets, { timesheets: [:index] }
    permission :submit_timesheets, { timesheets: [:submit] }
    permission :approve_timesheets, { timesheets: [:approve, :reject] }
  end

  # 2. Menú: Lo cambiamos a :top_menu (Barra superior)
  # Quitamos 'param: :project_id' porque al entrar no hemos elegido proyecto aún.
  menu :top_menu, :timesheets, 
       { controller: 'timesheets', action: 'index' }, 
       caption: 'Timesheets', 
       if: Proc.new { User.current.logged? }
end
