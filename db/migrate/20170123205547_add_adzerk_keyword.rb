class AddAdzerkKeyword < ActiveRecord::Migration
  def change
    add_column :episodes, :adzerk_keyword, :string
  end
end
