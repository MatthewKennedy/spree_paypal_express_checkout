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
        rates.each do |rate|
          old_rates = Spree::ShippingRate.where(shipment_id: rate.shipment_id,
                                                shipping_method_id: rate.shipping_method_id)
          old_rates.each do |old_rate|
            old_rate.destroy if old_rate.order.try(:id) == id
          end if old_rates.any?
          rate.save
        end
      end
      set_shipments_cost
      apply_free_shipping_promotions
    end

  end
end
