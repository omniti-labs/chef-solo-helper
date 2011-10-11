#!/bin/bash
# Script to run chef-solo with the right options
NODENAME=$(hostname)
LOGFILE=/var/log/chef/solo.log
MYDIR=$PWD/`dirname $BASH_SOURCE[0]`
OPTIONS=
# Daemon options (30 minutes, 15 minute splay, log output to file)
#OPTIONS="-d -s 900 -i 1800 -L $LOGFILE"
chef-solo -c $MYDIR/solo.rb -j $MYDIR/nodes/$NODENAME.json \
    -N $NODENAME $OPTIONS
