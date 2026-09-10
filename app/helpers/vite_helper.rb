# Loads the React admin bundle (frontend/src/admin.tsx) either from the Vite dev server
# (development) or from the built manifest in public/app/.vite/manifest.json.
module ViteHelper
  MANIFEST = Rails.root.join("public/app/.vite/manifest.json")

  def vite_admin_tags
    if use_vite_dev_server?
      server = ENV.fetch("VITE_DEV_SERVER", "http://localhost:5173")
      safe_join([
        tag.script(type: "module", src: "#{server}/@vite/client"),
        tag.script(type: "module", src: "#{server}/src/admin.tsx")
      ])
    else
      manifest = vite_manifest
      entry = manifest["src/admin.tsx"]
      return "".html_safe unless entry
      chunks = [ entry ] + Array(entry["imports"]).filter_map { |key| manifest[key] }
      tags = chunks.flat_map { |c| Array(c["css"]) }.uniq.map { |css| tag.link(rel: "stylesheet", href: "/app/#{css}") }
      tags += Array(entry["imports"]).filter_map { |key| manifest.dig(key, "file") }.map { |file| tag.link(rel: "modulepreload", href: "/app/#{file}") }
      tags << tag.script(type: "module", src: "/app/#{entry['file']}")
      safe_join(tags)
    end
  end

  private

  def use_vite_dev_server?
    Rails.env.development? && ENV.fetch("VITE_DEV_SERVER_ENABLED", "true") == "true"
  end

  def vite_manifest
    return {} unless MANIFEST.exist?
    @vite_manifest ||= JSON.parse(MANIFEST.read)
  end
end
