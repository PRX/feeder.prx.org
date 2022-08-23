class AddPaymentPointer < ActiveRecord::Migration
  def change
    add_column :podcasts, :payment_pointer, :string
    add_column :feeds, :payment_pointer, :string
  end
end