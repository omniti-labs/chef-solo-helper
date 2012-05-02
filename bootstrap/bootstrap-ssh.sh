#!/bin/bash
# Bootstrap an ec2 system remotely via ssh

CONFIG_FILE=$(dirname $0)/config.sh
while getopts ":c:" opt; do
    case $opt in
        c)
            CONFIG_FILE=$OPTARG
            ;;
        *)
            echo "Invalid option -- '$OPTARG'"
            exit 1
            ;;
    esac
done
shift $(($OPTIND-1))

. $CONFIG_FILE

HOST=$1
# Allow specifying the hostname on the command line - this is used to
# temporarily set the hostname on the system so that chef knows what node name
# to use
NODENAME=$2

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

SSH_OPTS=
[[ -n $SSH_KEY ]] && SSH_OPTS="-i $SSH_KEY"

msg "Making bootstrap dir on the server"
safe ssh $SSH_OPTS $USERNAME@$HOST mkdir -p $BOOTSTRAP_PATH

msg "Copying key"
safe scp $SSH_OPTS $KEY $USERNAME@$HOST:$BOOTSTRAP_PATH

msg "Copying bootstrap script"
safe scp $SSH_OPTS $BOOTSTRAP_SCRIPT $USERNAME@$HOST:$BOOTSTRAP_PATH

msg "Copying configuration"
safe scp $SSH_OPTS config.sh $USERNAME@$HOST:$BOOTSTRAP_PATH

if [[ -n $NODENAME ]]; then
    msg "Setting hostname on the server"
    safe ssh $SSH_OPTS $USERNAME@$HOST sudo hostname $NODENAME
fi

msg "Running bootstrap script on $HOST as root"
safe ssh $SSH_OPTS $USERNAME@$HOST sudo $BOOTSTRAP_PATH/$BOOTSTRAP_SCRIPT
