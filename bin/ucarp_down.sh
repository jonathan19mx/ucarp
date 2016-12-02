#!/bin/sh 
# Load variables from rc.conf 
./etc/rc.subr load_rc_config ucarp 
echo "Refusing to do go back online to avoid a split-brain situation." 
echo ""
echo "Manually run 'pg_ha.sh slave' after ensuring the master got the latest data." 

