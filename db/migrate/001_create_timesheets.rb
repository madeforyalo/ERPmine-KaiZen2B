class CreateTimesheets < ActiveRecord::Migration[7.0]
  def change
    # 1. Crear la tabla de cabeceras de Hojas de Tiempo
    create_table :timesheets do |t|
      t.integer :user_id, null: false
      t.date    :period_start, null: false  # Inicio de la semana
      t.date    :period_end, null: false    # Fin de la semana
      t.string  :status, default: 'draft'   # draft, submitted, approved, rejected
      
      # Para el flujo de aprobación
      t.datetime :submitted_on
      t.integer  :approved_by_id
      t.datetime :approved_on
      t.text     :comments                  # Comentarios al aprobar/rechazar

      t.timestamps
    end

    add_index :timesheets, [:user_id, :period_start], unique: true, name: 'index_timesheets_on_user_and_period'

    # 2. Modificar la tabla nativa TimeEntries para vincularla a una Timesheet
    # Esto nos permite agrupar las horas existentes en esta hoja.
    add_column :time_entries, :timesheet_id, :integer
    add_index :time_entries, :timesheet_id
  end
end