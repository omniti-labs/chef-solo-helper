#!/bin/bash

# This script will check to see if a killswitch is in place
# and email the given email address if so.

EMAIL=$1
HOST=`hostname`
KSFILE="/var/chef-solo/killswitch"
if [ -f $KSFILE ]; then
    KSINFO=`ls -l /var/chef-solo/killswitch`
    TMPFILE=`mktemp /tmp/ksXXXX`
    KSTEXT=`cat /var/chef-solo/killswitch`

cat > $TMPFILE <<EOF
Subject: Chef disabled

This is an alert that someone has created a killswitch and chef will be disabled until it is manually removed.

Host: $HOST
$KSINFO

$KSTEXT
EOF

    if [ -x /usr/lib/sendmail ]; then
        /usr/lib/sendmail -oi $EMAIL < $TMPFILE
    elif [ -x /usr/sbin/sendmail ]; then
        /usr/sbin/sendmail -oi $EMAIL < $TMPFILE
    fi

    rm $TMPFILE
fi
