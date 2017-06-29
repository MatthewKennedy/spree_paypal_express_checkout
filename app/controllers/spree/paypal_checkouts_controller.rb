module Spree
  class PaypalCheckoutsController < StoreController

    skip_before_action :verify_authenticity_token, only: [:create, :confirm, :finalize]

    def create
      @order = Spree::Order.friendly.find params[:order_id]
      @order.set_cart_shipping
      @payment_method = PaymentMethod.find(params[:payment_method_id])
      @paypal_payment = @payment_method.request_payment(@order)

      if @paypal_payment.create
        render json: { paymentID: @paypal_payment.id }
      else
        render status: 500, json: { error: @paypal_payment.error }
      end
    end

    def confirm
      @order = Spree::Order.friendly.find params[:order_id]

      paypal_checkout = Spree::PaypalCheckout.new(
        payer_id: params[:payerID],
        payment_id: params[:paymentID]
      )

      @order.payments.create!({
        source: paypal_checkout,
        amount: @order.total,
        payment_method_id: params[:payment_method_id]
      })

      until @order.state == "complete"
        if @order.next!
          @order.update_with_updater!
        else
          # TODO: refund no pagamento (ou erro)
          render status: 500, json: { error: @order.errors.full_messages.join(', ') }
        end
      end

      flash.now['order_completed'] = true
      render json: { path: completion_route }
    end

    def finalize
      @order = Spree::Order.friendly.find params[:order_id]
      @payment_method = Spree::PaymentMethod.find params[:payment_method_id]

      paypal_checkout = Spree::PaypalCheckout.new(
        payer_id: params[:payerID],
        payment_id: params[:paymentID]
      )

      @order.payments.create!({
        source: paypal_checkout,
        amount: @order.total,
        payment_method_id: params[:payment_method_id]
      })

      unless @payment_method.confirm(params[:paymentID], @order)
        render status: 500, json: { error: @order.errors.full_messages.join(', ') } and return
      end

      until @order.state == "complete"
        if @order.next!
          @order.update_with_updater!
        else
          payment = @order.payments.last
          @payment_method.refund(@order.total, paypal_checkout, payment.gateway_options)
          render status: 500, json: { error: @order.errors.full_messages.join(', ') } and return
        end
      end

      render json: { path: spree.paypal_checkouts_order_path(@order.number) }
    end

    def order
      @order = Spree::Order.friendly.find params[:order_id]
      flash['order_completed'] = true
      redirect_to completion_route
    end

    private

    def completion_route(custom_params = nil)
      spree.order_path(@order, custom_params)
    end
  end
end
