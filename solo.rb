# chef-solo configuration
file_cache_path "/var/chef-solo/cache"

# These are created by run-chef.sh, with symlinks
role_path "/var/chef-solo/combined/roles"
data_bag_path "/var/chef-solo/combined/data_bags"

# The checkouts each may contain a cookbooks directory.  run-chef.sh will 
# write a .cookbook-order file, and we should respect it.
cookbook_paths = []
IO.readlines('/var/chef-solo/.cookbook-order').each do |line|
  path = '/var/chef-solo/checkouts/' + line.chomp
  if File.exist? path then
    cookbook_paths.push path
  end
end

cookbook_path cookbook_paths

# Include any handlers
# Note that we also have handler under the combined/handlers area
Dir.glob('/var/chef-solo/scripts/handlers/*.rb') { |f| require f }
Dir.glob('/var/chef-solo/scripts/handlers/site/*.rb') { |f| require f }
