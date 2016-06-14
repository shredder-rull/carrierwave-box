require 'cache_method'  
require 'carrierwave'
require "carrierwave/box/client"
require 'carrierwave/storage/box'
require "carrierwave/box/version"

class CarrierWave::Uploader::Base
  # Plain auth
  add_config :box_email
  add_config :box_password

  add_config :box_client_id
  add_config :box_client_secret

  add_config :box_access_type

  # jwt auth
  add_config :jwt_private_key
  add_config :jwt_private_key_path
  add_config :jwt_private_key_password
  add_config :jwt_public_key_id
  add_config :jwt_user_id
  add_config :box_enterprise_id

  configure do |config|
    config.storage_engines[:box] = 'CarrierWave::Storage::Box'
  end
end
