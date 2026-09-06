#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the site exactly the way GitHub Pages does (plain `jekyll build`,
# _config.yml only — no _config_dev.yml, no --baseurl override) and then
# checks every internal link/asset reference in the output:
#
#   1. every root-relative href/src actually starts with site.baseurl
#      (the bug class that broke the nav menu and training page: a raw
#      `{{ item.url }}` or hardcoded href="/contact/" instead of
#      `| relative_url`, invisible while baseurl was "" and broken the
#      moment it wasn't)
#   2. every such link actually resolves to a file in the built site
#      (catches typos/renamed pages, not just missing-baseurl bugs)
#   3. the built HTML doesn't contain "localhost"/"127.0.0.1" (a sign the
#      dev config leaked into a production build)
#
# Usage: bundle exec ruby bin/checklinks.rb

require "yaml"
require "fileutils"
require "tmpdir"

root = File.expand_path("..", __dir__)
Dir.chdir(root)

config = YAML.load_file("_config.yml")
baseurl = config["baseurl"].to_s

errors = []
warnings = []

Dir.mktmpdir("checklinks-site-") do |dest|
  puts "Building site (production config) into #{dest} ..."
  build_ok = system("bundle exec jekyll build --destination #{dest} --quiet")
  unless build_ok
    warn "jekyll build failed"
    exit 1
  end

  html_files = Dir.glob(File.join(dest, "**", "*.html"))
  if html_files.empty?
    warn "No HTML files found in build output — build likely failed silently"
    exit 1
  end

  # Anything ending in one of these is a real asset path segment, not a
  # Jekyll "pretty" page URL, so it's checked as an exact file.
  file_href_re = /\.[a-zA-Z0-9]+\z/

  resolve = lambda do |href|
    # Strip baseurl prefix (already verified present by the caller),
    # fragment, and query string, then map to a path under `dest`.
    path = href.sub(/\A#{Regexp.escape(baseurl)}/, "")
    path = path.split("#").first || "/"
    path = path.split("?").first || "/"
    path = "/" if path.empty?

    if path.match?(file_href_re)
      File.file?(File.join(dest, path))
    else
      File.file?(File.join(dest, path, "index.html")) || File.file?(File.join(dest, "#{path}.html"))
    end
  end

  html_files.each do |file|
    relative_file = file.sub("#{dest}/", "")
    content = File.read(file, encoding: "UTF-8")

    if content.match?(/localhost|127\.0\.0\.1/)
      errors << "#{relative_file}: contains \"localhost\"/\"127.0.0.1\" — looks like it was built with the dev config, not production"
    end

    content.scan(/(?:href|src)="([^"]+)"/).flatten.each do |link|
      next if link.start_with?("http://", "https://", "mailto:", "tel:", "//")
      next if link.start_with?("#") # pure in-page anchor
      next unless link.start_with?("/") # relative (e.g. "thanks/") — out of scope here

      unless baseurl.empty? || link.start_with?(baseurl)
        errors << "#{relative_file}: link \"#{link}\" is missing the baseurl prefix (\"#{baseurl}\") — check for a raw href/src that skipped the relative_url filter"
        next
      end

      unless resolve.call(link)
        errors << "#{relative_file}: link \"#{link}\" doesn't resolve to any file in the built site"
      end
    end
  end
end

puts
if errors.empty?
  puts "✅ checklinks: #{Dir.glob('**/*.html').length rescue '?'} source pages, no broken/misconfigured links found."
else
  puts "❌ checklinks found #{errors.size} problem(s):\n\n"
  errors.each { |e| puts "  - #{e}" }
  puts
end

warnings.each { |w| puts "⚠️  #{w}" }

exit(errors.empty? ? 0 : 1)
