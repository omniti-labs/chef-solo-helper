#!/bin/bash
# Bootstrap script for centos
. $(dirname $0)/bootstrap-common.sh

install_chef() {
    if [[ ! -f /usr/bin/chef-solo ]]; then
        msg "Installing chef"

        if [ $(rpm -qa | grep -c rbel6-release) -eq 0 ]; then
            safe rpm -Uvh http://rbel.co/rbel6
        fi

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
}

install_git() {
    if [[ ! -f /usr/bin/git ]]; then
        msg "Installing git"
        safe yum install git
    fi
}

do_bootstrap
