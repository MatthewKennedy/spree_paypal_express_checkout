module Spree
  Order.class_eval do

    def set_paypal_shipping
      create_proposed_shipments
      set_shipments_cost
      apply_free_shipping_promotions
    end

  end
end
