#!/bin/bash

get_epoch_seconds() {
    date +%s
}

get_iso_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

get_readable_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}
