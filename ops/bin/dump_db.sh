#!/usr/bin/env bash
#
# These scripts expect to be in `feeder.prx.org/ops/bin`
set -e
set -u

usage() {
  echo "Usage: dump_db.sh <prod|stag>"
  exit 1
}

# It takes a single argument
if [ $# -ne 1 ]
  then
  usage
fi

# It takes in an argument of 'prod' or 'stag' to determine which port to connect to
if [ "$1" == "prod" ]; then
  echo "Connecting to prod"
  DB_DUMP_PORT=5433
  DIST_ENV="prod"
elif [ "$1" == "stag" ]; then
  echo "Connecting to stag"
  DB_DUMP_PORT=5435
  DIST_ENV="stag"
else
  usage
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/_env.sh"

NAME="$DUMP_REMOTE_POSTGRES_DATABASE-$DIST_ENV-dump-$(date "+%m%d%H%M%Y%S").out"
OUTPUT_FILE="$TMP_FOLDER/$NAME"

echo ""
echo "********************************************************************************"
echo "Make sure you're running the 'awstunnel.sh' script connected to ${DIST_ENV}!"
echo "Make sure you've added your PRX INC developer ssh keys: 'ssh-add <path-to-key>' "
echo "********************************************************************************"
echo ""
echo "Dumping remote database $DUMP_REMOTE_POSTGRES_DATABASE with user $DUMP_REMOTE_POSTGRES_USER"

echo "Feeder remote"
time pg_dump --verbose -Fc -h 127.0.0.1 \
  -p "$DB_DUMP_PORT" \
  --exclude-table-data 'public.say_when_job_executions' \
  --exclude-table-data 'sessions' \
  --exclude-table-data 'tasks' \
  -W -d "${DUMP_REMOTE_POSTGRES_DATABASE}" -U "$DUMP_REMOTE_POSTGRES_USER" -f "$OUTPUT_FILE"
echo "Wrote: $OUTPUT_FILE"

rm "$LINK_FILE" || true
ln -s "$OUTPUT_FILE" "$LINK_FILE"
echo "Linked: $LINK_FILE"

echo ""
echo "DONE"
echo ""
echo "Now run 'setup_clone_db.sh' followed by 'load_db.sh'"
echo ""