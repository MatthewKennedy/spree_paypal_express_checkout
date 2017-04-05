require 'spec_helper'

describe Spree::Gateway::PaypalExpressCheckout do

  let(:paypal_gateway) { FactoryGirl.build(:paypal_express_gateway) }
  let(:paypal_checkout) { FactoryGirl.build(:paypal_checkout) }
  let!(:payment) { create(:paypal_payment, source: paypal_checkout) }
  let(:order) { create(:order) }

  context 'purchase' do

    it 'should purchase the payment' do
      set_paypal_conf
      paypal_gateway.provider
      mock_request 'https://api.sandbox.paypal.com/v1/oauth2/token', 'spec/fixtures/token.json'
      mock_request 'https://api.sandbox.paypal.com/v1/payments/payment/PAY-001/execute', 'spec/fixtures/payment_response.json'

      payment_params = JSON.parse(File.read('spec/fixtures/payment_response.json'))
      stub_payment = paypal_gateway.payment_source_class.new payment_params
      allow(paypal_gateway.payment_source_class).to receive(:find).and_return(stub_payment)

      response = paypal_gateway.purchase(1500, paypal_checkout, {})
      expect(response.success?).to be_truthy
      expect(response.message).to eq 'Success'

      expect(paypal_checkout.state).to eq 'approved'
      expect(paypal_checkout.payment_id).to eq 'PAY-001'
      expect(paypal_checkout.payer_id).to eq 'PAYER001'
    end
  end

  context 'confirm' do

    it 'should save payment info in order' do
      set_paypal_conf
      paypal_gateway.provider
      payment_params = JSON.parse(File.read('spec/fixtures/payment_response.json'))
      stub_payment = paypal_gateway.payment_source_class.new payment_params
      allow(paypal_gateway.payment_source_class).to receive(:find).and_return(stub_payment)
      france = create(:france)
      response = paypal_gateway.confirm('PAY-001', order)
      order.reload

      expect(response).to be_truthy
      expect(order.email).to eq 'spree@example.com'
      expect(order.ship_address.firstname).to eq 'Spree'
      expect(order.ship_address.lastname).to eq 'Example'
      expect(order.ship_address.address1).to eq 'Av. de la Pelouse, 87648672 Mayet'
      expect(order.ship_address.city).to eq 'Paris'
      expect(order.ship_address.zipcode).to eq '75002'
      expect(order.ship_address.country).to eq france
      expect(order.bill_address.firstname).to eq 'Test Name'
      expect(order.bill_address.lastname).to eq 'Example'
      expect(order.bill_address.address1).to eq 'Boulevard Jordan, 48'
      expect(order.bill_address.city).to eq 'Paris'
      expect(order.bill_address.zipcode).to eq '75014'
      expect(order.bill_address.country).to eq france
    end

  end

  context 'cancel' do

    it 'should cancel the payment' do
      set_paypal_conf
      paypal_gateway.provider
      mock_request 'https://api.sandbox.paypal.com/v1/oauth2/token', 'spec/fixtures/token.json'
      mock_request 'https://api.sandbox.paypal.com/v1/payments/sale/ABC00000000000001', 'spec/fixtures/sale_response.json', :get

      payment_params = JSON.parse(File.read('spec/fixtures/payment_response.json'))
      stub_payment = paypal_gateway.payment_source_class.new payment_params
      allow(paypal_gateway.payment_source_class).to receive(:find).and_return(stub_payment)
      sale_params = JSON.parse(File.read('spec/fixtures/sale_response.json'))
      stub_sale = paypal_gateway.payment_sale_class.new sale_params
      allow(paypal_gateway.payment_sale_class).to receive(:find).and_return(stub_sale)
      refund_params = JSON.parse(File.read('spec/fixtures/refund_response.json'))
      stub_refund = PayPal::SDK::REST::DataTypes::Refund.new refund_params
      allow(stub_sale).to receive(:refund_request).and_return(stub_refund)

      response = paypal_gateway.cancel(paypal_checkout.id)
      expect(response.success?).to be_truthy
      expect(response.message).to eq 'Refund Successful'
    end

  end

  def set_paypal_conf
    paypal_gateway.preferred_server = 'sandbox'
    paypal_gateway.preferred_client_id = 'abc-001'
    paypal_gateway.preferred_client_secret = 'abc-001'
  end

  def mock_request(url, filename, method = :post)
    stub_request(method, url).
      to_return(:status => 200, :body => File.read(filename), :headers => {})
  end
end
