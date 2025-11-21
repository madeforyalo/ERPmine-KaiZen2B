class TimesheetsController < ApplicationController
  # Vista global, no depende de un proyecto específico de entrada
  before_action :require_login
  before_action :authorize_global, only: [:index]

  def index
    # Tipo de filtro: 'project' (por defecto) o 'group'
    @filter_type = params[:filter_type].presence || 'project'

    # Listas base para los combos
    @projects = Project.active.visible.order(:name).to_a
    @groups   = Group.givable.order(:lastname).to_a

    # Selecciones actuales
    @project = Project.find_by(id: params[:project_id]) if params[:project_id].present?
    @group   = Group.find_by(id: params[:group_id])     if params[:group_id].present?
    @selected_user = User.find_by(id: params[:user_id]) if params[:user_id].present?

    setup_dates

    # Usuarios disponibles para el combo "Miembro", según filtro
    @users_for_filter =
      case @filter_type
      when 'project'
        @project ? @project.members.active.map(&:user).sort_by(&:name) : []
      when 'group'
        @group ? @group.users.active.sort_by(&:name) : []
      else
        []
      end

    # Usuarios a mostrar en la tabla (puede estar filtrado por usuario)
    @users =
      case @filter_type
      when 'project'
        if @project
          unless User.current.allowed_to?(:view_timesheets, @project)
            render_403
            return
          end

          list = @project.members.active.map(&:user)
          list = list.select { |u| u.id == @selected_user.id } if @selected_user
          list.sort_by(&:name)
        else
          []
        end
      when 'group'
        if @group
          list = @group.users.active
          list = list.select { |u| u.id == @selected_user.id } if @selected_user
          list.sort_by(&:name)
        else
          []
        end
      else
        []
      end
  end

  private

  def setup_dates
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @start_of_week = @date.beginning_of_week
    @end_of_week   = @date.end_of_week
  end
end
