# Loaded by db/seeds.rb. Idempotent: re-running upserts each prompt by slug,
# leaving manual admin edits to active=false versions alone.
#
# Source of truth is db/ai_prompts/*.yml — one file per slug, easy to diff.
# Each YAML must define: slug, name, description, provider, model, kind,
# max_tokens, temperature, system_template, user_template. Anything else is
# ignored. ERB templates live verbatim inside the system_template /
# user_template block scalars and are rendered by AiPrompt#render at call time.

require "yaml"

require_relative "../app/models/ai_prompt"

prompt_dir = Rails.root.join("db", "ai_prompts")
files = Dir[prompt_dir.join("*.yml")].sort

if files.empty?
  warn "  ai_prompt seed: no YAML files found in #{prompt_dir}"
end

files.each do |path|
  attrs = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
  slug  = attrs["slug"].to_s

  if slug.blank?
    warn "  ai_prompt seed: #{path} missing slug, skipped"
    next
  end

  rec = AiPrompt.find_or_initialize_by(slug: slug)
  cache_attrs = {}
  cache_attrs[:cacheable]          = attrs["cacheable"]          unless attrs["cacheable"].nil?
  cache_attrs[:cache_ttl_seconds]  = attrs["cache_ttl_seconds"]  unless attrs["cache_ttl_seconds"].nil?

  rec.assign_attributes(
    {
      name:            attrs["name"],
      description:     attrs["description"],
      provider:        attrs["provider"],
      model:           attrs["model"],
      kind:            attrs["kind"] || "text",
      max_tokens:      attrs["max_tokens"],
      temperature:     attrs["temperature"],
      system_template: attrs["system_template"].to_s,
      user_template:   attrs["user_template"].to_s
    }.merge(cache_attrs)
  )
  rec.active = true if rec.active.nil?

  if rec.save
    puts "  ai_prompt: #{slug} (#{rec.previously_new_record? ? 'new' : 'updated'})"
  else
    warn "  ai_prompt FAILED: #{slug} — #{rec.errors.full_messages.join(', ')}"
  end
end
