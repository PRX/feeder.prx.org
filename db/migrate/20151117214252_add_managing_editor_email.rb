class AddManagingEditorEmail < ActiveRecord::Migration[4.2]
  def change
    rename_column :podcasts, :managing_editor, :managing_editor_name
    add_column :podcasts, :managing_editor_email, :string
  end
end
