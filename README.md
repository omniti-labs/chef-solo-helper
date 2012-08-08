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

In general, there are N+1 repositories for each chef installation:

 * Scripts to run chef (the + 1).  This is always present, and is checked out 
   into /var/chef-solo/scripts .
 * One or more checkouts, building up a set of cookbooks, roles, and node 
   configuration data.  The list of checkouts is determined dynamically by 
   executing a command in the config.sh file.  Each checkout is then delivered
   into the /var/chef-solo/checkouts directory.  Each may have a cookbooks, 
   nodes, roles, handlers, and data_bags directory.

#### Chef scripts repository

This step is normally performed by a bootstrapping script.

Check out the scripts repository to `/var/chef-solo/scripts/`:

    sudo mkdir /var/chef-solo
    cd
    git clone src@src.omniti.com:~internal/chef/scripts
    sudo mv scripts /var/chef-solo/scripts

#### List of Additional Checkouts/Repositories

run_chef.sh will fetch a list of additional checkouts.  The list should be in CSV format with no spaces between fields.  Example:

  git,src@src.omniti.com:~internal/chef/systems,omniti-internal-systems,master,chef.key
  git,src@src.omniti.com:~internal/chef/common,omniti-internal-common,multi-repo,chef.key
  git,git@trac-il.omniti.net:myproject/support/chef,myproject-chef,master,AGENT
  git,https://github.com/opscode-cookbooks/php.git,opscode-php/cookbooks/php,master,NONE

The fields are: VCS,repo address, directory name, branch, credentials
VCS may be either 'git' or 'svn'.
repo address is the identifier of the repository from which to obtain the checkout.
directory name is the path under /var/chef-solo/checkouts to clone/checkout into.  It may contain slashes.
branch is the name of the git branch.  Leave blank for svn (use repo address for svn branching)
credentials is the method to authenticate to the repo server.  NONE means use no authentication.  AGENT means to rely on a running ssh-agent to provide credentials.  All other values are taken to specify the location of a SSH private key, relative to /var/chef-solo, that should be used with a GIT_SSH wrapper.

On each run, the checkout list will be re-fetched, and each checkout will be cloned/checked-out (if absent) or pulled/updated (if present).  No facility exists for deleting a checkout.

#### Cross-Linking Roles, Nodes, Etc

Chef can use multiple cookbook directories, but only one roles, databags, and nodes directory.  To overcome this, run-chef maintains a 'combined' directory, with a 'combined/roles' directory containing links to EVERY role in the various checkouts.  

Combined objects are linked in the order specified in the checkout list file.  In the event of naming collisions, the LATER entry wins.

## Config File

This step is normally performed by a bootstrapping script, which will usually copy in or create a pre-existing config.sh

In /var/chef-solo/scripts/config.sh , add any settings you'd like to override.

#### FETCH_CHECKOUT_LIST_COMMAND

Default: "cat /var/chef-solo/checkout-list"

This command will be used to fetch the checkout list.  One simple example might be:

 FETCH_CHECKOUT_LIST_COMMAND="cat /var/chef-solo/checkout-list"
 FETCH_CHECKOUT_LIST_COMMAND="wget -O - -q http://trac.omniti.net/checkout-lists/myproject "

If the environment was bootstrapped, the bootstrapper may have delivered the checkout-list file.

#### INTERVAL

Default: 1800
If you run_chef.sh as a daemon (without the -o), number of seconds to sleep between runs.

#### CHEF_ROOT

Default: "/var/chef-solo"
Location on the filesystem for the various bits of this installation.

#### LOGFILE

Default:  /var/log/chef/solo.log
Location of the logfile.

#### SPLAY

Default: 120
When running in daemon mode, wait a random number of seconds up to this value, to offset the run interval.

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
