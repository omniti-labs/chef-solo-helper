# chef-solo configuration
file_cache_path "/var/chef-solo"
cookbook_path File.join(File.dirname(__FILE__), "cookbooks")
role_path File.join(File.dirname(__FILE__), "roles")
