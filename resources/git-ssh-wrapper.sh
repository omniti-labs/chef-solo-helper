#!/bin/bash
# Git ssh wrapper - manually specify the key to use
ssh -i /root/.ssh/id_rsa_chef -o "StrictHostKeyChecking no" "$@"
