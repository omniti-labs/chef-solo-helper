# Chef scripts

This repository contains scripts for running chef in a serverless
environment with one or more git repositories containing the chef
configuration.

## Installation instructions

### Git key

Get the secret key for the account that has access to the git repository where
you're storing the chef repository, and put it in /root/.ssh/id_rsa_chef:

    sudo mkdir /root/.ssh
    sudo chmod 700 /root/.ssh
    sudo cp id_rsa_chef /root/.ssh/
    sudo chmod 600 /root/.ssh/id_rsa_chef

### Repositories

In general, there are 3 repositories for each chef installation:

 * Scripts to run chef
 * A project specific repository (this is the main chef configuration)
 * A common/shared repository for cookbooks common to all installations

All of these go under /var/chef-solo in the scripts, config and common
directories respectively.

#### Chef scripts repository

Check out the scripts repository to `/var/chef-solo/scripts/`:

    sudo mkdir /var/chef-solo
    cd
    git clone src@src.omniti.com:~internal/chef/scripts
    sudo mv scripts /var/chef-solo/scripts

#### Project specific repository

Check out the project specific chef repository to `/var/chef-solo/config/`:

    git clone src@src.omniti.com:~systems/chef/myrepo
    sudo mv myrepo /var/chef-solo/config

### Common cookbooks repository

Check out the common chef repository to `/var/chef-solo/common/`:

    git clone src@src.omniti.com:~internal/chef/common
    sudo mv common /var/chef-solo/common

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

Run chef once, don't update from git, and print out lots of debug information:

    sudo ./run_chef.sh -ondv

### Running as a daemon

By default, run_chef.sh will run continuously, running chef at regular
intervals.

There is an smf manifest in the resources directory, it looks in
/var/chef-solo/config for run_chef.sh:

    svccfg import resources/chef-manifest.xml
    svcadm enable chef

## Changes from 'full' chef

 - cookbooks, roles and databags work identically to full chef, only you don't
   upload them with the knife command (there isn't a knife command)
 - searching isn't available (there's no server to search)
 - node configuration is kept in json files in the nodes/ directory and not on
   the chef server. These files contain the run list for each host.
