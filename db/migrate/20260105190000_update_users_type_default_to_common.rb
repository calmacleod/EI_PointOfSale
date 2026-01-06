class UpdateUsersTypeDefaultToCommon < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :type, from: "User", to: "Common"

    execute <<~SQL
      UPDATE users
      SET type = 'Common'
      WHERE type = 'User'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users
      SET type = 'User'
      WHERE type = 'Common'
    SQL

    change_column_default :users, :type, from: "Common", to: "User"
  end
end


