FactoryGirl.define do
  factory :paypal_express_gateway, class: Spree::Gateway::PaypalExpressCheckout do
    name 'Paypal Express'
    created_at Date.today
  end

  factory :paypal_payment, class: Spree::Payment do
    amount 15.00
    order
    state 'checkout'
    association(:payment_method, factory: :paypal_express_gateway)
    association(:source, factory: :credit_card_komerci)
  end

  factory :paypal_checkout, class: Spree::PaypalCheckout do
    payment_id 'PAY-001'
    payer_id 'PAYER001'
  end
end
