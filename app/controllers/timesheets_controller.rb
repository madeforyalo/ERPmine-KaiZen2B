class TimesheetsController < ApplicationController
  # Quitamos los filtros automáticos de proyecto porque es una vista global inicial
  before_action :authorize_global, only: [:index]

  def index
    # 1. Cargar todos los proyectos visibles por el usuario para el Dropdown
    @projects = Project.active.visible.order('name').to_a
    
    # 2. Verificar si el usuario seleccionó un proyecto en el filtro
    if params[:project_id].present?
      @project = Project.find_by(id: params[:project_id])
    end

    # 3. Si hay proyecto seleccionado, buscamos los usuarios y datos
    if @project
      # Verificar permisos manualmente ya que quitamos el filtro automático
      unless User.current.allowed_to?(:view_timesheets, @project)
        render_403
        return
      end

      setup_dates # Método privado para fechas
      
      # Buscar usuarios del proyecto seleccionado
      @users = @project.members.active.map(&:user).sort_by(&:name)
    else
      # Si no hay proyecto, listas vacías
      @users = []
    end
  end

  private

  def setup_dates
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @start_of_week = @date.beginning_of_week
    @end_of_week   = @date.end_of_week
  end
end
