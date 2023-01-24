#!/usr/bin/bash

echo ""
echo " -> Building Ubuntu 'kinetic' sandbox for package builds..."
pbuilder create --distribution kinetic --debootstrap /wkdev-sdk/container_files/wkdev-debootstrap --debootstrapopts --variant=buildd    
