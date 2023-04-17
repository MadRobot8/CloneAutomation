#!/bin/bash
#******************************************************************************************************
#$Header 1.1 2022/03/23 dikumar  base version $
#$Header 1.2 2023/01/02 dikumar   updated for 19c changes $
#	Purpose    :  Script to extract/backup important files/details.
#   Script name:  precloneextractdb.sh
#   Usage      :  sh  precloneextractdb.sh <instance name>
#                 sh  precloneextractdb.sh ORASUP
#   Remarks    :  Ideally this script should be setup in crontab to have Extract run in advance.
#
#******************************************************************************************************

#******************************************************************************************************
#
#  **********    D A T A B A S E - E X T R A C T - S C R I P T   **********
#
#******************************************************************************************************

#******************************************************************************************************
#       Assigning Script arguments
#******************************************************************************************************

dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
scr_home=/u05/oracle/autoclone
etc_home="${scr_home}/etc"
bin_home="${scr_home}/bin"
lib_home="${scr_home}/lib"
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"

#***************************************************************************************************###
# Using instance.properties to load instance specific settings
#***************************************************************************************************###

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [ ! -f "${envfile}" ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="/home/$(whoami)/.${trgcdbname,,}_profile"
if [ ! -f "${envfile}" ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "ERROR: Target Environment profile ${envfile} file not found on database server.\n"
	exit 1;
else
	source "${envfile}" > /dev/null
	sleep 1
fi

#******************************************************************************************************##
#  Create directories for extraction
#******************************************************************************************************##

mkdir  -p  "${currentextractdir}"/tns  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/ctx  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/env  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/dbs  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/app_others > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/pairs  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/app_others/wallet > /dev/null 2>&1
mkdir  -p  "${uploaddir}"/sql > /dev/null 2>&1

chmod -R 777   "${currentextractdir}"  "${uploaddir}"  > /dev/null 2>&1

#***************************************************************************************************###
# Cleaning up old scripts and creating new extract scripts from Database for Post clone Upload part.
#***************************************************************************************************###

log_dir="${extractlogdir}"
dbextractlog="${log_dir}"/extractDB${dbupper^^}.log
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Logfile for this session is at  ${HOST_NAME}" | tee "${dbextractlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:          ${dbextractlog}. " | tee -a "${dbextractlog}"

cd "${extractdir}"
if [ -d "${currentextractdir}" ] ;  then
	cp -pr  "${currentextractdir}"  "${bkpextractdir}"/$(date +'%d-%m-%Y') > /dev/null 2>&1
fi

mkdir -p "${currentextractdir}" > /dev/null 2>&1

#***************************************************************************************************###
# Check PDB/CDB status
#***************************************************************************************************###
check_dbstatus ()
{

cstatus=$(sqlplus -S /nolog <<EOF
connect / as sysdba
set head off
set feedback off
set pagesize 0
select status from v\$instance;
exit;
EOF
)

#cstatus=$(cat /tmp/cdbstat.tmp)
# Check the result and return the status
case "$cstatus" in
    *MOUNT*)    export cdbstatus="MOUNT" ;;
    *OPEN*)     export cdbstatus="OPEN" ;;
    *STARTED*)  export cdbstatus="STARTED" ;;
    *01034*)    export cdbstatus="DOWN" ;;
    *) echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: CHECK CDB STATUS : Could not determine database status. " | tee -a "${dbextractlog}"
      ;;
esac

pstatus=$(sqlplus -S /nolog <<EOF
connect / as sysdba
set head off
set feedback off
set pagesize 0
select open_mode from v\$pdbs;
exit;
EOF
)

#pstatus=$(cat /tmp/pdbstat.tmp)
case "$pstatus" in
    *MOUNT*)       export pdbstatus="MOUNT" ;;
    *WRITE*)       export pdbstatus="OPEN" ;;
    *READ*ONLY*)   export pdbstatus="READ_ONLY" ;;
    *) echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: CHECK PDB STATUS : Could not determine database status. " | tee -a "${dbextractlog}"
      ;;
esac

}

#******************************************************************************************************
# Creating sql files from Database for Post clone Upload part.
#******************************************************************************************************
check_dbstatus

export APPUSER=$(/dba/bin/getpass "${dbupper}" apps)
export APPPASS=$(echo "${APPUSER}" | cut -d/ -f 2)


if [[ "${cdbstatus}" == "OPEN"  &&  "${pdbstatus}" == "OPEN" ]] ; then
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: DB EXTRACT : Extracting DB Directories.  " | tee -a "${dbextractlog}"
sqlplus -s "${APPUSER}"@"${dbupper}" << EOF  > /dev/null
set head off
set feed off
set line 999
spool ${uploaddir}/sql/db_recreate_dba_directories.sql
col SQL FOR a150
set pages 2000
select 'CREATE OR REPLACE DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' as  '||''''||DIRECTORY_PATH ||''''||';'  SQL from DBA_DIRECTORIES ;
select 'GRANT READ, WRITE ON  DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' TO APPS;'  SQL from DBA_DIRECTORIES ;
select 'exit ; ' from dual;
spool off

spool ${uploaddir}/sql/upload_apps_profiles.sql
SELECT DISTINCT 'update fnd_profile_option_values set PROFILE_OPTION_VALUE='||''''||fpov.profile_option_value||''''||' where  PROFILE_OPTION_ID='||fpov.profile_option_id||' AND level_id ='||fpov.level_id||' ; '
    FROM apps.fnd_profile_options fpo,
         apps.fnd_profile_option_values fpov,
         apps.fnd_profile_options_tl fpot,
         apps.fnd_user fu,
         apps.fnd_application fap,
         apps.fnd_responsibility frsp,
         apps.fnd_nodes fnod,
         apps.hr_operating_units hou
   WHERE     fpo.profile_option_id = fpov.profile_option_id(+)
         AND fpo.profile_option_name = fpot.profile_option_name
         AND fu.user_id(+) = fpov.level_value
         AND frsp.application_id(+) = fpov.level_value_application_id
         AND frsp.responsibility_id(+) = fpov.level_value
         AND fap.application_id(+) = fpov.level_value
         AND fnod.node_id(+) = fpov.level_value
         AND hou.organization_id(+) = fpov.level_value ;
select 'commit ; ' from dual;
select 'exit ; ' from dual;
spool off

spool ${uploaddir}/sql/add_tempfiles_.sql
select 'ALTER TABLESPACE '||tablespace_name||' ADD TEMPFILE '||''''||'+${trgasmdg}'||''''||' size 100M autoextend on maxsize 30g ;'  from dba_temp_files ;
select 'exit ; ' from dual;
spool off

set head on
spool ${uploaddir}/sql/tempfile.log
select tablespace_name , sum(bytes)/1024/1024/1024 GB from dba_temp_files group by tablespace_name ;
spool off

exit
EOF

# Backup init parameters from spfile, if present
sqlplus -s / 'as sysdba' << EOF   > /dev/null
create pfile='${bkpinitdir}/init"${ORACLE_SID}".ora.spfile'  from spfile ;
exit
EOF

# Backup init parameters memory, if present
sqlplus -s / 'as sysdba' << EOF   > /dev/null
create pfile='${bkpinitdir}/init"${ORACLE_SID}".ora.memory'  from spfile ;
exit
EOF


if [ -f  "${ORACLE_HOME}"/dbs/spfile"${ORACLE_SID}".ora ] ;  then
		cp "${ORACLE_HOME}"/dbs/spfile"${ORACLE_SID}".ora  ${bkpinitdir}/.
fi

sqlplus -s / 'as sysdba' << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 100
spool /tmp/temp${dblower,,}spfile01.tmp
select value from v\$parameter where name='spfile';
spool off
spool /tmp/temp${dblower,,}control01.tmp
select value from v\$parameter where name='control_files' ;
spool off
exit
EOF

sed -i  '/select/d' /tmp/temp${dblower,,}spfile01.tmp
sed -i  '/spool/d' /tmp/temp${dblower,,}spfile01.tmp
grep -i spfile /tmp/temp${dblower,,}spfile01.tmp > ${bkpinitdir}/spfileloc

sed -i  '/select/d' /tmp/temp${dblower,,}control01.tmp
sed -i  '/spool/d' /tmp/temp${dblower,,}control01.tmp

grep -i cntrl  /tmp/temp${dblower,,}control01.tmp > ${bkpinitdir}/controlfileloc

# Backup logfile details for postclone
rm -f /tmp/logfile.tmp  /tmp/logfile2.tmp

sqlplus -s '/ as sysdba'  << EOF > /dev/null
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 10000
set verify OFF
SET TERMOUT OFF
SET LINES 100
spool /tmp/logfile.tmp
SELECT 'GROUP '||GROUP#||'  '||''''||MEMBER||''''||'  SIZE 1000M BLOCKSIZE 512,' from v\$logfile where type='ONLINE' order by GROUP#;
spool off
exit
EOF

grep 'GROUP' /tmp/logfile.tmp > /tmp/logfile2.tmp  >/dev/null 2>&1
inputfile1=/tmp/logfile2.tmp
lastline=$(tail -n 1 ${inputfile1})
newlastline=$(tail -n 1 ${inputfile1} |sed 's/,\([^,]*\)$/ \1/' )
sed -i  '$d' ${inputfile1} > /dev/null
echo "   "${newlastline} >> ${inputfile1}
cat ${inputfile1} > ${bkpinitdir}/logfile.txt
rm -f /tmp/logfile.tmp  /tmp/logfile2.tmp >/dev/null 2>&1
chmod -R 777 "${extractdir}"  "${uploaddir}"  > /dev/null 2>&1
rm -f /tmp/temp${dblower,,}control01.tmp > /dev/null 2>&1
rm -f /tmp/temp${dblower,,}spfile01.tmp > /dev/null 2>&1

export dbsqlextract="COMPLETED"
else

 echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: DB EXTRACT : Database sql extract was skipped due to unknown database status. " | tee -a "${dbextractlog}"
 export dbsqlextract="PASS"
fi

## backup utrlp.sql from ORACLE_HOME
cp "${ORACLE_HOME}"/rdbms/admin/utlrp.sql  ${uploaddir}/sql/.  > /dev/null 2>&1
echo 'exit ' >> ${uploaddir}/sql/utlrp.sql
cp "${ORACLE_HOME}"/rdbms/admin/utlprp.sql ${uploaddir}/sql/.  > /dev/null 2>&1


#******************************************************************************************************
#  Backup important files, to be restored as post clone process
#******************************************************************************************************

echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: DB EXTRACT : Extracting TNS, CONTEXT, ENV, Certs files from Database node.   " | tee -a "${dbextractlog}"
cp  ${CONTEXT_FILE}  "${currentextractdir}"/ctx/.   > /dev/null 2>&1
cp  "${ORACLE_HOME}"/*.env   "${currentextractdir}"/env/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/dbs/*$ORACLE_SID*   "${currentextractdir}"/dbs/.  > /dev/null 2>&1
cp -pr "${ORACLE_HOME}"/dbs/"${trgdbname^^}"_utlfiledir.txt   "${currentextractdir}"/dbs/.  > /dev/null 2>&1
cp  -pr "${TNS_ADMIN}"/*   "${currentextractdir}"/tns/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/appsutil  "${currentextractdir}"/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/wso2wallet  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/wso2wallet2  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/awswallet  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1

{
ls -lrt "${currentextractdir}"/* 
ls -rlt "${currentextractdir}"/db_others/wallet/* 
ls -rlt "${currentextractdir}"/db_others/*  
} >> "${dbextractlog}" 2>&1
sleep 2

#Cleaning up backup files older than 100 days.
#find ${bkpextractdir} -type d -mtime +100 -exec rm -rf {}\; >> "${dbextractlog}"  2>&1
export dbfileextract="COMPLETED"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: DB EXTRACT :***** $(basename $0) Scripts completed   *****"  | tee -a "${dbextractlog}"

exit 0
#******************************************************************************************************
#
#  **********   E N D - O F - D A T A B A S E - E X T R A C T - S C R I P T   **********
#
#******************************************************************************************************