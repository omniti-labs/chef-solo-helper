#!/bin/bash
##############################################################################
# Git ssh wrapper - manually specify the key to use
##############################################################################
# This requires that the key be present in the hosts file already. Use:
#       ssh-keyscan [hostname] >> /root/.ssh/known_hosts
##############################################################################
ssh -i /root/.ssh/id_rsa_chef "$@"
