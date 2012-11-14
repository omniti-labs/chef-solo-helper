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
# Strip off any domain name from incorrectly set hostnames
NODENAME=${NODENAME%%.*}

THINGS_TO_COMBINE="nodes roles data_bags handlers"

CHEF_ROOT="/var/chef-solo"

# Command to fetch checkout list
FETCH_CHECKOUT_LIST_COMMAND="cat /var/chef-solo/checkout-list"

# Use a custom wrapper for ssh with git
# Controlled by two more env vars, RELY_ON_SSH_AGENT and GIT_SSH_IDENTITY
export GIT_SSH=$CHEF_ROOT/scripts/resources/git-ssh-wrapper.sh

# Path to lockfile
LOCKFILE=/tmp/run_chef.lock

# Config.sh isn't kept in version control and can be created to override any
# values set above as needed. This file may also be created by bootstrap
# scripts.
[[ -f config.sh ]] && . config.sh

# Defaults
NO_GIT=
RUN_ONCE=
RUN_ONCE_SPLAY=
VERBOSE=
SVNUSER=
DEBUG=

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

error() {
    log "ERROR: $@"
    exit 1
}

usage() {
    echo "Usage: $0 [options]"
    echo "Updates a chef repository from git, and runs chef-solo"
    echo
    echo "Options:"
    echo "    -h         -- help"
    echo "    -d         -- Run chef with debug logging"
    echo "    -n         -- don't update using git before running chef-solo"
    echo "    -o         -- only run once"
    echo "    -j         -- Include random delay (splay) even when running once"
    echo "    -K         -- if a killswitch file exists, ignore it"
    echo "    -i         -- override default interval ($INTERVAL)"
    echo "    -s         -- override default splay ($SPLAY)"
    echo "    -l         -- override the default logfile ($LOGFILE)"
    echo "    -v         -- verbose (print stuff to STDOUT as well as logs)"
    echo "    -u         -- svn username"
    exit 1
}

lock() {
    if ( set -o noclobber; echo "$$" > $LOCKFILE ) 2>/dev/null; then
        trap "rm -f $LOCKFILE; exit $?" INT TERM EXIT
        [[ -n $VERBOSE ]] && echo "Aquired lock"
        return 0
    fi
    local PID=`cat $LOCKFILE`
    local RUNNING=""
    [[ -d /proc/$PID ]] && RUNNING=" (Running)"
    echo "Failed to acquire lock. Held by $PID$RUNNING"
    return 1
}

unlock() {
    [[ -n $VERBOSE ]] && echo "Releasing lock"
    rm -f $LOCKFILE
    trap - INT TERM EXIT
}


# Uses $FETCH_CHECKOUT_LIST_COMMAND (from config.sh) to read the checkout list into array $CHECKOUTS
read_checkout_list() {
    log "Reading checkout list via '$FETCH_CHECKOUT_LIST_COMMAND'"
    CHECKOUTS=(`$FETCH_CHECKOUT_LIST_COMMAND`)
    log "Found ${#CHECKOUTS[@]} checkouts to perform"
}

# Checks out or clones, etc
update_checkout() {
    split_checkout_line $1
    pushd $CHECKOUTS_DIR > /dev/null
    if [[ $CO_VCS = 'git' ]]; then
        if [[ -n $VERBOSE ]]; then
            update_git | tee -a $LOGFILE
        else
            update_git >> $LOGFILE
        fi
    fi
    if [[ $CO_VCS = 'svn' ]]; then
        update_svn
    fi

    echo $CO_COOKBOOK_DIR >> $CHEF_ROOT/.cookbook-order
    popd > /dev/null
}

update_git() {
    setup_git_creds

    if [[ -d $CHECKOUTS_DIR/$CO_DIR ]]; then
        # pull/update
        log "Pulling checkout $CO_DIR"
        pushd $CHECKOUTS_DIR/$CO_DIR > /dev/null
        git remote set-url origin $CO_REPO
        git fetch origin 2>&1 || error "Failed git fetch"
        local local_branch=$(git rev-parse --verify --symbolic-full-name $CO_BRANCH 2> /dev/null)
        # no branch or bad commit
        if [[ $PIPESTATUS -ne 0 ]]; then
            git rev-parse --verify -q --symbolic-full-name origin/$CO_BRANCH ||
                error "Unable to find branch or commit $CO_BRANCH"
            git checkout -b $CO_BRANCH origin/$CO_BRANCH || error "Failed to checkout $CO_BRANCH"
        # local branch already exists
        elif [[ -n $local_branch ]]; then
            git checkout $CO_BRANCH || error "Failed to checkout $CO_BRANCH"
            git merge origin/$CO_BRANCH || error "Failed to merge origin/$CO_BRANCH"
        else
            git checkout $CO_BRANCH || error "Failed to checkout $CO_BRANCH"
        fi

        popd > /dev/null
    else
        # Clone
        log "Pulling checkout $CO_DIR"
        # assume verbose mode here
        git clone --no-checkout $CO_REPO $CO_DIR 2>&1 | tee -a $LOGFILE
        [[ $PIPESTATUS -eq 0 ]] || error "Failed git clone"
        pushd $CHECKOUTS_DIR/$CO_DIR > /dev/null
        if git rev-parse --verify -q origin/$CO_BRANCH; then
            local current_branch=`git symbolic-ref --short HEAD 2> /dev/null`
            if [ $current_branch -ne $CO_BRANCH ]; then
                git branch -f $CO_BRANCH origin/$CO_BRANCH || error "Failed to create branch $CO_BRANCH"
            fi
        else
        git checkout $CO_BRANCH || error "Failed to checkout $CO_BRANCH"
        popd > /dev/null
    fi
}

update_svn() {

    if [[ -d $CHECKOUTS_DIR/$CO_DIR ]]; then
        log "SVN updating $CO_DIR"
        pushd $CHECKOUTS_DIR/$CO_DIR > /dev/null

        if [[ -n $VERBOSE ]]; then 
            # TODO svn switch for branch changes?
            svn update --username $SVNUSER 2>&1 | tee -a $LOGFILE
            [[ $PIPESTATUS -eq 0 ]] || error "Failed svn up"
        else
            # TODO svn switch for branch changes?
            svn update --username $SVNUSER >> $LOGFILE 2>&1 || error "Failed svn up"
        fi

        popd > /dev/null
    else
        # TODO
        error "No support for initial SVN checkout yet"
    fi
 
}


# Given a CSV line from $CHECKOUTS, split it into the fields, and store in global variables named CO_*
split_checkout_line() {
    local INFO=(`echo "$1" | sed -e 's/,/ /g'`)
    CO_VCS=${INFO[0]}
    CO_REPO=${INFO[1]}
    CO_DIR=${INFO[2]}
    CO_BRANCH=${INFO[3]}
    CO_CREDS=${INFO[4]}

    CO_COOKBOOK_DIR=`echo $CO_DIR | cut -d'/' -f1`
    CO_COOKBOOK_DIR="$CO_COOKBOOK_DIR/cookbooks"

}


# Examines CO_CREDS, and exports vars to control behavior of git-ssh-wrapper
setup_git_creds() {
    if [[ $CO_CREDS = 'AGENT' ]]; then
        export RELY_ON_SSH_AGENT="yes"
    else
        unset RELY_ON_SSH_AGENT
        if [[ $CO_CREDS = 'NONE' ]]; then
            unset GIT_SSH_IDENTITY
        else
            export GIT_SSH_IDENTITY=$CHEF_ROOT/$CO_CREDS
        fi
    fi
}

clear_combined_links() {
    for WHAT in $THINGS_TO_COMBINE; do
        rm $COMBINED_DIR/$WHAT/* 2> /dev/null
    done

    # Reset cookbook order
    echo -n > $CHEF_ROOT/.cookbook-order

}


update_combined_links() {
    split_checkout_line $1
    for WHAT in $THINGS_TO_COMBINE; do
        if [[ -e $CHECKOUTS_DIR/$CO_DIR/$WHAT ]]; then
            if [[ -n $VERBOSE ]]; then 
                log "Re-linking combined $WHAT from $CO_DIR"
            fi
            pushd $COMBINED_DIR/$WHAT > /dev/null            
            if [[ $WHAT == 'data_bags' ]]; then
                # Need a second layer of dirs for databags
                for DBAG in `ls $CHECKOUTS_DIR/$CO_DIR/$WHAT`; do 
                    if [[ -d $CHECKOUTS_DIR/$CO_DIR/$WHAT/$DBAG ]]; then
                        mkdir -p $DBAG
                        pushd $DBAG > /dev/null
                        ls $CHECKOUTS_DIR/$CO_DIR/$WHAT/$DBAG/*.{rb,json} 2> /dev/null | xargs -n 1 -I {} ln -sf {} . # Use -f so last one wins
                        popd
                    fi
                done
            else
                ls $CHECKOUTS_DIR/$CO_DIR/$WHAT/*.{rb,json} 2> /dev/null | xargs -n 1 -I {} ln -sf {} . # Use -f so last one wins
            fi
            popd > /dev/null
        fi
    done
}


while getopts ":hdjKnoiu:s:l:v" opt; do
    case $opt in
        h)  usage
            ;;
        d)  DEBUG=1
            ;;
        j)  RUN_ONCE_SPLAY=1
            ;;
        K)  IGNORE_KILLSWITCH=1
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
        u)  SVNUSER=$OPTARG
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

# Make sure the combined directories exist
COMBINED_DIR=$CHEF_ROOT/combined
mkdir -p $COMBINED_DIR
for WHAT in $THINGS_TO_COMBINE; do 
    mkdir -p $COMBINED_DIR/$WHAT
done

if [[ -z $NODEPATH ]]; then
    NODEPATH=$COMBINED_DIR/nodes
fi

# Make sure the checkouts dir exist
CHECKOUTS_DIR=$CHEF_ROOT/checkouts
mkdir -p $CHECKOUTS_DIR

# Check for killswitch and exit
if [[ -z $IGNORE_KILLSWITCH ]]; then
    if [[ -e $CHEF_ROOT/killswitch ]]; then
        log "Killswitch file $CHEF_ROOT/killswitch exists - exiting immediately"
        exit
    fi
fi

# If we're running multiple times, then have an initial random delay
if [[ -z $RUN_ONCE || -n $RUN_ONCE_SPLAY ]]; then
    DELAY=$((RANDOM % SPLAY))
    log "Sleeping for $DELAY seconds (inital stagger)..."
    sleep $DELAY
fi

while true; do
    if lock; then
        # Update repos
        if [[ -z $NO_GIT ]]; then
            clear_combined_links
            read_checkout_list
            for CHECKOUT in ${CHECKOUTS[@]}; do
                update_checkout $CHECKOUT
                update_combined_links $CHECKOUT
            done
        fi
        
        DEBUGLOG=
         [[ -n $DEBUG ]] && DEBUGLOG="-l debug"
        CMD="chef-solo -c solo.rb -j $NODEPATH/$NODENAME.json -N $NODENAME -L $LOGFILE $DEBUGLOG"
        log "Running chef-solo as $CMD"
        $CMD
        unlock
    fi
    # Quit if we're only running once
    [[ -n $RUN_ONCE ]] && exit
    # Otherwise, wait and do it all over
    log "Sleeping for $INTERVAL seconds..."
    sleep $INTERVAL
done
