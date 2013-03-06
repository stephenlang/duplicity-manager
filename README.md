## duplicity-manager

Wrapper script for Duplicity to assist in making backup management with
Duplicity a bit more user friendly.


### Purpose

Coming up with a secure and cost effective backup solution can be a
daunting task as there are many considerations that much be taken into
account.  Some of the more basic items to think about are:

- Where to store your backups?
- Is the storage medium redundant?
- How will data retention will handled?
- How will the data at rest be encrypted?

A tool that I prefer for performing encrypted, bandwidth efficient backups
to a variety of remote backends such as Rackspace Cloud Files, Amazon S3,
and many others is Duplicity.

Taken from [duplicity's](http://duplicity.nongnu.org) site, Duplicity backs
directories by producing encrypted tar-format volumes and uploading them to
a remote or local file server. Because duplicity uses librsync, the
incremental archives are space efficient and only record the parts of files
that have changed since the last backup. Because duplicity uses GnuPG to
encrypt and/or sign these archives, they will be safe from spying and/or
modification by the server.

Duplicity-manager was created to act as a wrapper script for the tasks I
commonly perform with Duplicity.  


### Features

- Simple invocation from cron for nightly backups.
- All in one script for performing backups, restores, searching for content
  from specific time period.
- Provides an optional menu driven interface to make backups as painless as
  possible.


### Configuration

The currently configurable options are listed below:

	# Configuring either Rackspace Cloud Files or Amazon S3 backends

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


### Usage

	./duplicity-manager.sh 

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


### Implementation

Download script to desired directory and set it to be executable:

	# Linux based systems
	cd /root
	git clone https://github.com/stephenlang/duplicity-manager
	
After configuring the tunables in the script (see above), create a cron job
to execute the script one a day:

	# Linux based systems
	crontab -e
	10 3 * * * /root/duplicity-manager/duplicity-manager.sh

As with any backup solution, it is critical that you test your backups
often to ensure your data is recoverable in the event a restore is needed.
