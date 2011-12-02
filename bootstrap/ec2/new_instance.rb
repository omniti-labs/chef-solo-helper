#!/usr/bin/env ruby
require 'rubygems'
require 'fog'
require 'mixlib/config'
# Highline is required for chef, so we're good to require it here
require 'highline/import'

class MyConfig
    extend(Mixlib::Config)

    # AWS keys
    aws_access_key_id ""
    aws_secret_access_key ""
end
MyConfig.from_file("config.rb")

images = {
    # Ubuntu 10.04 LTS us-east-1
    :ami_32 => {
        "32-bit, EBS storage" => "ami-ab36fbc2",
        "32-bit, instance storage" => "ami-6936fb00"
    },
    :ami_64 => {
        "64-bit, EBS storage" => "ami-ad36fbc4",
        "64-bit, instance storage" => "ami-1136fb78"
    }
}

instance_types = {
    :m1_small =>    [:ami_32],
    :c1_medium =>   [:ami_32],
    :m1_large =>    [:ami_64],
    :m1_xlarge =>   [:ami_64],
    :t1_micro =>    [:ami_32, :ami_64],
    :m2_xlarge =>   [:ami_64],
    :m2_2xlarge =>  [:ami_64],
    :m2_4xlarge =>  [:ami_64],
    :c1_xlarge =>   [:ami_64]
}

compute = Fog::Compute.new(
    :provider => 'AWS',
    :aws_access_key_id => MyConfig[:aws_access_key_id],
    :aws_secret_access_key => MyConfig[:aws_secret_access_key]
)

# Fetch available security groups from AWS
secgroups = compute.security_groups.all.collect{|g| g.name}.sort

availability_zones = compute.describe_availability_zones().body[
    'availabilityZoneInfo'].collect{|z| z['zoneName'].to_sym}.sort

# TODO - prompt for everything here
instance_name = ask("Instance name?  ") { |q| q.default = "test-instance" }
instance_type = choose do |menu|
    menu.prompt = "Instance type?  "
    menu.choices(*instance_types.keys)
end
image_type = choose do |menu|
    menu.prompt = "Image ID?  "
    menu.choices(*instance_types[instance_type].collect{
        |t| images[t].keys}.flatten.sort)
end
image_id = images.values.reduce{|r,v| r.merge(v)}[image_type]
puts image_id
secgroup = choose do |menu|
    menu.prompt = "Security group?  "
    menu.choices(*secgroups)
end
availability_zone = choose do |menu|
    menu.prompt = "Availability zone?  "
    menu.choices(*availability_zones)
end


puts "Making new AWS instance with the following settings:"
puts "Name: #{instance_name}"
puts "Instance type: #{instance_type}"
puts "Security group: #{secgroup}"
puts "Availability zone: #{availability_zone}"

exit unless agree("OK to create?  ")

puts "Creating instance..."

server = compute.servers.create(
    :image_id => image_id,
    :groups => [secgroup], # Security groups
    :flavor_id => instance_type.to_s.sub('_', '.'), # instance type
    :key_name => MyConfig.aws_ssh_key_name, # SSH key name (from config file)
    :availability_zone => availability_zone # Availability zone
)

puts "Instance ID #{server.id}"

print "Waiting for server to be ready"
server.wait_for { print "."; ready? }
puts "ready"

# Set tag for server name
compute.create_tags(server.id, { "Name" => instance_name })

puts "Address: #{server.dns_name}"
puts

puts "Now run the following to bootstrap chef:"
puts "./bootstrap-ssh.sh #{server.dns_name} #{instance_name}"
