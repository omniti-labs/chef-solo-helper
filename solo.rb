# chef-solo configuration
file_cache_path "/var/chef-solo/cache"
cookbook_path ["/var/chef-solo/common/cookbooks",
    "/var/chef-solo/config/cookbooks"]
role_path "/var/chef-solo/config/roles"
data_bag_path "/var/chef-solo/config/data_bags"

# Updated resources handler
require "/var/chef-solo/scripts/handlers/updated_resources"
report_handlers << SimpleReport::UpdatedResources.new
exception_handlers << SimpleReport::UpdatedResources.new
