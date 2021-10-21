module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Core::ControllerHelpers::Locale
        include Spree::Core::ControllerHelpers::Currency

        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from CanCan::AccessDenied, with: :access_denied
        rescue_from Doorkeeper::Errors::DoorkeeperError, with: :access_denied_401
        rescue_from Spree::Core::GatewayError, with: :gateway_error
        rescue_from ActionController::ParameterMissing, with: :error_during_processing
        if defined?(JSONAPI::Serializer::UnsupportedIncludeError)
          rescue_from JSONAPI::Serializer::UnsupportedIncludeError, with: :error_during_processing
        end
        rescue_from ArgumentError, with: :error_during_processing

        def content_type
          Spree::Api::Config[:api_v2_content_type]
        end

        protected

        def serialize_collection(collection)
          collection_serializer.new(
            collection,
            collection_options(collection).merge(params: serializer_params)
          ).serializable_hash
        end

        def serialize_resource(resource)
          resource_serializer.new(
            resource,
            params: serializer_params,
            include: resource_includes,
            fields: sparse_fields
          ).serializable_hash
        end

        def paginated_collection
          @paginated_collection ||= collection_paginator.new(sorted_collection, params).call
        end

        def collection_paginator
          Spree::Api::Dependencies.storefront_collection_paginator.constantize
        end

        def render_serialized_payload(status = 200)
          render json: yield, status: status, content_type: content_type
        end

        def render_error_payload(error, status = 422)
          json = if error.is_a?(ActiveModel::Errors)
                   { error: error.full_messages.to_sentence, errors: error.messages }
                 elsif error.is_a?(Struct)
                   { error: error.to_s, errors: error.to_h }
                 else
                   { error: error }
                 end

          render json: json, status: status, content_type: content_type
        end

        def render_result(result)
          if result.success?
            render_serialized_payload { serialize_resource(result.value) }
          else
            render_error_payload(result.error)
          end
        end

        def spree_current_user
          return nil unless doorkeeper_token
          return @spree_current_user if @spree_current_user

          doorkeeper_authorize!

          @spree_current_user ||= doorkeeper_token.resource_owner
        end

        def spree_authorize!(action, subject, *args)
          authorize!(action, subject, *args)
        end

        def require_spree_current_user
          raise CanCan::AccessDenied if spree_current_user.nil?
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Dependencies.ability_class.constantize.new(spree_current_user)
        end

        def request_includes
          # if API user want's to receive only the bare-minimum
          # the API will return only the main resource without any included
          if params[:include]&.blank?
            []
          elsif params[:include].present?
            params[:include].split(',')
          end
        end

        def resource_includes
          (request_includes || default_resource_includes).map(&:intern)
        end

        # overwrite this method in your controllers to set JSON API default include value
        # https://jsonapi.org/format/#fetching-includes
        # eg.:
        # %w[images variants]
        # ['variant.images', 'line_items']
        def default_resource_includes
          []
        end

        def sparse_fields
          return unless params[:fields]&.respond_to?(:each)

          fields = {}
          params[:fields].
            select { |_, v| v.is_a?(String) }.
            each { |type, values| fields[type.intern] = values.split(',').map(&:intern) }
          fields.presence
        end

        def serializer_params
          {
            currency: current_currency,
            locale: current_locale,
            price_options: current_price_options,
            store: current_store,
            user: spree_current_user,
            image_transformation: params[:image_transformation],
            taxon_image_transformation: params[:taxon_image_transformation]
          }
        end

        def record_not_found
          render_error_payload(I18n.t(:resource_not_found, scope: 'spree.api'), 404)
        end

        def access_denied(exception)
          render_error_payload(exception.message, 403)
        end

        def access_denied_401(exception)
          render_error_payload(exception.message, 401)
        end

        def gateway_error(exception)
          render_error_payload(exception.message)
        end

        def error_during_processing(exception)
          result = error_handler.call(exception: exception, opts: { user: spree_current_user })

          render_error_payload(result.value[:message], 400)
        end

        def error_handler
          Spree::Api::Dependencies.error_handler.constantize
        end
      end
    end
  end
end
