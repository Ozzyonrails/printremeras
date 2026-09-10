# Serves the built React app (public/app/index.html) for every storefront route.
# In development the Vite dev server (bin/dev) serves the SPA instead.
class SpaController < ApplicationController
  INDEX = Rails.root.join("public/app/index.html")

  def show
    if INDEX.exist?
      render file: INDEX, layout: false, content_type: "text/html"
    else
      render plain: "Frontend not built. Run `cd frontend && npm run build`, or use the Vite dev server on http://localhost:5173.", status: :service_unavailable
    end
  end
end
