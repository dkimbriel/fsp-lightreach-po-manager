require 'webmock/rspec'

# Disable all HTTP requests except localhost by default
WebMock.disable_net_connect!(allow_localhost: true)
