# Load tailwindcss-rails tasks
# The gem has `require: false` in Gemfile for runtime optimization,
# but we need its Rake tasks for asset compilation
require "tailwindcss-rails"

# Load the gem's rake tasks (they are not auto-loaded due to require: false)
tailwindcss_gem_path = Gem::Specification.find_by_name("tailwindcss-rails").gem_dir
Dir.glob("#{tailwindcss_gem_path}/lib/tasks/**/*.rake").each { |r| load r }
