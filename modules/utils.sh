#!/bin/bash

generate_password() {
    openssl rand -hex 8
}

get_system_specs() {
    CORES=$(nproc)
    RAM=$(free -m | awk '/^Mem:/{print $2}')
    echo "Detected $CORES cores and $RAM MB RAM" >> /etc/bakavps/logs/bakavps.log
}