#!/usr/bin/env bash
# These scripts expect to be in `feeder.prx.org/ops/bin`
set -e
set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/_env.sh

echo "Dropping clone database"
dropdb $CLONE_DB_NAME || true
echo "Creating clone database"
createdb $CLONE_DB_NAME

echo "Running pg_restore ..."
pg_restore --verbose -j 16 -d $CLONE_DB_NAME $LINK_FILE || true
echo ""
echo "DONE"
echo ""
echo "You may now run 'load_db.sh'"