# chef-solo configuration
file_cache_path "/var/chef-solo/cache"
cookbook_path ["/var/chef-solo/common/cookbooks",
    "/var/chef-solo/config/cookbooks"]
role_path "/var/chef-solo/config/roles"
data_bag_path "/var/chef-solo/config/data_bags"

# Include any handlers
Dir.glob('/var/chef-solo/scripts/handlers/*.rb') { |f| require f }
Dir.glob('/var/chef-solo/scripts/handlers/site/*.rb') { |f| require f }
