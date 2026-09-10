class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.public_storage = Rails.configuration.x.storage.public_service
  def self.private_storage = Rails.configuration.x.storage.private_service
end
