class RemoveEnclosureTemplate < ActiveRecord::Migration[7.2]
  def up
    if Feed.where.not(enclosure_template: nil).any?
      raise "you must nil out all enclosure templates before running this"
    end

    remove_column :feeds, :enclosure_template
  end

  def down
    remove_column :feeds, :enclosure_template, :string
  end
end
