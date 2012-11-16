#!/bin/bash
##############################################################################
# Bootstrap script for chef to be run on the remote server
##############################################################################

. $(dirname $0)/config.sh

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

if [[ ! -f /usr/bin/chef-solo ]]; then
    msg "Installing chef"
    safe rpm -Uvh http://rbel.co/rbel6
    safe yum install -y ruby ruby-devel ruby-ri ruby-rdoc ruby-shadow \
        gcc gcc-c++ automake autoconf make curl dmidecode wget
    safe wget http://production.cf.rubygems.org/rubygems/rubygems-1.6.2.tgz
    safe tar zxf rubygems-1.6.2.tgz
    pushd rubygems-1.6.2 > /dev/null
    safe ruby setup.rb --no-format-executable
    popd > /dev/null

    safe gem update --no-rdoc --no-ri
    safe gem install ohai --no-rdoc --no-ri
    safe gem install chef --no-rdoc --no-ri
fi

if [[ ! -f /usr/bin/git ]]; then
    msg "Installing git"
    safe yum install git
fi

mkdir -p $CHEF_ROOT

msg "Moving key in place"
safe mv $BOOTSTRAP_PATH/$KEY $CHEF_ROOT

if [[ -n $GIT_HOST ]]; then
    msg "Populating known hosts file"
    safe mkdir -p /root/.ssh/
    safe chmod 700 /root/.ssh/
    safe touch /root/.ssh/known_hosts
    safe chmod 600 /root/.ssh/known_hosts
    grep "$GIT_HOST" /root/.ssh/known_hosts > /dev/null ||
        safe ssh-keyscan $GIT_HOST >> /root/.ssh/known_hosts
fi

msg "Making temporary git ssh wrapper to use the chef key"
# Git uses the GIT_SSH environment variable to decide what to do when sshing
export GIT_SSH="$BOOTSTRAP_PATH/git-ssh-wrapper.sh"
echo "ssh -i $CHEF_ROOT/$KEY \"\$@\"" > $GIT_SSH
chmod +x $GIT_SSH

pushd $CHEF_ROOT > /dev/null
if [[ -n $CONFIG_REPO ]]; then
    msg "Cloning config repository"
    safe git clone $CONFIG_REPO config
fi
if [[ -n $COMMON_REPO ]]; then
    msg "Cloning common repository"
    safe git clone $COMMON_REPO common
fi
if [[ -n $SCRIPTS_REPO ]]; then
    msg "Cloning scripts repository"
    safe git clone $SCRIPTS_REPO scripts
fi
popd > /dev/null

msg "Running chef for the first time"
pushd $CHEF_ROOT/scripts > /dev/null
safe ./run_chef.sh -ov
popd > /dev/null
