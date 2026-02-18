#!/usr/bin/env sh

load_configurations() {
    while ! swanctl --load-all &>/dev/null; do
        echo "Waiting for service to start...";
        sleep 1;
    done
    echo "Configurations loaded successfully!"
}

load_configurations &

exec /usr/sbin/ipsec $@
