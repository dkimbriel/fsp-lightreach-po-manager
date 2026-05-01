module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session
      before_action :authenticate_user!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def render_success(data = {}, status: :ok)
        render json: { success: true, data: data }, status: status
      end

      def render_error(message, status: :unprocessable_entity, errors: nil)
        response = { success: false, error: message }
        response[:errors] = errors if errors.present?
        render json: response, status: status
      end

      def not_found(exception)
        render_error(exception.message, status: :not_found)
      end

      def unprocessable_entity(exception)
        render_error(exception.message, status: :unprocessable_entity, errors: exception.record&.errors)
      end
    end
  end
end
