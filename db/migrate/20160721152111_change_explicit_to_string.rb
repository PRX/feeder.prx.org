class ChangeExplicitToString < ActiveRecord::Migration[4.2]
  def up
    rename_column :podcasts, :explicit, :explicit_boolean
    add_column :podcasts, :explicit, :string
    execute "update podcasts set explicit = 'clean' where explicit_boolean is null or explicit_boolean = false"
    execute "update podcasts set explicit = 'yes' where explicit_boolean = true"
    remove_column :podcasts, :explicit_boolean
  end

  def down
    rename_column :podcasts, :explicit, :explicit_string
    add_column :podcasts, :explicit, :boolean
    execute "update podcasts set explicit = false where explicit_string = 'clean'"
    execute "update podcasts set explicit = true where explicit_string = 'yes'"
    remove_column :podcasts, :explicit_string
  end
end
