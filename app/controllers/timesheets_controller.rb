class TimesheetsController < ApplicationController
  # Vista global, no depende de un proyecto específico de entrada
  before_action :require_login
  before_action :authorize_global, only: [:index, :edit, :save]
  before_action :set_allowed_projects, only: [:index, :edit]


  def index
    @filter_type = params[:filter_type].presence || 'project'

    # Listas base para los combos
    @projects = @allowed_projects
    @groups   = Group.givable.order(:lastname).to_a

    # Selecciones actuales
    if params[:project_id].present?
      @project = @projects.find { |p| p.id == params[:project_id].to_i }
    end
    @group          = Group.find_by(id: params[:group_id])     if params[:group_id].present?
    @selected_user  = User.find_by(id: params[:user_id])       if params[:user_id].present?


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

    # --------------------------------------------------------
    # Cálculo de horas por usuario y total general
    # --------------------------------------------------------
    @user_hours  = {}
    @total_hours = 0.0

    if @users.any?
      scope = TimeEntry.where(user_id: @users.map(&:id))

      # Filtrar por proyecto si hay uno seleccionado
      scope = scope.where(project_id: @project.id) if @project

      # Filtrar por rango de fechas
      scope = scope.where('spent_on >= ?', @from_date) if @from_date
      scope = scope.where('spent_on <= ?', @to_date)   if @to_date

      # Devuelve un hash { user_id => horas }
      @user_hours = scope.group(:user_id).sum(:hours)

      @total_hours = @user_hours.values.map(&:to_f).sum
    end
  end

  def edit
    @users = User.active.order(:login).to_a
    @editable_projects = @allowed_projects

    @selected_user =
      if params[:user_id].present?
        User.find_by(id: params[:user_id])
      end || User.current

    date_param = params[:start_date] || params[:date]
    base_date  = date_param.present? ? Date.parse(date_param) : Date.today

    @week_start = base_date.beginning_of_week(:monday)
    @week_end   = @week_start + 6
    @week_days  = (@week_start..@week_end).to_a

    # Solo actividad "Horas"
    @activities_hours = TimeEntryActivity.where(name: 'Horas')
    @activities_hours = TimeEntryActivity.all if @activities_hours.empty?

    entries = TimeEntry.
      where(user_id: @selected_user.id).
      where(spent_on: @week_start..@week_end)

    grouped = entries.group_by { |te|
      [te.project_id, te.issue_id, te.activity_id, te.comments.to_s]
    }

    @rows = grouped.map do |(project_id, issue_id, activity_id, comments), list|
      daily = {}
      @week_days.each { |d| daily[d] = 0.0 }

      list.each do |e|
        daily[e.spent_on] ||= 0.0
        daily[e.spent_on] += e.hours.to_f
      end

      {
        project:  Project.find_by(id: project_id),
        issue:    Issue.find_by(id: issue_id),
        activity: TimeEntryActivity.find_by(id: activity_id),
        comments: comments,
        daily_hours: daily
      }
    end

    # Proyecto actual: el que vino de la pantalla principal o el de la primera fila
    @current_project =
      if params[:project_id].present?
        @editable_projects.find { |p| p.id == params[:project_id].to_i }
      elsif @rows.any? && @rows.first[:project]
        @rows.first[:project]
      end

    # Si no hay filas, creamos una vacía con el proyecto preseleccionado (si lo hay)
    if @rows.empty?
      empty_daily = {}
      @week_days.each { |d| empty_daily[d] = 0.0 }

      @rows << {
        project: @current_project,
        issue: nil,
        activity: @activities_hours.first,
        comments: '',
        daily_hours: empty_daily
      }
    end

    # Issues para el combo de Petición
    if @current_project
      @issues_for_project = @current_project.issues.open.order(:id)
    else
      @issues_for_project = Issue.open.
        where(project_id: @editable_projects.map(&:id)).
        order(:id).
        limit(200)
    end

    # Aseguramos incluir issues ya usadas aunque estén cerradas o fuera del scope
    used_issues = @rows.map { |r| r[:issue] }.compact
    missing     = used_issues.reject { |iss| @issues_for_project.include?(iss) }
    @issues_for_project += missing
  end


  def save
  user       = User.find(params[:user_id])
  week_start = Date.parse(params[:week_start])
  week_end   = week_start + 6

  # Por ahora: sólo el propio usuario o admin pueden guardar
  unless User.current == user || User.current.admin?
    render_403
    return
  end

  TimeEntry.transaction do
    # La grilla es la "verdad" de la semana: borramos todo y recreamos
    TimeEntry.where(user_id: user.id, spent_on: week_start..week_end).destroy_all

    rows      = params[:rows] || {}
    timesheet = nil

    rows.each_value do |row|
      project_id  = row[:project_id].presence
      activity_id = row[:activity_id].presence
      issue_id    = row[:issue_id].presence
      comments    = row[:comments].to_s
      hours_hash  = row[:hours] || {}

      # si no hay proyecto, ignoramos la fila
      next if project_id.blank?

      project = Project.find_by(id: project_id)
      next unless project

      hours_hash.each do |day_str, value|
        # soportar 1,5 y 1.5
        hours = value.to_s.tr(',', '.').to_f
        next if hours <= 0.0

        spent_on = Date.parse(day_str)

        # creamos/obtenemos la Timesheet de esa semana
        timesheet ||= Timesheet.find_or_create_by!(
          user_id:      user.id,
          period_start: week_start,
          period_end:   week_end
        ) do |ts|
          ts.status ||= 'draft'
        end

        te              = TimeEntry.new
        te.user_id      = user.id
        te.project_id   = project.id
        te.issue_id     = issue_id if issue_id.present?
        te.activity_id  = activity_id if activity_id.present?
        te.spent_on     = spent_on
        te.hours        = hours
        te.comments     = comments
        te.timesheet_id = timesheet.id
        te.save!
      end
    end

    # Si al final no quedó ninguna hora, eliminamos la timesheet vacía
    if timesheet && timesheet.time_entries.count == 0
      timesheet.destroy
    end
  end

  flash[:notice] = 'Hoja de tiempo guardada correctamente.'

  # Redirección según botón
  if params[:save_and_continue]
    # se queda en la misma semana para seguir cargando
    redirect_to edit_timesheet_path(user_id: user.id, start_date: week_start)
  else
    # botón "Guardar": vuelve al listado principal
    redirect_to timesheets_path
  end

rescue => e
  flash[:error] = "Error al guardar la hoja de tiempo: #{e.message}"
  redirect_back fallback_location: edit_timesheet_path(
    user_id:   params[:user_id],
    start_date: params[:week_start]
  )
end



  private

  def set_allowed_projects
    all = Project.active.visible.to_a
    @allowed_projects = all.select do |p|
      User.current.allowed_to?(:log_time, p) ||
      User.current.allowed_to?(:edit_time_entries, p) ||
      User.current.allowed_to?(:view_time_entries, p)
    end
  end

  def setup_dates
    @range_type = params[:range_type].presence || 'this_week'
    today = Date.today

    case @range_type
    when 'all_time'
      @from_date = nil
      @to_date   = nil

    when 'this_week'
      ref = params[:ref_date].present? ? Date.parse(params[:ref_date]) : today
      @from_date = ref.beginning_of_week
      @to_date   = ref.end_of_week

    when 'last_week'
      ref = params[:ref_date].present? ? Date.parse(params[:ref_date]) : today
      ref = ref - 7
      @from_date = ref.beginning_of_week
      @to_date   = ref.end_of_week

    when 'this_month'
      ref = params[:ref_date].present? ? Date.parse(params[:ref_date]) : today
      @from_date = ref.beginning_of_month
      @to_date   = ref.end_of_month

    when 'last_month'
      ref = params[:ref_date].present? ? Date.parse(params[:ref_date]) : today
      ref = (ref - 1.month)
      @from_date = ref.beginning_of_month
      @to_date   = ref.end_of_month

    when 'this_year'
      ref = params[:ref_date].present? ? Date.parse(params[:ref_date]) : today
      @from_date = ref.beginning_of_year
      @to_date   = ref.end_of_year

    when 'custom'
      @from_date = params[:from].present? ? Date.parse(params[:from]) : today.beginning_of_week
      @to_date   = params[:to].present?   ? Date.parse(params[:to])   : today
    else
      @range_type = 'this_week'
      @from_date = today.beginning_of_week
      @to_date   = today.end_of_week
    end

    # Compatibilidad con lo que usás en la tabla
    @date          = today
    @start_of_week = @from_date || today.beginning_of_week
    @end_of_week   = @to_date   || today.end_of_week
  end
end
