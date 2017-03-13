module Spree
  class Gateway::PaypalExpressCheckout < Gateway
    include PayPal::SDK::REST
    include Gateway::PaypalPayment
    include Gateway::PaypalWebProfile

    preference :client_id,          :string
    preference :client_secret,      :string
    preference :server,             :string, default: 'production'
    preference :brand_name,         :string
    preference :allow_note,         :boolean, default: false
    preference :no_shipping,        :boolean, default: true
    preference :address_override,   :integer, default: 1
    preference :landing_page_type,  :string,  default:'billing'
    preference :temporary,          :boolean, default: true
    preference :locale_code,        :string,  default: 'US'
    preference :profile_name,       :string
    preference :logo_url,           :string, default: 'https://www.paypalobjects.com/webstatic/en_US/i/btn/png/blue-rect-paypal-60px.png'

    def provider_class
      PayPal::SDK::REST
    end

    def payment_source_class
      PayPal::SDK::REST::DataTypes::Payment
    end

    def payment_sale_class
      PayPal::SDK::REST::Sale
    end

    def provider
      provider_class.set_config(
        mode: preferred_server,
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
      payment = payment_source_class.find(source.payment_id)

      executed_payment = payment.execute(payer_id: source.payer_id)
      source.update(state: payment.state)
      if executed_payment
        sale_id = payment.transactions.first.related_resources.first.sale.id
        source.update(sale_id: sale_id)
        ActiveMerchant::Billing::Response.new(true, 'Success', payment.to_hash, authorization: source.id)
      else
        ActiveMerchant::Billing::Response.new(false, payment.error.message, payment.to_hash, authorization: source.id)
      end
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
  end
end