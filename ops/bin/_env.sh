DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TMP_FOLDER="$DIR/../../tmp"
LINK_NAME="feeder-dump.out"
LINK_FILE="$TMP_FOLDER/$LINK_NAME"

CLONE_DB_NAME="feeder_clone"

DOTENV_PATH="$DIR/../../.env"
set -a
source $DOTENV_PATH
set +a

NAME="$REMOTE_DATABASE-dump-`date "+%m%d%H%M%Y%S"`.out"
OUTPUT_FILE="$TMP_FOLDER/$NAME"


