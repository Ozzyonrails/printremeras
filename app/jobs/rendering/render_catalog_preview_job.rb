module Rendering
  class RenderCatalogPreviewJob < ApplicationJob
    queue_as :rendering
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(catalog_item_id)
      Rendering::RenderCatalogPreview.call(catalog_item: CatalogItem.find(catalog_item_id))
    end
  end
end
