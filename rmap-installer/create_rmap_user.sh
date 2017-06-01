#!/bin/bash

USER=rmap

echo "Creating a sudo account for user '"$USER"'..."

# Create the user, set their password, add them to the sudo list.
useradd $USER
passwd $USER
echo $USER "ALL=(ALL) ALL" >> /etc/sudoers
