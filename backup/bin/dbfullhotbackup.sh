#!/bin/bash


dbupper=${1^^}
dblower=${dbupper,,}
. /home/$(whoami)/."${dblower}"_profile

export SCRIPT_DIR=/dba/bin
export LOG_DIR=/dba/log
export RMAN_BASE=/backuprman/ebs_backups
export DATE=$(date '+%d-%m-%Y')
MAILID=orapmon@expedia.com
MAILID1=erppager@expedia.com,dbapager@expediainc.pagerduty.com

mkdir $RMAN_BASE/ORAPRD/fulldb/$DATE

echo "GAHMAUI Full Backup is Running....\n"
rman TARGET /   log $LOG_DIR/rman_full_backup_ORAPRD_${DATE}.log << EOF
RUN
{
ALLOCATE CHANNEL disk1 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk2 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk3 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk4 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk5 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk6 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk7 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk8 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk9 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk10 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk11 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
ALLOCATE CHANNEL disk12 DEVICE TYPE DISK FORMAT '/backuprman/ebs_backups/"${dbupper}"/fulldb/$DATE/FULL_Backup%d_DB_%u_%s_%p_%T';
BACKUP INCREMENTAL LEVEL 0 DATABASE PLUS ARCHIVELOG ;
BACKUP CURRENT CONROLFILE
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
release channel disk11;
release channel disk12;
}
exit;
EOF
ERRCNT=`grep -i RMAN- $LOG_DIR/rman_full_backup_ORAPRD_${DATE}.log|wc -l`
if [ $ERRCNT = 0 ]
then
mailx -s "ORAPRD RMAN FULL Backup Completed...Successfully" $MAILID < $LOG_DIR/rman_full_backup_ORAPRD_${DATE}.log
else
mailx -s "CRITICAL: ORAPRD RMAN FULL Backup Completed with Errors - Please Review the log" $MAILID1 < $LOG_DIR/rman_full_backup_ORAPRD_${DATE}.log
fi
exit