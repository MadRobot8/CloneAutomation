#!/bin/bash
#******************************************************************************************************##
#  **********  D A T A B A S E - F U L L - H O T - N E T B A C K U P - T A P E - B A C K U P - S C R I P T **********
#******************************************************************************************************##

if [ -f /dba/tmp/gahprdfullbkp.lock ]; then
  printf "GAHPRD Full/Hot Backup script is already running. Exiting this run!!";
  exit 1
else
  echo $$ > /dba/tmp/gahprdfullbkp.lock
fi

. /home/oracle/.rmandb_profile
export SCRIPT_DIR=/dba/bin
export LOG_DIR=/dba/log
export RMAN_BASE=/backuprman/ebs_backups
DATE=$(date '+%d-%m-%Y')
MAILID=orapmon@expedia.com
MAILID1=dbapager@expediainc.pagerduty.com

printf "GAHPRD Full/Hot Backup is Running....\n"
rman TARGET sys/YfXqM0pNs079bp1b@GAHPRD1 CATALOG rmancat/h1ghland3r@RMANDB log $LOG_DIR/rman_fulldb_bkp_GAHPRD_"${DATE}".log << EOF
RUN
{
sql "alter system switch logfile";
sql "alter system archive log current";
ALLOCATE CHANNEL CH1 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup01/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH2 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup02/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH3 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup03/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH4 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup04/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH5 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup05/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH6 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup06/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH7 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup07/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH8 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup08/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH9 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup09/bk_dbfile_%d_%s_%t' ;
ALLOCATE CHANNEL CH10 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup10/bk_dbfile_%d_%s_%t' ;
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=c01c_ora_ebsdb_gahprd';

backup
incremental level 0
filesperset 1
database
tag 'GAHPRD_RAC_HOT_FULL_BACKUP';

ALLOCATE CHANNEL CH11 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup01/bk_control_%d_%s_%t';
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=c01c_ora_ebsdb_gahprd';
#Backup Control file
backup
current controlfile
tag 'GAHPRD_RAC_CTLbackup';
}


allocate channel for maintenance device type disk connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 ;
change archivelog all crosscheck;
release channel;

RUN
{
sql "alter system switch logfile";
sql "alter system archive log current";
ALLOCATE CHANNEL CH1 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup01/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH2 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup02/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH3 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup03/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH4 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup04/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH5 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup05/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH6 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup06/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH7 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup07/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH8 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup08/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH9 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup09/bk_arc_%d_%s_%t' ;
ALLOCATE CHANNEL CH10 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup10/bk_arc_%d_%s_%t' ;
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=c01c_ora_ebsdb_gahprd';

backup
filesperset 20
archivelog all not backed up 1 times;
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'TRUNC(SYSDATE-3)';

ALLOCATE CHANNEL CH11 type 'SBT_TAPE' connect sys/"YfXqM0pNs079bp1b"@GAHPRD1 format '/rman1/gahprd/backup01/bk_control_%d_%s_%t';
SEND 'NB_ORA_SERV=chcxbkpnba001';
SEND 'NB_ORA_POLICY=c01c_ora_ebsdb_gahprd';
#Backup Control file
backup
current controlfile
tag 'GAHPRD_RAC_CTLbackup';
}

exit;
EOF

ERRCNT=$(grep -ic RMAN- $LOG_DIR/rman_fulldb_bkp_GAHPRD_"${DATE}".log)
if [ "$ERRCNT" = 0 ]
then
mailx -s "GAHPRD RMAN Full/Hot Backup Completed ...Successfully" $MAILID < $LOG_DIR/rman_fulldb_bkp_GAHPRD_"${DATE}".log
else
mailx -s "CRITICAL: GAHPRD RMAN Full/Hot Backup Completed with Errors. Please Review the Log" $MAILID1 < $LOG_DIR/rman_fulldb_bkp_GAHPRD_"${DATE}".log
fi

rm -f /dba/tmp/gahprdfullbkp.lock > /dev/null 2>&1

exit
#******************************************************************************************************##
#  **********  D A T A B A S E - F U L L - H O T - N E T B A C K U P - T A P E - B A C K U P - S C R I P T - E N D **********
#******************************************************************************************************##

