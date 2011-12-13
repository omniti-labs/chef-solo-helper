#!/bin/bash
##############################################################################
# Copyright (c) 2011, OmniTI Computer Consulting, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name OmniTI Computer Consulting, Inc. nor the names
#       of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################
# Script to run chef-solo with the right options
##############################################################################

# Hack for when running under rvm (for testing)
[[ -f .rvmrc ]] && . .rvmrc

MYDIR=$(dirname $BASH_SOURCE[0])
cd $MYDIR

INTERVAL=1800
SPLAY=120 # Random interval to inititally sleep to stagger chef runs
LOGFILE=/var/log/chef/solo.log
NODENAME=$(hostname)

CHEF_ROOT="/var/chef-solo"
# Which repositories to update with git
REPOS="$CHEF_ROOT/scripts $CHEF_ROOT/config $CHEF_ROOT/common"
# Path to node configs
NODEPATH="$CHEF_ROOT/config/nodes"

# Use a custom wrapper for ssh with git
export GIT_SSH=$CHEF_ROOT/scripts/resources/git-ssh-wrapper.sh

# Config.sh isn't kept in version control and can be created to override any
# values set above as needed. This file may also be created by bootstrap
# scripts.
[[ -f config.sh ]] && . config.sh

# Defaults
NO_GIT=
RUN_ONCE=
VERBOSE=

rotate_logs() {
    # Keep enough logs for a little over a day
    for ((i=50; $i>0; i--)); do
        [[ -f $LOGFILE.$i ]] && mv $LOGFILE.$i $LOGFILE.$((i+1))
    done
    [[ -f $LOGFILE ]] && mv $LOGFILE $LOGFILE.1
}

log() {
    [[ -n $VERBOSE ]] && echo "$0: $@"
    echo "$0: $@" >> $LOGFILE
}

usage() {
    echo "Usage: $0 [options]"
    echo "Updates a chef repository from git, and runs chef-solo"
    echo
    echo "Options:"
    echo "    -h    -- help"
    echo "    -n    -- don't update using git before running chef-solo"
    echo "    -o    -- only run once"
    echo "    -i    -- override default interval ($INTERVAL)"
    echo "    -s    -- override default splay ($SPLAY)"
    echo "    -l    -- override the default logfile ($LOGFILE)"
    echo "    -v    -- verbose (print stuff to STDOUT as well as logs)"
    exit 1
}

while getopts ":hnoi:s:l:v" opt; do
    case $opt in
        h)  usage
            ;;
        n)  NO_GIT=1
            ;;
        o)  RUN_ONCE=1
            ;;
        i)  INTERVAL=$OPTARG
            ;;
        s)  SPLAY=$OPTARG
            ;;
        l)  LOGFILE=$OPTARG
            ;;
        v)  VERBOSE=1
            ;;
        *)  echo "Invalid option -- '$OPTARG'"
            usage
            ;;
    esac
done
shift $(($OPTIND-1))

# Make sure the log directory exists
LOGDIR=$(dirname $LOGFILE)
[[ -d $LOGDIR ]] || mkdir -p $LOGDIR

rotate_logs

# If we're running multiple times, then have an initial random delay
if [[ -z $RUN_ONCE ]]; then
    DELAY=$((RANDOM % SPLAY))
    log "Sleeping for $DELAY seconds (inital stagger)..."
    sleep $DELAY
fi

while true; do
    # Update git
    if [[ -z $NO_GIT ]]; then
        for r in $REPOS; do
            if [[ -d $r ]]; then
                log "Updating git repository $r"
                pushd $r > /dev/null
                if [[ -n $VERBOSE ]]; then
                    git pull 2>&1 | tee -a $LOGFILE
                else
                    git pull >> $LOGFILE 2>&1
                fi
                popd > /dev/null
            fi
        done
    fi
    log "Running chef-solo"
    # Run chef-solo
    chef-solo -c solo.rb \
        -j $NODEPATH/$NODENAME.json \
        -N $NODENAME \
        -L $LOGFILE
    # Quit if we're only running once
    [[ -n $RUN_ONCE ]] && exit
    # Otherwise, wait and do it all over
    log "Sleeping for $INTERVAL seconds..."
    sleep $INTERVAL
done
