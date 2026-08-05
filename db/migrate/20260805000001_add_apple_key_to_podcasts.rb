class AddAppleKeyToPodcasts < ActiveRecord::Migration[7.2]
  def change
    add_reference :podcasts, :apple_key, foreign_key: {to_table: :apple_keys}
  end
end
