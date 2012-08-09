#!/bin/bash
##############################################################################
# Git ssh wrapper - manually specify the key to use
##############################################################################
# This requires that the key be present in the hosts file already. Use:
#       ssh-keyscan -t rsa,dsa [hostname] >> /root/.ssh/known_hosts
##############################################################################

if [[ -z $RELY_ON_SSH_AGENT ]]; then

    unset SSH_AUTH_SOCK
 
    if [[ -z $GIT_SSH_IDENTITY ]]; then
        GIT_SSH_IDENTITY=/var/chef-solo/chef.key
    fi
    SSH_OPTS="$SSH_OPTS -i $GIT_SSH_IDENTITY"

fi

ssh $SSH_OPTS "$@"
