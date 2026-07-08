# SEO/AEO/GEO helpers for the public (marketing-layout) pages.
#
# Canonical URLs always point at the apex host in production so
# www.wanderply.com and any stray hosts consolidate ranking signals.
module SeoHelper
  CANONICAL_HOST = "https://wanderply.com".freeze

  def canonical_base_url
    Rails.env.production? ? CANONICAL_HOST : request.base_url
  end

  # The canonical URL for the current request (path only — query strings
  # never define a distinct public document on this site).
  def canonical_url
    content_for(:canonical).presence || (canonical_base_url + request.path)
  end

  def default_og_image_url
    "#{canonical_base_url}/icon.png"
  end

  # Organization node reused by the site-wide and Article JSON-LD.
  def organization_ld
    {
      "@type" => "Organization",
      "@id"   => "#{CANONICAL_HOST}/#about",
      "name"  => "Wanderply",
      "url"   => CANONICAL_HOST,
      "logo"  => "#{CANONICAL_HOST}/icon.png"
    }
  end
end
