#!/usr/bin/env bash
set -e
set -u

# These scripts expect to be in `feeder.prx.org/ops/bin`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TMP_FOLDER="$DIR/../../tmp"
LINK_NAME="feeder-dump.out"
LINK_FILE="$TMP_FOLDER/$LINK_NAME"

CLONE_DB_NAME="feeder_clone"

DOTENV_PATH="$DIR/../../.env"
set -a
source $DOTENV_PATH
set +a

echo "Dropping clone database"
dropdb $CLONE_DB_NAME || true
echo "Creating clone database"
createdb $CLONE_DB_NAME

echo "Running pg_restore ..."
pg_restore --verbose -j 16 -d $CLONE_DB_NAME $LINK_FILE
echo ""
echo "DONE"
echo "Please ignore errors about missing roles."
echo ""
echo "You may now run 'load_db.sh'"