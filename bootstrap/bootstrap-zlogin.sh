#!/bin/bash
# Bootstrap a non-global zone from the global zone
MYDIR=$(dirname $0)
CONFIG_FILE=$MYDIR/config.sh

while getopts ":c:p:" opt; do
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

CONFIG_FILE_DIR=$(dirname $CONFIG_FILE)

ZONE=$1
# Allow specifying the hostname on the command line - this is used to
# temporarily set the hostname on the system so that chef knows what node name
# to use
NODENAME=$2

# Path to the zone's root filesystem from the global zone
ZONEROOT="/zones/$ZONE/root"

# Utility functions
msg() { echo " * $@"; }
err() { msg $@; exit 100; }
safe() { "$@" || err "cannot $@"; }

msg "Making bootstrap dir on the zone"
safe mkdir -p $ZONEROOT/$BOOTSTRAP_PATH

msg "Copying key"
safe cp $CONFIG_FILE_DIR/$KEY $ZONEROOT/$BOOTSTRAP_PATH

msg "Copying bootstrap script(s)"
safe cp $MYDIR/local_scripts/bootstrap_common.sh $ZONEROOT/$BOOTSTRAP_PATH
safe cp $MYDIR/local_scripts/$BOOTSTRAP_SCRIPT $ZONEROOT/$BOOTSTRAP_PATH

msg "Copying configuration (renaming as config.sh)"
safe cp $CONFIG_FILE $ZONEROOT/$BOOTSTRAP_PATH/config.sh

if [[ -n $NODENAME ]]; then
    msg "Setting hostname on the zone"
    safe zlogin $ZONE hostname $NODENAME
fi

if [[ -n $SCHLEP_FILES ]]; then
    for FILE in "$SCHLEP_FILES"; do 
        msg "Uploading schlep file $FILE"
        cp $CONFIG_FILE_DIR/$FILE $ZONEROOT/$BOOTSTRAP_PATH
    done
fi

msg "Running bootstrap script on $ZONE"
safe zlogin $ZONE $BOOTSTRAP_PATH/$BOOTSTRAP_SCRIPT
