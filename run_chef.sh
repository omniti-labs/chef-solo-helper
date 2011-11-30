#!/bin/bash
# Script to run chef-solo with the right options

# Hack for when running under rvm (for testing)
[[ -f .rvmrc ]] && . .rvmrc

MYDIR=$(dirname $BASH_SOURCE[0])
cd $MYDIR

[[ -f config.sh ]] && . config.sh

# Defaults
NO_GIT=
RUN_ONCE=
VERBOSE=

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

# If we're running multiple times, then have an initial random delay
if [[ -z $RUN_ONCE ]]; then
    DELAY=$((RANDOM % SPLAY))
    log "Sleeping for $DELAY seconds (inital stagger)..."
    sleep $DELAY
fi

while true; do
    # Update git
    if [[ -z $NO_GIT ]]; then
        if [[ -n $VERBOSE ]]; then
            git pull 2>&1 | tee -a $LOGFILE
        else
            git pull 2>&1 >> $LOGFILE
        fi
    fi
    # Run chef-solo
    chef-solo -c solo.rb \
        -j /var/chef-solo/config/nodes/$NODENAME.json \
        -N $NODENAME \
        -L $LOGFILE
    # Quit if we're only running once
    [[ -n $RUN_ONCE ]] && exit
    # Otherwise, wait and do it all over
    log "Sleeping for $INTERVAL seconds..."
    sleep $INTERVAL
done
