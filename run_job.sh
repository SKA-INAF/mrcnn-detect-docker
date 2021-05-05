#!/bin/bash

##########################
##    PARSE ARGS
##########################
RUNUSER="caesar"

# - CAESAR OPTIONS
JOB_OUTDIR=""
JOB_ARGS=""

# - RCLONE OPTIONS
MOUNT_RCLONE_VOLUME=0
MOUNT_VOLUME_PATH="/mnt/storage"
RCLONE_REMOTE_STORAGE="neanias-nextcloud"
RCLONE_REMOTE_STORAGE_PATH="."
RCLONE_MOUNT_WAIT_TIME=10

echo "ARGS: $@"

for item in "$@"
do
	case $item in
		--user=*)
    	RUNUSER=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--joboutdir=*)
    	JOB_OUTDIR=`echo "$item" | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--jobargs=*)
    	JOB_ARGS=`echo "$item" | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-rclone-volume=*)
    	MOUNT_RCLONE_VOLUME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mount-volume-path=*)
    	MOUNT_VOLUME_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage=*)
    	RCLONE_REMOTE_STORAGE=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-remote-storage-path=*)
    	RCLONE_REMOTE_STORAGE_PATH=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--rclone-mount-wait=*)
    	RCLONE_MOUNT_WAIT_TIME=`echo $item | /bin/sed 's/[-a-zA-Z0-9]*=//'`
    ;;

	*)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done


# - Check job args
#if [ "$JOB_ARGS" = "" ]; then
#	echo "ERROR: Empty JOB_ARGS argument (hint: you must specify image at least)!"
#	exit 1
#fi


###############################
##    MOUNT VOLUMES
###############################
if [ "$MOUNT_RCLONE_VOLUME" = "1" ] ; then

	# - Create mount directory if not existing
	echo "INFO: Creating mount directory $MOUNT_VOLUME_PATH ..."
	mkdir -p $MOUNT_VOLUME_PATH	

	# - Get device ID of standard dir, for example $HOME
	#   To be compared with mount point to check if mount is ready
	DEVICE_ID=`stat "$HOME" -c %d`
	echo "INFO: Standard device id @ $HOME: $DEVICE_ID"

	# - Mount rclone volume in background
	uid=`id -u $RUNUSER`

	echo "INFO: Mounting rclone volume at path $MOUNT_VOLUME_PATH for uid/gid=$uid ..."
	MOUNT_CMD="/usr/bin/rclone mount --daemon --uid=$uid --gid=$uid --umask 000 --allow-other --file-perms 0777 --dir-cache-time 0m5s --vfs-cache-mode full $RCLONE_REMOTE_STORAGE:$RCLONE_REMOTE_STORAGE_PATH $MOUNT_VOLUME_PATH -vvv"
	eval $MOUNT_CMD

	# - Wait until filesystem is ready
	echo "INFO: Sleeping $RCLONE_MOUNT_WAIT_TIME seconds and then check if mount is ready..."
	sleep $RCLONE_MOUNT_WAIT_TIME

	# - Get device ID of mount point
	MOUNT_DEVICE_ID=`stat "$MOUNT_VOLUME_PATH" -c %d`
	echo "INFO: MOUNT_DEVICE_ID=$MOUNT_DEVICE_ID"
	if [ "$MOUNT_DEVICE_ID" = "$DEVICE_ID" ] ; then
 		echo "ERROR: Failed to mount rclone storage at $MOUNT_VOLUME_PATH within $RCLONE_MOUNT_WAIT_TIME seconds, exit!"
		exit 1
	fi

	# - Print mount dir content
	echo "INFO: Mounted rclone storage at $MOUNT_VOLUME_PATH with success (MOUNT_DEVICE_ID: $MOUNT_DEVICE_ID)..."
	ls -ltr $MOUNT_VOLUME_PATH

	# - Create job & data directories
	echo "INFO: Creating job & data directories ..."
	mkdir -p $MOUNT_VOLUME_PATH/jobs
	mkdir -p $MOUNT_VOLUME_PATH/data

	# - Create job output directory
	#echo "INFO: Creating job output directory $JOB_OUTDIR ..."
	#mkdir -p $JOB_OUTDIR

fi


###############################
##    SET OPTIONS
###############################
#RUN_OPTIONS="--runmode=detect --jobdir=/home/$RUNUSER/mrcnn-job --weights=/opt/Software/MaskR-CNN/install/share/mrcnn_weights.h5 "
RUN_OPTIONS="--runmode=detect --jobdir=/home/$RUNUSER/mrcnn-job "
if [ "$JOB_OUTDIR" != "" ]; then
	RUN_OPTIONS="$RUN_OPTIONS --outdir=$JOB_OUTDIR "
	if [ "$MOUNT_RCLONE_VOLUME" = "1" ] ; then
		RUN_OPTIONS="$RUN_OPTIONS --waitcopy --copywaittime=$RCLONE_MOUNT_WAIT_TIME "
	fi	
fi

JOB_OPTIONS="$RUN_OPTIONS $JOB_ARGS " 


###############################
##    RUN Mask-RCNN JOB
###############################
# - Define run command & args
EXE="/opt/Software/MaskR-CNN/install/bin/run_mrcnn.sh"
CMD="runuser -l $RUNUSER -g $RUNUSER -c '""export MASKRCNN_DIR=$MASKRCNN_DIR; export PATH=$PATH:$MASKRCNN_DIR/bin; export PYTHONPATH=$MASKRCNN_DIR/lib/python3.6/site-packages/mrcnn-1.0.0-py3.6.egg:$MASKRCNN_DIR/lib/python3.6/site-packages; alias python3=python3.6; echo PYTHONPATH=$PYTHONPATH; which python3; $EXE $JOB_OPTIONS""'"

# - Run job
echo "INFO: Running job command: $CMD ..."
eval "$CMD"

