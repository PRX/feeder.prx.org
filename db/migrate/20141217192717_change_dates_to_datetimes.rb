class ChangeDatesToDatetimes < ActiveRecord::Migration
  def change
    change_column :podcasts, :pub_date, :datetime
    change_column :podcasts, :last_build_date, :datetime
    change_column :podcasts, :update_base, :datetime
  end
end
