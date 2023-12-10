#!/bin/bash

# Todays date
DATE=`date +%d-%h-%Y`

# Create log directory
LOG_PATH=/tmp/weekly-backup/logs
mkdir -p $LOG_PATH
#Log file 
LOG_FILE=$LOG_PATH/backup_${DATE}.log
echo  | tee -a $LOG_FILE
echo Script started on $DATE $(date -u +"%Y-%m-%dT%H:%M:%SZ") | tee -a $LOG_FILE    

# Default path on server
POSTGRES_PATH=/tmp/weekly-backup/postgresBackup/$DATE
MONGO_PATH=/tmp/weekly-backup/mongoBackup/$DATE

# Create database directory
mkdir -p $POSTGRES_PATH
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Created $POSTGRES_PATH directory >> $LOG_FILE    

mkdir -p $MONGO_PATH
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Created $MONGO_PATH directory >> $LOG_FILE    
# Database configurations
PG_HOST="x.x.x.x"
PG_USERNAME="postgres"
PG_PASSWORD="admin"
MONGO_HOST="x.x.x.x"
MONGO_PORT="27017"
MONGO_USERNAME="root"
MONGO_PASSWORD="Password"

# Delete previous backup folder
NO_OF_DAYS=7

# Database name
PG_DBS=`PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -U $PG_USERNAME -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'`
MONGO_DBS="database-1 database-2 database-3"

# Postgres backup
for i in $PG_DBS; do  if [ "$i" != "postgres" ] && [ "$i" != "template0" ] && [ "$i" != "template1" ] && [ "$i" != "template_postgis" ]; then    
    echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Started dumping for $i >> $LOG_FILE
    PGPASSWORD=$PG_PASSWORD pg_dump -h $PG_HOST -U $PG_USERNAME -v -d $i > $POSTGRES_PATH/$i.sql
    echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Completed dumping for $i to $POSTGRES_PATH/$i.sql >> $LOG_FILE
  fi
done


# Mongo backup
for db in $MONGO_DBS; do
    echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Started dumping for $db >> $LOG_FILE
    echo -- $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Started dumping for $db
    mongodump --host $MONGO_HOST --port $MONGO_PORT --authenticationDatabase=admin --username $MONGO_USERNAME --password $MONGO_PASSWORD --db $db --out $MONGO_PATH/$db
    echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Completed dumping for $db to $MONGO_PATH/$db >> $LOG_FILE
    echo -- $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Completed dumping for $db to $MONGO_PATH/$db
done

ls -lr $MONGO_PATH/ >> $LOG_FILE
ls -lr $POSTGRES_PATH/ >> $LOG_FILE



# Uploading backup to s3
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Started file uploading to s3 >> $LOG_FILE

aws s3 sync /tmp/weekly-backup/postgresBackup/ s3://databackup/postgresBackup/
aws s3 sync /tmp/weekly-backup/mongoBackup/ s3://databackup/mongoBackup/

echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Completed file uploading to s3 >> $LOG_FILE


# Deleting folder backup folder on server
sleep 10
rm -rfv $POSTGRES_PATH >> $LOG_FILE
sleep 10
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Removed $POSTGRES_PATH directory >> $LOG_FILE
sleep 10
rm -rfv $MONGO_PATH >> $LOG_FILE
sleep 10
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Removed $MONGO_PATH directory >> $LOG_FILE
sleep 10

# Previous folder name to delete
DEL_FOLDER=`date +%d-%h-%Y --date="$NO_OF_DAYS days ago"`

# Deleting previous backup folder on aws
aws s3 rm s3://databackup/postgresBackup/$DEL_FOLDER --recursive >> $LOG_FILE
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Removed s3://databackup/postgresBackup/$DEL_FOLDER directory >> $LOG_FILE

aws s3 rm s3://databackup/mongoBackup/$DEL_FOLDER --recursive >> $LOG_FILE
echo == $(date -u +"%Y-%m-%dT%H:%M:%SZ") : Removed s3://databackup/mongoBackup/$DEL_FOLDER directory >> $LOG_FILE

echo  | tee -a $LOG_FILE
echo Script ended on $DATE $(date -u +"%Y-%m-%dT%H:%M:%SZ") | tee -a $LOG_FILE
