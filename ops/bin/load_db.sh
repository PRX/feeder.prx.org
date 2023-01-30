#!/usr/bin/env bash
# These scripts expect to be in `feeder.prx.org/ops/bin`
set -u
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/_env.sh

load_db () {
  # drop all the open connections
  echo "REVOKE CONNECT ON DATABASE $POSTGRES_DATABASE FROM public;" | psql
  echo "SELECT pid, pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DATABASE' AND pid <> pg_backend_pid();" | psql

  dropdb $POSTGRES_DATABASE || true

  echo "CREATE DATABASE $POSTGRES_DATABASE WITH TEMPLATE $CLONE_DB_NAME OWNER $POSTGRES_USER;" | time psql
}

set -x

load_db
