#!/bin/bash
#******************************************************************************************************##
#  **********  D A T A B A S E - A R C H I V E - B A C K U P - S C R I P T**********
#******************************************************************************************************##

if [ -f /dba/tmp/oraprdarchbkp.lock ]; then
  printf "ORAPRD Archive Backup script is already running. Exiting this run!!";
  exit 1
else
  echo $$ > /dba/tmp/oraprdarchbkp.lock
fi


. /home/oracle/.rmandb_profile
export SCRIPT_DIR=/dba/bin
export LOG_DIR=/dba/log
export RMAN_BASE=/backuprman/ebs_backups
DATE=$(date '+%d-%m-%Y')
MAILID=orapmon@expedia.com
MAILID1=erppager@expedia.com,dbapager@expediainc.pagerduty.com
mkdir -p $RMAN_BASE/ORAPRD/archivelogs/"$DATE" > /dev/null 2>&1

printf "ORAPRD Archive Backup is Running....\n"
rman TARGET sys/BFu568kSern5EYSn@ORAPRD2 CATALOG rmancat/h1ghland3r@RMANDB log $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log << EOF
RUN
{
ALLOCATE CHANNEL disk1 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk2 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk3 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk4 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk5 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk6 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk7 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk8 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk9 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk10 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/ORAPRD/archivelogs/$DATE/ARC_Backup%d_DB_%u_%s_%p_%T';
BACKUP ARCHIVELOG ALL not backed up 1 times;
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'TRUNC(SYSDATE-7)';
release channel disk1;
release channel disk2;
release channel disk3;
release channel disk4;
release channel disk5;
release channel disk6;
release channel disk7;
release channel disk8;
release channel disk9;
release channel disk10;
}
exit;
EOF
ERRCNT=$(grep -ic RMAN- $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log )
if [ "$ERRCNT" = 0 ] ;
then
mailx -s "ORAPRD RMAN Archive Backup Completed ...Successfully" $MAILID < $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log
else
mailx -s "CRITICAL: ORAPRD RMAN Archive Backup Completed with Errors. Please Review the Log" $MAILID1 < $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log
fi


# For adhoc backup runs
if [ -f /backuprman/ebs_backups/ORAPRD/archivelogs/adhocarch.running ]; then
  mv /backuprman/ebs_backups/ORAPRD/archivelogs/adhocarch.running  /backuprman/ebs_backups/ORAPRD/archivelogs/adhocarch.complete
fi


rm -f /dba/tmp/oraprdarchbkp.lock > /dev/null 2>&1

exit
#******************************************************************************************************##
#  **********  D A T A B A S E - A R C H I V E - B A C K U P - S C R I P T - E N D **********
#******************************************************************************************************##