# Fixes the TRMNL "Daycast" weather plugin after importing it into Terminus, configures it
# for Guarapuava-PR in Brazilian Portuguese, attaches it to the device and renders the screen.
# Safe to run more than once.
#
# Usage (from the terminus/ folder):
#   docker compose cp ../terminus-customizations/fix_daycast.rb web:/app/tmp_fix_daycast.rb
#   docker compose exec web bundle exec hanami run tmp_fix_daycast.rb
#   docker compose exec web rm /app/tmp_fix_daycast.rb
#
# Optional env: DAYCAST_LABEL (default "Daycast"), DEVICE_ID (default 1).

require "sidekiq"

Sidekiq.configure_client { |config| config.redis = {url: ENV.fetch("KEYVALUE_URL")} }

LABEL = ENV.fetch("DAYCAST_LABEL", "Daycast")
DEVICE_ID = Integer(ENV.fetch("DEVICE_ID", "1"))
SETTINGS = {
  "lat_lon" => "-25.390448929650905,-51.461431835084795",
  "place_name" => "Guarapuava",
  "language" => "pt",
  "units" => "metric",
  "wind" => "kmh",
  "clock" => "24"
}.freeze

extensions = Hanami.app["repositories.extension"]
exchanges = Hanami.app["repositories.extension_exchange"]

record = Hanami.app["relations.extension"].where(label: LABEL).one or abort "Extension #{LABEL.inspect} not found."
extension = extensions.find record[:id]

# 1. Settings: location, language, units.
values = Hash(extension.data["values"]).merge SETTINGS
extensions.update extension.id, data: extension.data.merge("values" => values)

# 2. Template fixes for Terminus.
template = extension.template
  # The importer rewrote bare captures into source_1.* lookups that don't exist.
  .gsub("source_1.wx_attrs", "wx_attrs")
  .gsub("source_1.wx_json", "wx_json")
  # Terminus has `jsonify`, not `json`.
  .gsub(/\|\s*json\s*\}\}/, "| jsonify }}")
  # Terminus strips type="application/json", so the JSON would run as JavaScript and break the screenshot.
  .gsub(%r{<script type="application/json" class="wx-data">(.*?)</script>}m) do
    %(<div class="wx-data" style="display:none">#{Regexp.last_match(1)}</div>)
  end
  # Terminus strips CSS custom property declarations, so inline their values.
  .gsub("var(--k)", "1")
  .gsub("var(--pad)", "24px")
  # The thin grey sub line dithers into dots on a 1-bit panel.
  .gsub('class="wx-sub description lg:description--large lg:text--regular"',
        'class="wx-sub text--base text--black" style="color:#000;font-weight:600;opacity:1"')
extensions.update extension.id, template: template

# 3. Exchange URL: plugin settings live in extension.values, not source_1.
Hanami.app["relations.extension_exchange"].where(extension_id: extension.id).to_a.each do |row|
  exchanges.update row[:id], template: row[:template].gsub("source_1.lat_lon", "extension.values.lat_lon")
  result = Hanami.app["aspects.extensions.exchanges.refresher"].call exchanges.find(row[:id])
  puts "Exchange #{row[:id]} refresh: #{result.success? ? 'ok' : result.failure}"
end

# 4. Attach to the device and render.
extensions.update_with_devices extension.id, {}, [DEVICE_ID]
screen = Hanami.app["aspects.extensions.screen_upserter"].call extensions.find(extension.id), device_id: DEVICE_ID
puts "Screen: #{screen.success? ? 'ok' : screen.failure}"
