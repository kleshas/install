#!/bin/bash

read -p "Do you want to backup skyrimmodlist to /mnt/4TB? " RESP1
if [ "$RESP1" = "y" ]; then
	rsync -avP --delete /mnt/SN850/skyrim/modlists/ /mnt/4TB/skyrim/modlists --log-file=$HOME/Downloads/skyrimmodlists.log
	fi


read -p "Do you want to backup /home and important files to /mnt/4TB? " RESP1
if [ "$RESP1" = "y" ]; then
	rsync -avPL --delete --delete-excluded --ignore-errors \
	--exclude='**steam**/' \
	--exclude='**Proton**/' \
	--exclude='**Prismlauncher**/' \
	--exclude='**.wine**/' \
	--exclude='**cache**/' \
	--exclude='**.cache**/' \
	--exclude='**.cargo**/' \
	--exclude='**appcache**/' \
	--exclude='**Cache**/' \
	--exclude='**runners**/' \
	/home/bhava/ "/mnt/4TB/backup/home backup/"

	rsync -avP --delete --mkpath /mnt/SN850/STANDALONES/ /mnt/4TB/backup/STANDALONES --log-file=$HOME/Downloads/STANDALONES.log
	fi

read -p "Do you want to rsync everything (12TB, 10TB, homebackup) to the backup system? " RESP2
if [ "$RESP2" = "y" ]; then
	rsync -avP --delete --mkpath /mnt/4TB/backup/ bhava@192.168.1.87:/mnt/backup/backup --log-file=$HOME/Downloads/4TB.log
	rsync -avP --delete --mkpath /mnt/10TB/ bhava@192.168.1.87:/mnt/backup/10TB --log-file=$HOME/Downloads/10TB.log
	rsync -avP --delete --mkpath /mnt/12TB/ bhava@192.168.1.87:/mnt/backup/12TB --log-file=$HOME/Downloads/12TB.log
	fi
	
	
read -p "press any key to exit"
