#!/usr/bin/env bash
#
# These scripts expect to be in `feeder.prx.org/ops/bin`
set -e
set -u

. ./_env.sh

echo ""
echo "********************************************************************************"
echo "Make sure you're running the 'awstunnel.sh' script connected to prod!"
echo "Make sure you've added your PRX INC developer ssh keys: 'ssh-add <path-to-key>' "
echo "********************************************************************************"
echo ""
echo "Dumping remote database $REMOTE_DATABASE with user $REMOTE_USER"

echo "Feeder remote"
time pg_dump --verbose -Fc -h 127.0.0.1 \
  -p 5433 \
  --exclude-table-data 'public.say_when_job_executions' \
  --exclude-table-data 'tasks' \
  -W -d $REMOTE_DATABASE -U $REMOTE_USER -f $OUTPUT_FILE 
echo "Wrote: $OUTPUT_FILE"

rm $LINK_FILE
ln -s $OUTPUT_FILE $LINK_FILE
echo "Linked: $LINK_FILE"

echo ""
echo "DONE"
echo ""
echo "Now run 'setup_clone_db.sh' followed by 'load_db.sh'"
echo ""
