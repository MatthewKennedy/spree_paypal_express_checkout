module Spree
  Order.class_eval do

    def set_paypal_shipping
      return if shipments.any?
      create_proposed_shipments
      shipments.each do |shipment|
        next if shipment.shipped?

        package = shipment.to_package
        shipping_methods = shipment.available_paypal_shipping_methods
        rates = shipment.paypal_shipping_rates
      end
      set_shipments_cost
      apply_free_shipping_promotions
    end

  end
end
