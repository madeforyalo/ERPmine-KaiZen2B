class Timesheet < ActiveRecord::Base
  include Redmine::SafeAttributes

  # Relaciones
  belongs_to :user
  belongs_to :approver, class_name: 'User', foreign_key: 'approved_by_id', optional: true
  
  # Una hoja de tiempo tiene muchas entradas de tiempo
  # Si borramos la hoja, desvinculamos las horas (nullify), no las borramos.
  has_many :time_entries, dependent: :nullify 

  # Validaciones
  validates :user_id, :period_start, :period_end, presence: true
  validates :status, inclusion: { in: %w(draft submitted approved rejected) }

  # Scopes útiles para los filtros de la Imagen 2
  scope :pending_approval, -> { where(status: 'submitted') }
  scope :for_user, ->(user) { where(user_id: user.id) }

  # Método auxiliar para calcular totales (se verá en la vista)
  def total_hours
    time_entries.sum(:hours)
  end
end