#!/bin/bash
set -e

DATA_DIR=/data
SERVER_DIR=$DATA_DIR/server

# If the container is started as root, change the ownership of the data directory to the user that owns it and re-exec the script as that user
if [ "$(id -u)" = "0" ]; then
    uid=$(stat -c %u "$DATA_DIR"); gid=$(stat -c %g "$DATA_DIR")
    [ "$uid" = "0" ] && uid=1000 && gid=1000
    mkdir -p "$SERVER_DIR" "$DATA_DIR/home"
    chown -R "$uid:$gid" "$DATA_DIR"
    exec setpriv --reuid "$uid" --regid "$gid" --clear-groups "$0" "$@"
fi

export HOME=$DATA_DIR/home
export WINEPREFIX=$DATA_DIR/wineprefix

if [ ! -f "$SERVER_DIR/enshrouded_server.exe" ] || [ "${UPDATE_ON_START:-true}" = "true" ]; then
    /opt/depotdownloader/DepotDownloader -app 2278520 -os windows -dir "$SERVER_DIR" \
        || [ -f "$SERVER_DIR/enshrouded_server.exe" ]
fi

cd "$SERVER_DIR"
exec wine ./enshrouded_server.exe
