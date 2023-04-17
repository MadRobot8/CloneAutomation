#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/15 dikumar fundbcommon.sh
#  Purpose  : Function library for common database operations.
#
#  SYNTAX   :
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  C O M M O N - D A T A B A S E -  T A S K - F U N - S C R I P T **********
#******************************************************************************************************##
HOST_NAME=$(uname -n | cut -f1 -d".")

# Common functions

#To validate current os user
os_user_check()
	{
	user=$1
	if [ "$(whoami)" != "$user" ]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Error: User must be ${user} \n"
		exit 1
	fi
	}

#To source profile file for DB
source_profile()
	{
	dblower=${1,,}
	unset envfile
	envfile="/home/$(whoami)/.${dblower}_profile"
	if [ ! -f "${envfile}" ]; then
		echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
		exit 1;
	else
		source "${envfile}" > /dev/null
	fi
	}

# Exit while failure
error_exit()
{
  sed -i '/^session_state/d' "${restart_dir}"/clone.rsp  >/dev/null
  echo -e "session_state=\"${session_state}\"" >> "${restart_dir}"/clone.rsp
  exit 0
}

	# Running utlrp.sql on database node
compile_invalid_objects()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"


sqlplus  '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
spool ${restore_log}/spool_compile_invalids${trgdbname^^}."${startdate}"
@${common_sql}/utlrp.sql
@${common_sql}/utlrp.sql
@${common_sql}/utlrp.sql
spool off
exit
EOF

	}


	# Password validate function ######
chk_password()
{
	unpw="apps/${1}@${2}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

	if [ $? -ne 0 ]; then
		#   echo -e "return 1"
		return 1
	fi
	#echo -e "return 0"
	return 0
}

# To load up password for Target instance
	load_getpass_password()
	{
	dbupper="${trgdbname^^}"

	#Load Target passwords
	export SYSTUSER=$(/dba/bin/getpass "${dbupper}" system)
	#echo ${SYSTUSER}
	export SYSTPASS=$(echo "$SYSTUSER" | cut -d/ -f 2)
	export APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
	export APPSPASS=$(echo "$APPSUSER" | cut -d/ -f 2)
	#echo ${APPSUSER}
	export EXPDUSER=$(/dba/bin/getpass "${dbupper}" xxexpd)
	export EXPDPASS=$(echo "$EXPDUSER" | cut -d/ -f 2)
	export OALLUSER=$(/dba/bin/getpass "${dbupper}" alloracle)
	export OALLPASS=$(echo "$OALLUSER" | cut -d/ -f 2)
	export SYSADUSER=$(/dba/bin/getpass "${dbupper}" sysadmin)
	export SYSADPASS=$(echo "$SYSADUSER" | cut -d/ -f 2)
	export WLSUSER=$(/dba/bin/getpass "${dbupper}" weblogic )
	export WLSPASS=$(echo "$WLSUSER" | cut -d/ -f 2 )
	#WLSPASS="weblogic123"
	export VSAPPREADUSER=$(/dba/bin/getpass "${dbupper}" sappreaduser )
	export VSAPPREADPASS=$(echo "$VSAPPREADUSER" | cut -d/ -f 2 )
	export VSAPPWRITEUSER=$(/dba/bin/getpass "${dbupper}" sappwriteuser )
	export VSAPPWRITEPASS=$(echo "$VSAPPWRITEUSER" | cut -d/ -f 2)

	}

	# Validate which APPS password is working - Source or Target
	validate_apps_password()
	{
	chk_password "${workappspass}"  "${trgdbname^^}"
	_chkTpassRC1=$?
	sleep 2
	chk_password "${APPSPASS}"  "${trgdbname^^}"
	_chkTpassRC2=$?
	sleep 2
	if [ ${_chkTpassRC1} -eq 0 ]; then
		echo -e  " "
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t*******  Source APPS Password is working  *******" | tee -a "${logf}"
        echo -e  " "
	elif [ ${_chkTpassRC2} -eq 0 ]; then
        workappspass=${APPSPASS}
		echo -e  " "
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t*******  Target APPS Password is working  *******" | tee -a "${logf}"
        echo -e  " "
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t WARNING: \n Source and Target - Both APPS passwords are not working, APPS SQL part will be skipped\n" | tee -a "${logf}"
	fi

	}



	# Shutdown and restart database
bouncedb()
	{

	os_user_check oracle
	source_profile "${trgdbname}"

sqlplus  '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_bouncedb${trgdbname^^}.${startdate}
SHUTDOWN IMMEDIATE;
STARTUP
SPOOL OFF ;
exit
EOF
	rt_stat=$?

	if [ "${rt_stat}" -gt 0 ];
		then
		db_bounce="FAILED"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ERROR: Database bounce failed on Target. EXITING !!\n" | tee -a "${logf}"
	else
		db_bounce="SUCCESS"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Database restarted Successfully." | tee -a "${logf}"
	fi
	}

	#To validate given database name with current environment
check_dbname()
	{
	dbupper="${1^^}"
	dblower="${1,,}"

	os_user_check oracle
	source_profile "${dbupper}"

	if  grep -q "${dbupper}" <<< "${ORACLE_SID}" ; then
		namecheck="Y"
	else
		namecheck="N"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  ERROR: Target Environment name not matching with given Database name. EXITING !!\n" | tee -a "${logf}"
		exit 1
	fi

	}

	#Check running database process at OS level
check_dbprocess()
	{
	dbupper="${1^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Checking for Target Database processes" | tee -a "${logf}"
	if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -gt 0 ] ; then
		dbprocess="running"
	else
		sleep 30   # Wait for 1 minutes
		if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -gt 0 ] ; then
			dbprocess="running"
		elif [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
			dbprocess="stopped"
		else
			echo ' ' > /dev/null
		fi
	fi

	#return ${dbprocess}
	}

	#Check database state- OPEN, MOUNT, NOMOUNT, DOWN
check_dbstatus()
	{
	dbupper="${1^^}"

	os_user_check oracle
	source_profile "${dbupper}"

	chkfile="/tmp/checkinststatus${ORACLE_SID}.tmp"
	if [ -f "${chkfile}" ]; then
	  rm /tmp/checkinststatus"${ORACLE_SID}".tmp
	fi

sqlplus -s '/ as sysdba'  << EOF > /dev/null
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkinststatus${ORACLE_SID}.tmp
select status from v\$instance ;
spool off
exit
EOF


	check_stat=$(</tmp/checkinststatus"${ORACLE_SID}".tmp)
	check_stat="${check_stat// /}"
	down_stat=$(grep -ic ORA-01034 /tmp/checkinststatus"${ORACLE_SID}".tmp )
	# shellcheck disable=SC2003
	err_cnt=$(expr "${down_stat}" )
	if [ "${check_stat}" = "STARTED" ]; then
		db_state="NOMOUNT"
	elif [ "${check_stat}" = "MOUNTED" ]; then
		db_state="MOUNT"
	elif [ "${check_stat}" = "OPEN" ]; then
		db_state="OPEN"
	elif [ "${err_cnt}" -ne 0 ]; then
		db_state="DOWN"
	else
		db_state="UNKNOWN"
	fi

	#return ${db_stat}
	}

startdb_sqlplus()
	{
	dbupper="${1^^}"
	startup_mode=${2}
	os_user_check oracle
	source_profile "${trgdbname}"
	if [ -z "${startup_mode}" ] ; then
		echo 'startup;' | "${ORACLE_HOME}"/bin/sqlplus -s  '/ as sysdba' >>  "${logf}"
		rt_stat=$?
	elif [ "${startup_mode}" = "NOMOUNT" ] || [ "${startup_mode}" = "MOUNT" ] ; then
		echo "startup ${startup_mode} ; " | "${ORACLE_HOME}"/bin/sqlplus -s  '/ as sysdba' >>  "${logf}"
		rt_stat=$?
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tStartup parameters are wrong. Please check. EXITING !!\n" | tee -a "${logf}"
		exit 1
	fi

	if [ "${rt_stat}" -gt 0 ]; then
		db_start="FAILED"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tERROR: Database Startup failed on Target Database. EXITING !!\n" | tee -a "${logf}"
	else
		db_start="SUCCESS"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Database Started Successfully.\n" | tee -a "${logf}"
	fi
	}


check_startdb_sqlplus()
	{
	dbupper="${1^^}"
	os_user_check oracle
	source_profile "${dbupper}"

sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on
spool ${restore_log}/spool_checkDBstartup${trgdbname^^}.${startdate}
startup;
spool off ;
exit
EOF

	rt_stat=$?
	if [ "${rt_stat}" -gt 0 ];
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tERROR: Database could not be started. Please check init.ora or spfile. EXITING !!\n" | tee -a "${logf}"
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tDatabase Started Successfully." | tee -a "${logf}"
	fi
	unset rt_stat
	check_dbstatus "${dbupper}"
	}

startdb_restore()
	{
	dbupper=${1^^}
	os_user_check oracle
	source_profile "${dbupper}"

	if [ -f "${bkpinitdir}"/spfile"${ORACLE_SID}".ora ]; then
		cp "${bkpinitdir}"/spfile"${ORACLE_SID}".ora "${ORACLE_HOME}"/dbs/.

sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_startupRestore${trgdbname^^}.${startdate}
SHUTDOWN ABORT;
STARTUP NOMOUNT;
ALTER SYSTEM SET DB_NAME=${srcdbname} scope=SPFILE ;
ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;
alter system reset db_recovery_file_dest_size scope=spfile ;
alter system reset db_recovery_file_dest scope=spfile ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
spool off ;
exit
EOF

	elif [ ! -f "${bkpinitdir}"/spfile"${ORACLE_SID}".ora ] && [ -f "${bkpinitdir}"/init"${ORACLE_SID}".ora.memory ] ;  then
		cp "${bkpinitdir}"/init"${ORACLE_SID}".ora.memory "${ORACLE_HOME}"/dbs/.

sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_startupRestore${trgdbname^^}.${startdate}
STARTUP pfile='${bkpinitdir}/init${dbupper}.ora.memory' NOMOUNT;
create spfile='${trgspfile}' from memory ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
ALTER SYSTEM SET DB_NAME=${srcdbname} scope=SPFILE ;
ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;
alter system reset db_recovery_file_dest_size scope=spfile ;
alter system reset db_recovery_file_dest scope=spfile ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
spool off ;
exit
EOF

	elif [ ! -f "${bkpinitdir}"/spfile"${ORACLE_SID}".ora ] && [ ! -f "${bkpinitdir}"/init"${ORACLE_SID}".ora.memory ] && [ -f "${bkpinitdir}"/init"${ORACLE_SID}".ora.spfile ] ; then
		cp "${bkpinitdir}"/init"${ORACLE_SID}".ora.spfile "${ORACLE_HOME}"/dbs/.

sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_startupRestore${trgdbname^^}.${startdate}
STARTUP pfile='${bkpinitdir}/init${dbupper}.ora.spfile' NOMOUNT;
create spfile='${trgspfile}' from memory ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
ALTER SYSTEM SET DB_NAME=${srcdbname} scope=SPFILE ;
ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;
alter system reset db_recovery_file_dest_size scope=spfile ;
alter system reset db_recovery_file_dest scope=spfile ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
spool off ;
exit
EOF

	fi

	rt_stat=$?
	if [ "${rt_stat}" -gt 0 ]; then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tERROR: Database could not be started in NOMOUNT.EXITING !!\n" | tee -a "${logf}"
		exit 1
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tDatabase Started in NOMOUNT for RESTORE." | tee -a "${logf}"
	fi
	unset rt_stat
	}

abortdb()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo 'shutdown abort;' | "${ORACLE_HOME}"/bin/sqlplus -s  '/ as sysdba'   >> "${logf}"

	if [ $? -gt 0 ]; then
		db_abort="FAILED"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tERROR: SHUTDOWN ABORT FAILED on Target Database. EXITING !!\n" | tee -a "${logf}"
	else
		db_abort="SUCCESS"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Database stopped Successfully." | tee -a "${logf}"
	fi
	}

stopdb_sqlplus()
	{
	os_user_check oracle
	source_profile "${trgdbname}"
	echo 'shutdown immediate;' | "${ORACLE_HOME}"/bin/sqlplus -s  '/ as sysdba' >>  "${logf}"
	rt_stat=$?

	if [ "${rt_stat}" -gt 0 ]; then
		db_stop="FAILED"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ERROR: Database Shutdown failed on Target Database. EXITING !!\n" | tee -a "${logf}"
	else
		db_stop="SUCCESS"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Database stopped Successfully." | tee -a "${logf}"
	fi
	}


disable_cluster()
	{
	os_user_check oracle
	source_profile "${trgdbname}"
sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_disableCluster${trgdbname^^}.${startdate}
alter system set cluster_database=false scope=spfile ;
spool off;
exit
EOF
	rt_stat=$?

	if [ "${rt_stat}" -gt 0 ]; then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ERROR: CLUSTER_DATABASE could not be disabled. EXITING !!\n" | tee -a "${logf}"
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t CLUSTER_DATABASE set to FALSE Successfully." | tee -a "${logf}"
	fi
	}

dropdb()
	{
	os_user_check oracle
	source_profile "${trgdbname}"

sqlplus  '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${restore_log}/spool_dropdb${trgdbname^^}.${startdate}
shutdown abort;
startup mount exclusive;
alter system enable restricted session;
DROP DATABASE;
SPOOL OFF ;
exit
EOF
	rt_stat=$?

	if [ "${rt_stat}" -gt 0 ]; then
		db_drop="FAILED"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ERROR: Database Drop failed on Target Database. EXITING !!\n" | tee -a "${logf}"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile - ${restore_log}/spool_dropdb${trgdbname^^}.${startdate}" | tee -a "${logf}"
	else
		db_drop="SUCCESS"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Database dropped Successfully." | tee -a "${logf}"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile - ${restore_log}/spool_dropdb${trgdbname^^}.${startdate}" | tee -a "${logf}"
	fi
	}
#******************************************************************************************************##
#  **********  C O M M O N - D A T A B A S E -  T A S K - F U N - S C R I P T - E N D **********
#******************************************************************************************************##