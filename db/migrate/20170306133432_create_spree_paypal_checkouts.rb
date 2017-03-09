class CreateSpreePaypalCheckouts < ActiveRecord::Migration
  def change
    create_table :spree_paypal_checkouts do |t|
      t.string    :payer_id
      t.string    :payment_id, index: true
      t.string    :refund_id, index: true
      t.string    :refund_type
      t.string    :state
      t.string    :sale_id, index: true
      t.datetime  :refunded_at
      t.timestamps null: false
    end
  end
end
