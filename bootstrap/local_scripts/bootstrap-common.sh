#!/bin/bash
# Common functions used across bootstrap scripts

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

load_config() {
    . $(dirname $0)/config.sh
}

install_chef() {
    # You should override this with something to install chef
    if [[ ! -f /usr/bin/chef-solo ]]; then
        error "Chef not installed"
    fi
}

install_git() {
    # You should override this with something to install git
    if [[ ! -f /usr/bin/git ]]; then
        error "Git not installed"
    fi
}

install_packages() {
    # This is just a wrapper around install_git and install_chef
    # You can either make separate install_git and install_chef functions, or
    # you can just override install_packages if you do both at once.
    install_git
    install_chef
}

make_chef_dir() {
    # Makes /var/chef-solo (or whatever you configured)
    if [[ -e $CHEF_ROOT ]]; then
        msg "Found existing $CHEF_ROOT - moving to $CHEF_ROOT.old"
        mv $CHEF_ROOT $CHEF_ROOT.old
    fi
    mkdir -p $CHEF_ROOT
}

install_key() {
    # Moves the chef key in place
    msg "Moving key in place"
    safe mv $BOOTSTRAP_PATH/$KEY $CHEF_ROOT
    safe chmod 600 $CHEF_ROOT/$KEY
    safe chown root:root $CHEF_ROOT/$KEY
}

schlep_files() {
    if [[ -n $SCHLEP_FILES ]]; then
        for FILE in "$SCHLEP_FILES"; do
            msg "Moving in schlep file $FILE"
            safe mv $BOOTSTRAP_PATH/$FILE $CHEF_ROOT
            safe chown root:root $CHEF_ROOT/$FILE
        done
    fi
}

populate_known_hosts() {
    # Grandfather in old GIT_HOST variable
    if [[ -z $SSH_KNOWN_HOSTS ]]; then
        SSH_KNOWN_HOSTS=$GIT_HOST
    fi

    # If we need to, automatically populate the known hosts file
    if [[ -n $SSH_KNOWN_HOSTS ]]; then
        msg "Populating known hosts file"
        safe mkdir -p /root/.ssh/
        safe chmod 700 /root/.ssh/
        safe touch /root/.ssh/known_hosts
        safe chmod 600 /root/.ssh/known_hosts
        for HOST in "$SSH_KNOWN_HOSTS"; do
            grep "$HOST" /root/.ssh/known_hosts > /dev/null ||
                safe ssh-keyscan -t rsa,dsa $HOST >> /root/.ssh/known_hosts
        done
    fi
}

make_git_wrapper() {
    # Make a git-ssh wrapper
    msg "Making temporary git ssh wrapper to use the chef key"
    # Git uses the GIT_SSH environment variable to decide what to do when sshing
    export GIT_SSH="$BOOTSTRAP_PATH/git-ssh-wrapper.sh"
    echo "ssh -i $CHEF_ROOT/$KEY \"\$@\"" > $GIT_SSH
    chmod +x $GIT_SSH
}

clone_repos() {
    pushd $CHEF_ROOT > /dev/null
    if [[ -n $SCRIPTS_REPO ]]; then
        msg "Cloning scripts repository"
        safe git clone $SCRIPTS_REPO scripts
    fi
    popd > /dev/null
}

additional_tasks() {
    # There are no additional tasks by default, but you can override this to
    # do anything you need to do before running chef for the first time.
    :
}

run_chef() {
    msg "Running chef for the first time"
    pushd $CHEF_ROOT/scripts > /dev/null
    safe ./run_chef.sh -ov
    popd > /dev/null
}

do_bootstrap() {
    # Runs all the other commands to do the bootstrap, should be run at the
    # end of a bootstrap script
    load_config
    install_packages
    make_chef_dir
    install_key
    schlep_files
    populate_known_hosts
    make_git_wrapper
    clone_repos
    additional_tasks
    run_chef
}
