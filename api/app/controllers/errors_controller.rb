# frozen_string_literal: true

# Answers every path the API does not serve. Without it an unknown path raised
# a routing error and the framework's error page went out instead of JSON.
class ErrorsController < ActionController::API
  def route_not_found
    render json: { error: 'Route not found', status: 404 }, status: :not_found
  end
end
