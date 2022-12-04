class RevisePaymentPointer < ActiveRecord::Migration[4.2]
  def change
    remove_column :feeds, :payment_pointer
    add_column :podcasts, :payment_pointer, :string
    add_column :podcasts, :donation_url, :string
    add_column :feeds, :include_podcast_value, :boolean, default: true
    add_column :feeds, :include_donation_url, :boolean, default: true
  end
end
