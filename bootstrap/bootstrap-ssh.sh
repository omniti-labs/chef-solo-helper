#!/bin/bash
# Bootstrap a system remotely via ssh
MYDIR=$(dirname $0) # Directory where the script is
CONFIG_FILE=$MYDIR/config.sh
SSH_PORT=22
while getopts ":c:p:" opt; do
    case $opt in
        c)
            CONFIG_FILE=$OPTARG
            ;;
        p)
            SSH_PORT=$OPTARG
            ;;
        *)
            echo "Invalid option -- '$OPTARG'"
            exit 1
            ;;
    esac
done
shift $(($OPTIND-1))

. $CONFIG_FILE

CONFIG_FILE_DIR=$(dirname $CONFIG_FILE)

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

SCP_OPTS="$SSH_OPTS -P $SSH_PORT"
SSH_OPTS="$SSH_OPTS -p $SSH_PORT"

msg "Making bootstrap dir on the server"
safe ssh $SSH_OPTS $USERNAME@$HOST mkdir -p $BOOTSTRAP_PATH

msg "Copying key"
safe scp $SCP_OPTS $CONFIG_FILE_DIR/$KEY $USERNAME@$HOST:$BOOTSTRAP_PATH

msg "Copying bootstrap script"
safe scp $SCP_OPTS $MYDIR/local_scripts/$BOOTSTRAP_SCRIPT \
    $USERNAME@$HOST:$BOOTSTRAP_PATH

msg "Copying configuration (renaming as config.sh)"
safe scp $SCP_OPTS $CONFIG_FILE $USERNAME@$HOST:$BOOTSTRAP_PATH/config.sh

if [[ -n $NODENAME ]]; then
    msg "Setting hostname on the server"
    safe ssh $SSH_OPTS -t $USERNAME@$HOST sudo hostname $NODENAME
fi

if [[ -n $SCHLEP_FILES ]]; then
    for FILE in "$SCHLEP_FILES"; do 
        msg "Uploading schlep file $FILE"
        safe scp $SCP_OPTS $CONFIG_FILE_DIR/$FILE \
            $USERNAME@$HOST:$BOOTSTRAP_PATH
    done
fi

msg "Running bootstrap script on $HOST as root"
safe ssh $SSH_OPTS -t $USERNAME@$HOST sudo $BOOTSTRAP_PATH/$BOOTSTRAP_SCRIPT
