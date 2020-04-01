#!/bin/sh -x

case "$1" in
    controller)
        runc-controller.sh
        ;;
    node)
        runc-node.sh
        ;;
    *)
        echo "Bad Argument"
        exit 1
esac 