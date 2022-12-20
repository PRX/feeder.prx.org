class AddPaymentPointer < ActiveRecord::Migration[4.2]
  def change
    add_column :feeds, :payment_pointer, :string
  end
end
