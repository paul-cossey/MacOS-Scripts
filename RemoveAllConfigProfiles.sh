#!/bin/bash
#Removes All Profile Manager Config Profiles from a client computer that are secured with a removal password
/usr/bin/profiles -D -f -z 'YourProfileRemovalPassword'
/usr/bin/profiles -d -f -z 'YourProfileRemovalPassword'
Exit 0
