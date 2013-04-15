#!/bin/bash
# Bootstrap script for OmniOS
. $(dirname $0)/bootstrap-common.sh

install_packages() {
    msg "Ensuring required packages are installed"
    pkg publisher ms.omniti.com || \
        pkg set-publisher -g http://pkg-internal.omniti.com/omniti-ms \
        ms.omniti.com
    pkg install git chef
}

additional_tasks() {
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
}

# Actually do the bootstrap
do_bootstrap
