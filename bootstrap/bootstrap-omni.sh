#!/bin/bash
##############################################################################
# Bootstrap script for chef to be run on the remote server
# Version for OMNIOS
##############################################################################

. $(dirname $0)/config.sh

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

GIT=/usr/bin/git

if [[ -e $CHEF_ROOT ]]; then
    msg "Found existing $CHEF_ROOT - moving to $CHEF_ROOT.old"
    mv $CHEF_ROOT $CHEF_ROOT.old
fi

mkdir -p $CHEF_ROOT

msg "Moving key in place"
safe mv $BOOTSTRAP_PATH/$KEY $CHEF_ROOT
safe chmod 600 $CHEF_ROOT/$KEY
safe chown root:root $CHEF_ROOT/$KEY

if [[ -n $SCHLEP_FILES ]]; then
    for FILE in "$SCHLEP_FILES"; do 
        msg "Moving in schlep file $FILE"
        safe mv $BOOTSTRAP_PATH/$FILE $CHEF_ROOT
        safe chown root:root $CHEF_ROOT/$FILE
    done
fi

# Grandfather in old GIT_HOST variable
if [[ -z $SSH_KNOWN_HOSTS ]]; then 
    SSH_KNOWN_HOSTS=$GIT_HOST
fi

if [[ -n $SSH_KNOWN_HOSTS ]]; then
    msg "Populating known hosts file"
    safe mkdir -p /root/.ssh/
    safe chmod 700 /root/.ssh/
    safe touch /root/.ssh/known_hosts
    safe chmod 600 /root/.ssh/known_hosts
    for HOST in "$SSH_KNOWN_HOSTS"; do
        grep "$HOST" /root/.ssh/known_hosts > /dev/null || \
         ssh-keyscan -t rsa,dsa $HOST >> /root/.ssh/known_hosts
    done
fi

msg "Making temporary git ssh wrapper to use the chef key"
# Git uses the GIT_SSH environment variable to decide what to do when sshing
export GIT_SSH="$BOOTSTRAP_PATH/git-ssh-wrapper.sh"
echo "ssh -i $CHEF_ROOT/$KEY \"\$@\"" > $GIT_SSH
chmod +x $GIT_SSH

msg "Ensuring required packages are installed"
pkg install git chef

pushd $CHEF_ROOT > /dev/null
if [[ -n $SCRIPTS_REPO ]]; then
    msg "Cloning scripts repository"
    safe $GIT clone $SCRIPTS_REPO scripts
fi
popd > /dev/null

msg "Creating local config"
cat > $CHEF_ROOT/scripts/config.sh <<EOT
# Fix various paths to get chef-solo and git working
export PATH=\$PATH:/opt/omni/bin
export PATH=\$PATH:/opt/omni/lib/ruby/gems/1.9/gems/chef-0.10.8/bin
export PATH=\$PATH:/usr/bin

export GEM_PATH=/opt/omni/lib/ruby/gems/1.9
export GEM_HOME=/opt/omni/lib/ruby/gems/1.9

# Pass on checkout fetch command
export FETCH_CHECKOUT_LIST_COMMAND="$FETCH_CHECKOUT_LIST_COMMAND"

EOT

msg "Running chef for the first time"
pushd $CHEF_ROOT/scripts > /dev/null
safe ./run_chef.sh -ov
popd > /dev/null
