#!/bin/bash
# Ubuntu bootstrap script
. $(dirname $0)/bootstrap-common.sh

. /etc/lsb-release

install_chef() {
    if [[ ! -f /usr/bin/chef-solo ]]; then
        msg "Installing chef"
        safe apt-get update
        if [[ $DISTRIB_RELEASE == "12.04" ]]; then
            safe apt-get install -y ruby ruby1.8-dev build-essential wget
        else
            safe apt-get install -y ruby ruby1.8-dev build-essential wget \
                libruby-extras libruby1.8-extras
        fi
        safe wget http://production.cf.rubygems.org/rubygems/rubygems-1.6.2.tgz
        safe tar zxf rubygems-1.6.2.tgz
        pushd rubygems-1.6.2 > /dev/null
        safe ruby setup.rb --no-format-executable
        popd > /dev/null

        safe gem update --no-rdoc --no-ri
        safe gem install ohai --no-rdoc --no-ri
        safe gem install chef --no-rdoc --no-ri
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
