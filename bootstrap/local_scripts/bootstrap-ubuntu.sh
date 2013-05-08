#!/bin/bash
# Ubuntu bootstrap script
. $(dirname $0)/bootstrap-common.sh

. /etc/lsb-release

install_chef() {
    if [[ ! -f /usr/bin/chef-solo ]]; then
        msg "Installing chef"
        safe apt-get update
        safe apt-get install -y ruby1.9.3 build-essential
        if [[ -n $CHEF_VERSION ]]; then
            # Allow specifying the chef version
            safe gem install --version "$CHEF_VERSION" chef --no-rdoc --no-ri
        else
            safe gem install chef --no-rdoc --no-ri
        fi
    fi
}

install_git() {
    if [[ ! -f /usr/bin/git ]]; then
        msg "Installing git"
        safe apt-get install -y git-core
    fi
}

# Actually do the bootstrap
do_bootstrap
