#!/bin/bash

DATE=$(date +'%Y-%m-%d_%H-%M-%S')

# Záloha dat
tar czf /opt/vaultwarden/backup/vaultwarden_backup_$DATE.tar.gz -C /opt/vaultwarden/data .

# Kopírování na NAS
cp /opt/vaultwarden/backup/vaultwarden_backup_$DATE.tar.gz /mnt/export2266/NAS/Backup/vaultwarden

# Čištění starých záloh
find /opt/vaultwarden/backup/ -type f -mtime +7 -name "*.tar.gz" -exec rm {} \;
