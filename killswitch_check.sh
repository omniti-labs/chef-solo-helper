#!/bin/bash

# This script will check to see if a killswitch is in place
# and email the given email address if so.

SUBJECT="Chef disabled"
EMAIL=$1
MESSAGE="This is an alert that someone has created a killswitch and chef will be disabled until it is manually removed."

if [ -f /var/chef-solo/scripts/killswitch]; then
    /bin/mail -s "$SUBJECT" "$EMAIL" < $MESSAGE
fi
