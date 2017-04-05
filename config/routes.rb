Spree::Core::Engine.routes.draw do

  post 'paypal_checkouts/create/:payment_method_id', to: 'paypal_checkouts#create', as: :paypal_checkouts_create
  post 'paypal_checkouts/confirm/:payment_method_id', to: 'paypal_checkouts#confirm', as: :paypal_checkouts_confirm
  post 'paypal_checkouts/finalize/:payment_method_id', to: 'paypal_checkouts#finalize', as: :paypal_checkouts_finalize
  post 'paypal_checkouts/cancel', to: 'paypal_checkouts#cancel', as: :paypal_checkouts_cancel

end
