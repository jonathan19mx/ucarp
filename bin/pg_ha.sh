#!/bin/sh 
# Define the remote node
REMOTE=servidor2
# Define the Data Directory
DATA_DIR=/data100 
# Define the Backup Directory 
BACKUP_DIR=/data200 
# Postgres user
PGUSER=pgsql 
# Contact 
CONTACT="Shanmu <mailme@abc.com>" 
# Date 
TIME=$(date +%Y-%m-%d_%H:%M) 
# Since this script may launches at boot, we need to set the proper path.
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin 
if [ "$1" == "" ];       
then                 
echo "Usage: pg_ha.sh status|master|slave|init-slave"         
fi 
case "$1" in 
        master)                 
	# This is the trigger for PostgreSQL to step up as master                
	sudo -u $PGUSER touch /tmp/pgsql.trigger                
	echo -e "$(hostname) was just promoted to master for PostgreSQL.\n\nMake sure to login and active the slave." | 
	mail -s "Warning! $(hostname) is now the PostgreSQL Master" $CONTACT        
	;; 
        slave)                
	echo "Taking backup of local files prior to overwriting data."                 
	sudo -u $PGUSER mkdir -p $BACKUP_DIR/ha_backups 
	sudo -u $PGUSER tar cfz $BACKUP_DIR/ha_backups/local_dump-$TIME.tar.gz --exclude="*~" $DATA_DIR 
                echo "Removing trigger file."                 
		sudo -u $PGUSER rm -f /tmp/pgsql.trigger 
                echo "Stopping PGSQL in stand-alone mode."                
		sudo -u $PGUSER pg_ctl stop -D $DATA_DIR -m fast 
                # Dumping and restoring the database from the remote server locally.                 
		# If the dump fails, (ie. not exit with error code 0), we abort.                
		echo "Removing $DATA_DIR directory Content..."                 
		sudo -u $PGUSER rm -R $DATA_DIR/*                 
		echo "Dumping database from $REMOTE ..."                 
		sudo -u $PGUSER pg_basebackup -h$REMOTE -D $DATA_DIR -U $PGUSER -v -P -x 
		if [ $? = 0 ]                         
		then                                 
		echo "Restoring database and recovering..."                                
		sudo -u $PGUSER cp -f /usr/local/pgsql/data-temp/recovery.bak  $DATA_DIR/recovery.conf 
         echo "Restarting PGSQL in slave-mode..."  
	 sudo -u $PGUSER pg_ctl start -D $DATA_DIR  
echo -e "$(hostname) is now an active slave for PostgreSQL.\nBackups are stored in '$BACKUP_DIR/ha_backups'." | mail -s "$(hostname) is now the PostgreSQL Slave" $CONTACT 
else                                
echo "Aborting. Recovery from master failed."                         
fi 
        ;; 
        status)                
	# Load variables from rc.conf                
	. /etc/rc.subr                 load_rc_config ucarp 
                UCARPIF=$(ifconfig | grep "$ucarp_addr " | grep -v grep) 
                echo "Checking UCARP Status..."                 
		if [ "$UCARPIF" != "" ];                
		then                         
		# Get xlog data from PostgreSQL                        
		LOCALMASTERSTAT=$(sudo -u $PGUSER psql postgres -c "SELECT pg_current_xlog_location()" $PGUSER | head 
		-n 3 | tail -n 1)                         
		REMOTESLAVESTAT=$(sudo -u $PGUSER psql -h$REMOTE postgres -c "SELECT pg_last_xlog_receive_location()" $PGUSER | head -n 3 | tail -n 1) 
                        echo -e "\tI'm the UCARP master!"                         
			echo "Checking for WAL Sender Process..." 
                        # Check for Wal sending process                         
			WALSEND=$(ps aux | grep "wal sender process" | grep -v grep)                        
			if [ "$WALSEND" != "" ];                         
			then                                 
			echo -e "\tWAL Sender Process found!" 
                                # Print Replication status                                 
				echo -e "Master xlog location (local):"                                 
				echo -e "\t$LOCALMASTERSTAT"                                
				echo -e "Slave xlog location (remote):"                                
				echo -e "\t$REMOTESLAVESTAT"                        
				else                                 
				echo -e "\tWarning! No WAL Sender Process found."                        
				fi                
				else                        
				# Get xlog data from PostgreSQL                        
				LOCALSLAVESTAT=$(sudo -u $PGUSER psql postgres -c "SELECT pg_last_xlog_receive_location()" $PGUSER | 
				head -n 3 | tail -n 1)                        
				REMOTEMASTERSTAT=$(sudo -u $PGUSER psql -h$REMOTE postgres -c "SELECT pg_current_xlog_location()" $PGUSER | 
				head -n 3 | tail -n 1) 
                        echo -e "\tI'm the UCARP slave!"                        
			echo "Checking for WAL Receiver Process..." 
                        # Check for Wal receiver process                        
			WALRECV=$(ps aux | grep "wal receiver process" | grep -v grep)                        
			if [ "$WALRECV" != "" ];                        
			then                                  
			echo -e "\tWAL Receiver Process found!" 
                                # Print Replication status                                 
				echo -e "Slave xlog location (local):"                                
				echo -e "\t$LOCALSLAVESTAT"                                
				echo -e "Master xlog location (remote):"                                
				echo -e "\t$REMOTEMASTERSTAT"                        
				else                                
				echo -e "\tWarning! No WAL Receiver Process found."                        
				fi                 
				fi         
				;; 
				esac 
