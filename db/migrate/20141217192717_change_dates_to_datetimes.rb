class ChangeDatesToDatetimes < ActiveRecord::Migration[4.2]
  def change
    change_column :podcasts, :pub_date, :datetime
    change_column :podcasts, :last_build_date, :datetime
    change_column :podcasts, :update_base, :datetime
  end
end
