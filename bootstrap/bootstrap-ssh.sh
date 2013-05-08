#!/bin/bash
# Bootstrap a system remotely via ssh
usage() {
    echo "Usage: $0 [OPTIONS] HOSTNAME [NODENAME]"
    echo
    echo "Options:"
    echo "  -c configfile -- alternate bootstrap config file (default: config.sh)"
    echo "  -p ssh_port   -- alternate ssh port to connect to (default: 22)"
    echo "  -o ssh_opts   -- additional options to pass to ssh/scp commands"
    echo "  -u username   -- override the ssh username"
}

MYDIR=$(dirname $0) # Directory where the script is
CONFIG_FILE=$MYDIR/config.sh
SSH_PORT=22
SSH_OPTS=
SSH_USER_OPT=
while getopts ":c:p:o:u:" opt; do
    case $opt in
        c)
            CONFIG_FILE=$OPTARG
            ;;
        p)
            SSH_PORT=$OPTARG
            ;;
        o)
            SSH_OPTS=$OPTARG
            ;;
        u)
            SSH_USER_OPT=$OPTARG
            ;;
        *)
            echo "Invalid option -- '$OPTARG'"
            usage
            exit 1
            ;;
    esac
done
shift $(($OPTIND-1))

if [[ -z $1 ]]; then
    usage
    exit 1
fi

. $CONFIG_FILE

# Override username if provided on the command line
if [[ -n $SSH_USER_OPT ]]; then
    USERNAME=$SSH_USER_OPT
fi

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

[[ -n $SSH_KEY ]] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

SCP_OPTS=$SSH_OPTS
if [[ $SSH_PORT != 22 ]]; then
    SCP_OPTS="$SCP_OPTS -P $SSH_PORT"
    SSH_OPTS="$SSH_OPTS -p $SSH_PORT"
fi

msg "Making bootstrap dir on the server"
safe ssh $SSH_OPTS $USERNAME@$HOST mkdir -p $BOOTSTRAP_PATH

msg "Copying key"
safe scp $SCP_OPTS $CONFIG_FILE_DIR/$KEY $USERNAME@$HOST:$BOOTSTRAP_PATH

msg "Copying bootstrap script"
safe scp $SCP_OPTS $MYDIR/local_scripts/bootstrap-common.sh \
    $USERNAME@$HOST:$BOOTSTRAP_PATH
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
