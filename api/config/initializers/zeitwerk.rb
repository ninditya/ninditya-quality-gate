# frozen_string_literal: true

# The WebSocket middlewares are named with a capital S ("WebSocket"), which is
# not what their file names inflect to. Without these inflections the app
# cannot eager-load, and production eager-loads at boot.
Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    'audio_websocket_middleware'    => 'AudioWebSocketMiddleware',
    'coverage_websocket_middleware' => 'CoverageWebSocketMiddleware'
  )
end
