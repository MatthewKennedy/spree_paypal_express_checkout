module Spree
  module Gateway::PaypalWebProfile

    def web_profile_class
      PayPal::SDK::REST::DataTypes::WebProfile
    end

    def create_profile(options)
      web_profile_class.new(request_hash(options)).create
    end

    def update_profile(id, options)
      find_profile(id).partial_update(options)
    end

    def delete_profile(id)
      find_profile(id).delete
    end

    def find_profile(id)
      web_profile_class.find(id)
    end

    def get_list
      web_profile_class.get_list
    end

    def first_or_new(options)
      list = get_list
      if list.empty?
        selected_profile = web_profile_class.new(request_hash(options))
      else
        selected_profile = list.find { |item| have_correct_options?(item, options) }
        if selected_profile.nil?
          selected_profile = web_profile_class.new(request_hash(options))
        end
      end
      selected_profile
    end

    def request_hash(options)
      {
        name: options[:profile_name],
        presentation:{
          brand_name: options[:brand_name],
          locale_code: options[:locale_code],
        },
        input_fields:{
          allow_note: options[:allow_note],
          no_shipping: format_shipping_config(options[:no_shipping]),
          address_override: options[:address_override],
        },
        flow_config:{
          landing_page_type: options[:landing_page_type],
          return_uri_http_method: 'get'
        }
      }
    end

    def have_correct_options?(profile, options)
      return false if profile.presentation.try(:brand_name).to_s != options[:brand_name]
      return false if profile.presentation.try(:locale_code) != options[:locale_code]
      return false if profile.input_fields.try(:no_shipping) != format_shipping_config(options[:no_shipping])
      return false if profile.input_fields.try(:address_override) != options[:address_override].to_i
    end

    def format_shipping_config(value)
      value.present? ? '1' : '2'
    end

  end
end
