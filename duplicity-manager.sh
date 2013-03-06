#!/usr/bin/env bash

# duplicity-manager.sh
# Wrapper script for Duplicity to assist in making backup management
# with Duplicity a bit more user friendly.
#
# Copyright (c) 2013, Stephen Lang
# All rights reserved.
#
# Git repository available at:
# https://github.com/stephenlang/duplicity-manager
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


##########################################
# Rackspace CloudFiles Specific Settings #
##########################################

# Requires the following to be installed:
# - Duplicity (http://duplicity.nongnu.org)
# - pip install python-cloudfiles

# Important:  If your server resides on Rackspace's network, and has access
# to servicenet, then set RACKSPACE_SERVICENET=true to utilize the internal
# network.  Otherwise, set to false.

# Rackspace Cloudfiles API Credentials
export CLOUDFILES_USERNAME=YOUR_USERNAME
export CLOUDFILES_APIKEY=YOUR_API_KEY
export RACKSPACE_SERVICENET=True

# Rackspace container to store server backups
backupdestination=cf+http://YOUR_CONTAINER


##########################################
# Amazon S3 Specific Settings            #
##########################################

# Requires the following to be installed:
# - Duplicity (http://duplicity.nongnu.org)
# - pip install python-boto

# Amazon S3 API Credentials
# export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
# export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY

# Amazon S3 Bucket to store server backups
# backupdestination=s3+http://YOUR_CONTAINER


##########################################
# Server Configuration Options           #
##########################################

# List of directories to backup
INCLUDE_LIST=( /etc /var/www /var/lib/mysqlbackup )

# GPG Passphrase for encrypting data at rest
# You can use the following to generate a decent GPG passphrase, just be sure
# to store it someone secure off this server.
# < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c64
export PASSPHRASE=YOUR_PASSPHRASE

# Backup Retention 
retention_type=remove-older-than
retention_max=14D
 
# Number of full backups to keep (alternative to above)
# retention_type=remove-all-but-n-full
# retention_max=3

# Force Full Backup Every XX Days
full_backup_days=7D

# Restore Directory
restore=/tmp


##########################################
# End User Configuration Settings        #
##########################################


# Environment specific variables
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
lockdir=/tmp/backup-manager.lock
date=`date +%Y%m%d%H%M%S`
args=("$@")


# Sanity Checks
if [ ! `whoami` = root ]; then
	echo "This script must be ran by the user: root"
	exit 1
fi

if [ -d $lockdir ]; then
	echo "Lock file exists. Please confirm that backup-manager"
	echo "is not still running. If all is well, manually"
	echo "remove lock by running: rm -rf $lockdir"
	exit 1
fi


# Format directories to be backed up for Duplicity

for include in ${INCLUDE_LIST[@]}; do
	INCLUDE="$INCLUDE --include=$include"
done


# Functions

function help {

echo "
Options:

--backup:                      runs a normal backup based off retention settings
--backup-force-full:           forces a full backup
--list-files [age]:            lists the files currently stored in backups
--restore-all [age]:           restores everything to restore directory
--restore-single [age] [path]: restores a specific file/dir to restore directory
--show-backups:                lists full and incremental backups in the archive
--menu:                        user friendly menu driven interface


Examples:

duplicity-manager.sh --list-files 0D              Lists the most recent files in archive
duplicity-manager.sh --restore-all 2D             Restores everything from 2 days ago
duplicity-manager.sh --restore-single 0D var/www/ Restores /var/www from latest backup
"

}


function perform_backup {

duplicity cleanup --force $backupdestination
duplicity $retention_type $retention_max --force $backupdestination
duplicity --full-if-older-than $full_backup_days $INCLUDE --exclude '**' / $backupdestination

} 


function show_collection_status {

duplicity collection-status $backupdestination 

}


function list_current_files {

age=0D
if [ ! ${args[1]} = 0 ]; then
	age=${args[1]}
fi

duplicity -t $age list-current-files $backupdestination

}


function force_full_backup {

duplicity full $INCLUDE --exclude '**' / $backupdestination

}


function restore_all {

age=0D

if [ ! ${args[1]} = 0 ]; then
        age=${args[1]}
fi

mkdir $restore/restore_$date
duplicity -t $age $backupdestination $restore/restore_$date
echo "Your backup has been restored to $restore/restore_$date."

}


function restore_single {

age=0D

if [ ! ${args[1]} = 0 ]; then
        age=${args[1]}
fi

mkdir $restore/restore_$date
duplicity -t $age --file-to-restore ${args[2]} $backupdestination $restore/restore_$date 
echo "Your backup has been restored to $restore/restore_$date."

}


function menu {

bold=`tput smso`
offbold=`tput rmso`
clear

cat << EOF

${bold}\
  Duplicity Management Console  \
${offbold}

  1)  Perform Normal Backup
  2)  Force Full Backup
  3)  Search Repository
  4)  Restore All
  5)  Restore Specific File / Directory
  6)  Show Backup History

  7)  Quit and Disconnect

EOF

echo -n "Please select an option:  "
read _my_choice

case "$_my_choice" in
 1) clear
    perform_backup 
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;
 2) clear
    force_full_backup
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;
 3) clear
    echo -n "Type name of file or directory to search for:  "
    read search
    if [ -z "$search" ]; then
    	echo "Error:  Search term not defined.  Please try again."
	sleep 2
        menu
    fi
    echo -n "From how many days ago? [0D]:  "
    read age
    echo ""
    echo "Results will be displayed below:"
    echo "--"
    echo ""     
    
    if [ -z $age ]; then
    	age=0D
    fi

    duplicity -t $age list-current-files $backupdestination | grep $search   
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;
 4) clear
    echo -n "Restore everything from how many days ago?  [0D]:"
    read age

    if [ -z $age ]; then
        age=0D
    fi
    echo "Warning:  This will restore everything to $restore/restore_$date.  Do you"
    echo "wish to proceed?"
    echo ""
    echo -n "Type:  y/n:  "
    read answer
    if [ ! $answer = y ]; then
        echo "Aborting restore.  No changes have been made"
        sleep 2
        menu
    fi
    echo "Restoring backup.  Please wait..."
    mkdir -p $restore/restore_$date
    duplicity -t $age $backupdestination $restore/restore_$date
    echo "Your backup has been restored to $restore/restore_$date."
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;
 5) clear
    echo -n "Type name of file or directory to restore:  "
    read search
    if [ -z "$search" ]; then
        echo "Error:  Search term not defined.  Please try again."
        sleep 2
        menu
    fi
    echo -n "From how many days ago? [0D]:  "
    read age

    if [ -z $age ]; then
        age=0D
    fi

    echo ""
    echo "Results will be displayed below:"
    echo "--"
    echo "" 
    duplicity -t $age list-current-files $backupdestination | grep $search
    echo "--"
    echo ""
    echo "Using the output above, copy and paste the path below to restore file or directory:"
    read restorefile
    if [ -z "$restorefile" ]; then
        echo "Error:  Search term not defined.  Aborting restore."
        sleep 2
        menu
    fi
    clear
    echo "Restoring $restorefile.  Please wait..."
    mkdir -p $restore/restore_$date
    duplicity -t $age --file-to-restore $restorefile $backupdestination $restore/restore_$date
    echo "Your backup has been restored to $restore/restore_$date."
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;

 6) clear
    show_collection_status
    echo "Press any key to continue..."
    read -p "$*"
    menu ;;
 *) exit ;;
esac

}


# Main

case "$1" in
 --backup) perform_backup ;;
 --backup-force-full) force_full_backup ;;
 --show-backups) show_collection_status ;;
 --list-files) list_current_files ;;
 --restore-all) restore_all ;;
 --restore-single) restore_single ;;
 --menu) menu ;;
 *) help ;;
esac


# Cleanup

unset CLOUDFILES_USERNAME
unset CLOUDFILES_APIKEY
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset PASSPHRASE

