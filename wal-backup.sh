#!/bin/bash
# This command is called like this:
# /var/lib/postgresql/wal-backup.sh pg_xlog/000000010000000000000001 000000010000000000000001
# And it's useful to have a WAL backup to be able to do point-in-time recovery
FULL_NAME=$PG_DATADIR/$1
BASE_NAME=$2
ARCHIVE_COMMAND="bzip2 -9 -c"
ARCHIVE_EXT="bz2"
BACKUP_PATH=$(dirname $0)
ARCHIVE_NAME=$BACKUP_PATH/wal-backup/${BASE_NAME}.${ARCHIVE_EXT}
if hash xz 2>/dev/null; then
	ARCHIVE_COMMAND="xz"
	ARCHIVE_EXT="xz"
fi

# Change into the folder
cd $BACKUP_PATH
# Try creating a backup folder, if it doesn't exist
if [ ! -d $BACKUP_PATH/wal-backup ]; then
	mkdir $BACKUP_PATH/wal-backup || exit 1
fi

if [ ! -f ${FULL_NAME} ]; then
	(>&2 echo "Could not find ${FULL_NAME}!")
	exit 2
fi

if [ -f ${ARCHIVE_NAME} ]; then
	echo "File ${ARCHIVE_NAME} already exists."
	exit 0
fi

echo "Executing ${ARCHIVE_COMMAND} ${FULL_NAME} > ${ARCHIVE_NAME}..."
${ARCHIVE_COMMAND} ${FULL_NAME} > ${ARCHIVE_NAME} || exit 1
