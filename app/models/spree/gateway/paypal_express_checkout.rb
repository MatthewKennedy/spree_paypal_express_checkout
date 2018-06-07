module Spree
  class Gateway::PaypalExpressCheckout < Gateway
    include PayPal::SDK::REST
    include Gateway::PaypalPayment
    include Gateway::PaypalWebProfile

    preference :client_id,             :string
    preference :client_secret,         :string
    preference :server,                :string, default: 'production'
    preference :brand_name,            :string
    preference :allow_note,            :boolean, default: false
    preference :no_shipping,           :boolean, default: true
    preference :address_override,      :integer, default: 1
    preference :landing_page_type,     :string,  default:'billing'
    preference :temporary,             :boolean, default: true
    preference :locale_code,           :string,  default: 'US'
    preference :profile_name,          :string
    preference :logo_url,              :string, default: 'https://www.paypalobjects.com/webstatic/en_US/i/btn/png/blue-rect-paypal-60px.png'
    preference :enable_guest_checkout, :boolean, default: false

    def provider_class
      PayPal::SDK::REST
    end

    def payment_sale_class
      PayPal::SDK::REST::Sale
    end

    def provider
      provider_class.set_config(
        mode: server_mode,
        client_id: preferred_client_id,
        client_secret: preferred_client_secret
      )
    end

    def source_required?
      true
    end

    def auto_capture?
      true
    end

    def method_type
      'paypal_express_checkout'
    end

    def request_payment(order)
      provider
      payment(order, first_or_new(profile_options).id)
    end

    def purchase(amount, source, options)
      begin
        provider
        payment = payment_source_class.find(source.payment_id)

        if payment.transactions.any?
          paypal_total = payment.transactions.first.amount.total
          paypal_total_cents = Spree::Money.new(paypal_total, currency: options[:currency]).cents
          if amount != paypal_total_cents
            return ActiveMerchant::Billing::Response.new(false, Spree.t(:paypal_wrong_price), payment.to_hash)
          end
        end

        executed_payment = payment.execute(payer_id: source.payer_id)
        source.update(state: payment.state)
        if executed_payment
          sale_id = payment.transactions.first.related_resources.first.sale.id
          source.update(sale_id: sale_id)
          ActiveMerchant::Billing::Response.new(true, 'Success', {}, authorization: sale_id)
        else
          ActiveMerchant::Billing::Response.new(false, payment.error.message, payment.to_hash, authorization: sale_id)
        end
      rescue PayPal::SDK::Core::Exceptions::ResourceNotFound => e
        ActiveMerchant::Billing::Response.new(false, Spree.t(:paypal_failed_payment_id), {}, {})
      end
    end

    def confirm(paypal_payment_id, order)
      provider
      payment = payment_source_class.find(paypal_payment_id)
      phone = payment.payer.payer_info.phone
      ship_address = format_address_from_response(payment.payer.payer_info.shipping_address)
      ship_address[:phone] = phone

      order_attributes = {
        email: payment.payer.payer_info.email,
        special_instructions: 'PayPal Guest Checkout',
        ship_address_attributes: ship_address
      }

      if payment.payer.payer_info.billing_address.line1.present?
        bill_address = format_address_from_response(payment.payer.payer_info.billing_address)
        bill_address[:phone] = phone
        bill_address[:firstname] = payment.payer.payer_info.first_name
        bill_address[:lastname] = payment.payer.payer_info.last_name
        order_attributes[:bill_address_attributes] = bill_address
      else
        order_attributes[:bill_address_attributes] = ship_address
      end

      order.update_attributes(order_attributes)
    end

    def refund(amount, source, options)
      provider
      payment = payment_source_class.find(source.payment_id)
      sale_id = payment.transactions.first.related_resources.first.sale.id
      sale = payment_sale_class.find(sale_id)
      paypal_refund = sale.refund_request({
        amount:{
          total: amount,
          currency: options[:currency]
        }
      })
      if paypal_refund.success?
        refund_type = paypal_refund.amount == amount.to_f ? 'Full' : 'Partial'
        source.update(
          refund_id: paypal_refund.id,
          refund_type: refund_type,
          refunded_at: paypal_refund.create_time
        )
        ActiveMerchant::Billing::Response.new(true, 'Refund Successful', paypal_refund.to_hash, authorization: source.id)
      else
        ActiveMerchant::Billing::Response.new(false, paypal_refund.error.message, paypal_refund.to_hash, authorization: source.id)
      end
    end

    def cancel(source_id)
      payment = Spree::Payment.find_by source_type: 'Spree::PaypalCheckout',source_id: source_id
      refund(payment.amount, payment.source, { currency: payment.currency })
    end

    def credit(amount, source, options)
      origin = options[:originator]
      fixed_amount = Money.new(amount * 0.01).money.to_s
      refund(fixed_amount, origin.payment.source, {currency: origin.payment.currency, originator: origin})
    end

    def profile_options
      {
        profile_name: preferred_profile_name,
        brand_name: preferred_brand_name,
        allow_note: preferred_allow_note,
        no_shipping: preferred_no_shipping,
        locale_code: preferred_locale_code,
        address_override: preferred_address_override,
        landing_page_type: preferred_landing_page_type,
        temporary: preferred_temporary
      }
    end

    def server_mode
      if preferred_test_mode
        'sandbox'
      else
        'live'
      end
    end
  end
end
