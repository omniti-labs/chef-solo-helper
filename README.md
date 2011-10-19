# Chef

## Installation instructions

### Git key

Get the secret key for the account that has access to the git repository where
you're storing the chef repository, and put it in /root/.ssh/id_rsa_chef:

    sudo mkdir /root/.ssh
    sudo chmod 700 /root/.ssh
    sudo cp id_rsa_chef /root/.ssh/
    sudo chmod 600 /root/.ssh/id_rsa_chef

### Chef repository

Check out the chef repository to `/var/chef-solo/config/`:

    sudo mkdir /var/chef-solo
    cd
    git clone src@src.omniti.com:~systems/chef/myrepo
    sudo mv myrepo /var/chef-solo/config


## Running chef

The `run-chef.sh` script is used to run chef. It can:

 - update from git before running chef (optional)
 - run once, or multiple times
 - when running multiple times, apply a random delay at the beginning

### Testing

Run chef once, without updating from git first:

    sudo ./run_chef.sh -o -n

Run chef once, updating from git first:

    sudo ./run_chef.sh -o

### Running as a daemon

By default, run_chef.sh will run continuously, running chef at regular
intervals.

## Changes from 'full' chef

 - cookbooks, roles and databags work identically to full chef, only you don't
   upload them with the knife command (there isn't a knife command)
 - searching isn't available (there's no server to search)
 - node configuration is kept in json files in the nodes/ directory and not on
   the chef server. These files contain the run list for each host.
