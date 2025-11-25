class EnableTimesheetsModule < ActiveRecord::Migration[7.0]
  def up
    Project.find_each do |project|
      next if project.enabled_modules.where(name: 'timesheets').exists?

      project.enabled_modules.create!(name: 'timesheets')
    end
  end

  def down
    EnabledModule.where(name: 'timesheets').delete_all
  end
end
