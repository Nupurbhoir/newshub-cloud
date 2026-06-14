#!/bin/bash
# backup_db.sh
# Purpose: Backup MySQL database and upload to S3 (to be run via Cron)
# Add this to crontab via: crontab -e
# Example cron entry for daily at 2AM: 0 2 * * * /path/to/backup_db.sh >> /var/log/backup_db.log 2>&1

DB_CONTAINER_NAME="newshub-db-1"
DB_USER="root"
DB_PASS="root_pass"
DB_NAME="newshub_db"
BACKUP_DIR="/opt/newshub/backups"
DATE=$(date +\%Y-\%m-\%d_\%H-\%M-\%S)
BACKUP_FILE="$BACKUP_DIR/newshub_backup_$DATE.sql"
S3_BUCKET="your-s3-bucket-name" # Remember to change this

echo "Starting database backup: $DATE"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Dump database from the running docker container
docker exec $DB_CONTAINER_NAME /usr/bin/mysqldump -u $DB_USER --password=$DB_PASS $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Database backup created successfully: $BACKUP_FILE"
    
    # Upload to S3 if AWS CLI is installed and configured
    if command -v aws &> /dev/null; then
        echo "Uploading to S3..."
        aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/db-backups/
        if [ $? -eq 0 ]; then
            echo "Uploaded to S3 successfully."
            # Remove local backup older than 7 days to save space
            find $BACKUP_DIR -type f -name "*.sql" -mtime +7 -delete
        else
            echo "Failed to upload to S3."
        fi
    else
        echo "AWS CLI not installed. Skipping S3 upload."
    fi
else
    echo "Database backup failed."
fi
echo "Backup process completed."
