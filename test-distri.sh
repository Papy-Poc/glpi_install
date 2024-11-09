#!/bin/bash

if [ -f /etc/debian_version ]; then
    echo "Système Debian"
elif [ -f /etc/redhat-release ]; then
    echo "Système Red Hat"
else
    echo "Système inconnu"
fi
