module Spree
  Shipment.class_eval do

    def available_paypal_shipping_methods(display_filter = Spree::ShippingMethod::DISPLAY_ON_FRONT_END)
      package = to_package

      shipping_methods = package.shipping_methods.select do |ship_method|
        calculator = ship_method.calculator

        ship_method.available_to_display(display_filter) &&
        calculator.available?(package) &&
        (calculator.preferences[:currency].blank? ||
         calculator.preferences[:currency] == currency)
      end
    end

    def paypal_shipping_rates(display_filter = Spree::ShippingMethod::DISPLAY_ON_FRONT_END)
      package = to_package
      shipping_methods = available_paypal_shipping_methods(display_filter)
      rates = shipping_methods.map do |shipping_method|
        cost = shipping_method.calculator.compute(package)

        shipping_method.shipping_rates.new(
          shipment: self,
          cost: cost
        ) if cost
      end.compact

      rates.min_by(&:cost).selected = true if rates.any?
      rates.sort_by!(&:cost)
    end

  end
end
