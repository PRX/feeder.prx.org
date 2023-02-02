export TMP_FOLDER="$DIR/../../tmp"
export LINK_NAME="feeder-dump.out"
export LINK_FILE="$TMP_FOLDER/$LINK_NAME"
export CLONE_DB_NAME="feeder_clone"
export DOTENV_PATH="$DIR/../../.env"

set -a
# shellcheck source=/dev/null
source "$DOTENV_PATH"
set +a

export PGPASSWORD=$POSTGRES_PASSWORD
export PGUSER=$POSTGRES_USER
export PGHOST=$POSTGRES_HOST
