#!/bin/bash
#******************************************************************************************************##
#  **********  D A T A B A S E - A R C H I V E - N E T B A C K U P - T A P E - B A C K U P - S C R I P T **********
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

DATE=$(date '+%d-%m-%Y')
MAILID=orapmon@expedia.com
MAILID1=dbapager@expediainc.pagerduty.com

printf "ORAPRD Archive Backup is Running....\n"
rman TARGET sys/Pm_K5Bru@ORACPRD2 CATALOG rmancat/h1ghland3r@RMANDB log $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log << EOF
RUN
{
sql "alter system switch logfile";
sql "alter system archive log current";
ALLOCATE CHANNEL CH1 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup01/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH2 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup02/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH3 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup03/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH4 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup04/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH5 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup05/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH6 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup06/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH7 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup07/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH8 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup08/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH9 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup09/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH10 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup10/bk_arc_%d_%s_%t' ;
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=p02c_ora_ebsdb_oraprd';

backup
filesperset 20
archivelog all not backed up 1 times;
#DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'TRUNC(SYSDATE-2)';

ALLOCATE CHANNEL CH11 type 'SBT_TAPE' connect sys/"Pm_K5Bru"@ORACPRD2 format '/rman1/oraprd/backup01/bk_control_%d_%s_%t';
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=p02c_ora_ebsdb_oraprd';
#Backup Control file
backup
current controlfile
tag 'ORAPRD_RAC_CTLbackup';
}
exit;
EOF

ERRCNT=$(grep -ic RMAN- $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log)
if [ "$ERRCNT" = 0 ]
then
mailx -s "ORAPRD RMAN Archive Backup Completed ...Successfully" $MAILID < $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log
else
mailx -s "CRITICAL: ORAPRD RMAN Archive Backup Completed with Errors. Please Review the Log" $MAILID1 < $LOG_DIR/rman_archive_bkp_ORAPRD_"${DATE}".log
fi

# For adhoc backup runs
if [ -f /backuprman/ebs_backups/ORAPRD/rman/archivelogs/adhocarch.running ]; then
  mv /backuprman/ebs_backups/ORAPRD/rman/archivelogs/adhocarch.running  /backuprman/ebs_backups/ORAPRD/rman/archivelogs/adhocarch.complete
fi

rm -f /dba/tmp/oraprdarchbkp.lock > /dev/null 2>&1

exit
#******************************************************************************************************##
#  **********  D A T A B A S E - A R C H I V E - N E T B A C K U P - T A P E - B A C K U P - S C R I P T - E N D **********
#******************************************************************************************************##

