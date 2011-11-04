# chef-solo configuration
file_cache_path "/var/chef-solo/cache"
cookbook_path ["/var/chef-solo/common/cookbooks",
    "/var/chef-solo/config/cookbooks"]
role_path "/var/chef-solo/config/roles"
