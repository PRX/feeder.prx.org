#!/usr/bin/env bash
set -e

. ./_env.sh

export PGPASSWORD=$POSTGRES_PASSWORD
export PGUSER=$POSTGRES_USER
export PGHOST=$POSTGRES_HOST

psql
