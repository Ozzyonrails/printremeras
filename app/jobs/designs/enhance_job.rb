module Designs
  class EnhanceJob < ApplicationJob
    queue_as :rendering
    retry_on ImageEnhancement::Provider::Error, wait: :polynomially_longer, attempts: 3

    def perform(design_id, target_width_px, target_height_px)
      Designs::Enhance.call(design: Design.find(design_id), target_width_px: target_width_px, target_height_px: target_height_px)
    end
  end
end
