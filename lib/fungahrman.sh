#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/15 dikumar fungahrman.sh
#  Purpose  : Function library for rman database operations.
#
#  SYNTAX   : genrman  #To generate rman cmdfile for rman restore
#             execrman # To execute rman restore
#             gen_controlfile_sql  # To generate controlfile sql
#             renamedb  #To rename database after rman restore
#
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  R M A N - D A T A B A S E - T A S K - F U N - S C R I P T **********
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
	if [ ! -f "${envfile}" ];
		then
		echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
		exit 1;
	else
		source "${envfile}" > /dev/null
	fi
	}

# Delete archive logs
del_archivelog()
	{
	os_user_check oracle
	source_profile "${trgdbname}"
	rman cmdfile=${etc_home}/rman/delarchive.cmd  log="${restore_log}"/delarchive"${trgdbname^^}".log  >/dev/null
	rt_stat=$?
	if [ "${rt_stat}" -gt 0 ];
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t WARNING: ARCHIVE LOGS Could not be deleted." | tee -a "${logf}"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile - ${restore_log}/delarchive${trgdbname^^}.log" | tee -a "${logf}"
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ARCHIVE LOGS deleted Successfully." | tee -a "${logf}"
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile - ${restore_log}/delarchive${trgdbname^^}.log" | tee -a "${logf}"
	fi

	}



# Function to generate RMAN CMD file for RMAN executions.
genrman()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"

	locctl="${dbctlbkploc}"
	#ctlfile=$(find "${locctl}" -type f -name "*${srcdbname}*" -printf '%T+ %p\n' | sort -r | head -n 1| cut -d' ' -f2)
	ctlfile=$(find "${locctl}" -type f -name "*${srcdbname}*" -mmin -240  -printf '%T+ %p\n' | sort -r | tail -n 1| cut -d' ' -f2)

  loc1="${dbfullbkploc}"
  loc2="${dbincrbkploc}"
  loc3="${dbarchivebkploc}"

  rm -f /tmp/catalogdbbkp.tmp > /dev/null 2>&1
  for loc in ${loc1} ${loc2} ${loc3} ;
  do
    for bkpdir in $(du -sk "${loc}"/* | awk -v m=100 '$1 > 1024*m {print $2}' )
    do
      if [ ! -f "${bkpdir}" ]; then
      echo -e "CATALOG START WITH '""${bkpdir}""'  noprompt ;" >> /tmp/catalogdbbkp.tmp
      fi
    done
  done

	rm -f /tmp/catalogarchbkp.tmp > /dev/null 2>&1
  for bkpdir in $(du -sk "${loc3}"/* | awk -v m=10 '$1 > 1024*m {print $2}' )
  do
  if [ ! -f "${bkpdir}" ]; then
  echo -e "CATALOG START WITH '"${bkpdir}"'  noprompt ;" >> /tmp/catalogarchbkp.tmp
  fi
  done

	rmancmd="${restart_dir}"/rman_${trgdbname}.cmd
  rm -f "${rmancmd}"

{
echo -e "connect target / ;"
echo -e "run  "
echo -e "{  "
echo -e "allocate channel ch1 device type DISK;"
echo -e "allocate channel ch2 device type DISK;"
echo -e "allocate channel ch3 device type DISK;"
echo -e "allocate channel ch4 device type DISK;"
echo -e "allocate channel ch5 device type DISK;"
echo -e "allocate channel ch6 device type DISK;"
echo -e "allocate channel ch7 device type DISK;"
echo -e "allocate channel ch8 device type DISK;"
echo -e "allocate channel ch9 device type DISK;"
echo -e "allocate channel ch10 device type DISK;"
echo -e "allocate channel ch11 device type DISK;"
echo -e "RESTORE CONTROLFILE FROM '${ctlfile}' ;"
echo -e "ALTER DATABASE MOUNT;"
echo -e "ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;"
cat /tmp/catalogdbbkp.tmp
echo -e "set until time \"to_date('${recover_time}', 'DD-MON-YYYY HH24:MI:SS')\"; "
echo -e "set newname for database to '${trgasmdg}'; "
echo -e "restore database; "
echo -e "switch datafile all; "
cat /tmp/catalogarchbkp.tmp
echo -e "RECOVER DATABASE DELETE ARCHIVELOG ; "
echo -e "} "
echo -e "exit "

} >> "${rmancmd}"

  rm -f /tmp/catalogarchbkp.tmp  /tmp/catalogarchbkp.tmp
  chmod 755 "${rmancmd}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tRMAN CMD file : ${rmancmd} "
	echo -e  "\n\n    ****** RMAN CMD file start ****** \n "
  cat "${rmancmd}"
  echo -e "\n    ****** RMAN CMD file end ****** \n\n"
	}

	# Execute RMAN commands : Restore
	execrman()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"

	rmanrestorelog="${restore_log}"/rmanrestore_"${trgdbname^^}".log

	nohup "${ORACLE_HOME}"/bin/rman cmdfile="${rmancmd}" log="${rmanrestorelog}" > /dev/null 2>&1 &
	#rmanpid=$!
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  RMAN RESTORE: RMAN CMD FILE : ${rmancmd}." | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  RMAN RESTORE: RMAN restore logfile : ${rmanrestorelog}." | tee -a "${logf}"
	oldfilecnt=0
	recovercnt=0
	#while ps -eaf|grep "${rmancmd}" |grep -v grep &>/dev/null; do
	while pgrep -f  "${rmancmd}" &>/dev/null; do
		sleep 1m
		echo "Y" > "${restore_statedir}"/dbrestore.run
		newfilecnt=$(grep -c 'restoring datafile' ${rmanrestorelog} )
		echo -e "${newfilecnt}" > "${restore_statedir}"/dbfilecount.run
		if [ ${recovercnt} -eq 0 ] ||  [ 10 -gt  ${recovercnt} ]; then
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  RMAN RESTORE: Status : Running     File restored: ${newfilecnt}" | tee -a "${logf}"
		fi
		if [ ${newfilecnt} -gt 0 ]; then
			if [ ${newfilecnt} -eq ${oldfilecnt} ]; then
			  (( recovercnt++ )) || true
				#let "${recovercnt}=${recovercnt}+1"
			else
			${oldfilecnt}=${newfilecnt}
			echo -e "MOUNT_RESTORE" > "${restore_statedir}"/dbstate
			echo -e "RUNNING" > "${restore_statedir}"/restorestate
			fi
		fi

		if [ ${recovercnt} -gt 10 ]; then
			echo -e "MOUNT_RECOVER" > "${restore_statedir}"/dbstate
			echo -e "RUNNING" > "${restore_statedir}"/restorestate
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S") : ${HOST_NAME}:  RMAN RESTORE: Status : Running     Recovery in progress" | tee -a "${logf}"
		fi
	done

	errcnt=$(grep -cE 'RMAN-03002|RMAN-00571|RMAN-00569|RMAN-06054|RMAN-06053|RMAN-06025|ORA-01103|ORA-01547|ORA-01194|ORA-01110' "${rmanrestorelog}" )
	if (( errcnt > 0 )); then
    	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  RMAN RESTORE:ERROR: RMAN restore script failed.  EXITING !! \n " | tee -a "${logf}"
		echo -e "FAILED" > "${restore_statedir}"/restorestate
    	exit 1
	else
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  RMAN RESTORE:RMAN restore script completed." | tee -a "${logf}"
		echo -e "COMPLETED" > "${restore_statedir}"/restorestate
		echo -e "OPEN_RECOVER" > "${restore_statedir}"/dbstate
    sleep 2
	fi

	}



	# Generate Controlfile sql to recreate controlfile.
	gen_controlfile_sql()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"

	rm -f /tmp/logfile.tmp  /tmp/logfile2.tmp > /dev/null
	rm -f /tmp/datafile.tmp /tmp/datafile2.tmp > /dev/null

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
spool /tmp/datafile.tmp
select ''''||NAME||''',' datafile from v\$datafile ;
spool off
exit
EOF

	grep "${trgdbname}" /tmp/datafile.tmp > /tmp/datafile2.tmp

	if [ ! -f "${bkpinitdir}"/logfile.txt ]; then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Logfile details not found. Control file will not be created. Exiting!! " | tee -a "${logf}"
		exit 0
	fi

	inputfile2=/tmp/datafile2.tmp
	#Removing comma from last line
	#lastline=$(tail -n 1 ${inputfile2})
	newlastline=$(tail -n 1 ${inputfile2} |sed 's/,\([^,]*\)$/ \1/' )
	sed -i  '$d' ${inputfile2} > /dev/null
	echo "${newlastline}" >> ${inputfile2}

	controlfilesql="${restart_dir}"/control"${trgdbname^^}".sql

{
echo "CREATE CONTROLFILE SET  DATABASE ${trgdbname} RESETLOGS ARCHIVELOG"
echo "    MAXLOGFILES 32 "
echo "    MAXLOGMEMBERS 5 "
echo "    MAXDATAFILES 8096 "
echo "    MAXINSTANCES 8 "
echo "    MAXLOGHISTORY 29214 "
echo "LOGFILE "
grep "GROUP" "${bkpinitdir}"/logfile.txt
echo "DATAFILE "
grep "${trgdbname}"  "${inputfile2}"
echo "CHARACTER SET AL32UTF8 ;"
} >> "${controlfilesql}"

	#cat "${controlfilesql}"

	}



	# RENAME database with creating fresh controlfile
	renamedb()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"

# If done with NID
#1. Bound DB and MOUNT.
##2. nid TARGET=/ DBNAME=ORASUP SETNAME=Y  logfile=Rename${source}_${target}.log
#3. SHUTDOWN IMMEDIATE
#   STARTUP MOUNT;
#	ALTER SYSTEM SET DB_NAME=${targetdbname} SCOPE=SPFILE;
#	SHUTDOWN IMMEDIATE
#4. STARTUP MOUNT;
#validate state
#5. ALTER DATABASE OPEN RESETLOGS;
# Validate state

# If done with creating control file
#-- Gen controlfile .
#1. Shutdown IMMEDIATE
#2. Startup NOMOUNT
#3. Change Controlfile
#   Change db_name
#4. Shutdown IMMEDIATE
#5. Startup NOMOUNT
#6. Create controlfile
#7. alter database open resetlogs

	# Validate for Mount state
	check_dbprocess "${trgdbname^^}"
	if [ "${dbprocess}" = "running" ] ;
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Database processes are running: Validated.  " | tee -a "${logf}"
			check_dbstatus "${trgdbname^^}"
		if [ "${db_state}" = "MOUNT" ] ;
			then
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Database state is ${db_state}: Validated  " | tee -a "${logf}"
		else
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Database state is ${db_state}, not compatible for Control file sql generation. EXITING !!  " | tee -a "${logf}"
			exit 1
		fi

	elif [ "${dbprocess}" = "stopped" ] ;
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Database state is DOWN, not compatible for Control file sql generation. EXITING !!" | tee -a "${logf}"
		exit 1
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Database processes status could not be validated for Control file sql generation.  " | tee -a "${logf}"
	fi

	# Generate control file sql from MOUNT database
	gen_controlfile_sql

	if [ ! -f "${controlfilesql}" ];
	then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME:ERROR: Control file creation sql file ${controlfilesql} not found.\n"  | tee -a  "${logf}"
		exit 1;
	fi
	sleep 2

sqlplus '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
spool ${restore_log}/spool_runcontrolfilesql${trgdbname^^}.log
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT ;
ALTER SYSTEM SET control_files='${trgasmpath}/CONTROLFILE/cntrl00${startdate}.dbf','${trgasmpath}/ONLINELOG/cntrl00${startdate}.dbf' scope=spfile;
ALTER SYSTEM SET DB_NAME=${trgdbname^^} SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT ;
@${controlfilesql}
ALTER DATABASE OPEN RESETLOGS;
spool off
exit
EOF

	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  DB RENAME: Logfile - ${restore_log}/spool_runcontrolfilesql${trgdbname^^}.log"  | tee -a  "${logf}"
	# Validate for OPEN state
	check_dbprocess "${trgdbname^^}"
	if [ "${dbprocess}" = "running" ] ;
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  POST DB OPEN : Database processes are running: Validated.  " | tee -a "${logf}"
			check_dbstatus "${trgdbname^^}"
		if [ "${db_state}" = "OPEN" ] ;
			then
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  POST DB OPEN : Database state is ${db_state}: Validated  " | tee -a "${logf}"
		else
			echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  POST DB OPEN : ERROR: Database state is ${db_state}. Check errors. EXITING !!  " | tee -a "${logf}"
			exit 1
		fi

	elif [ "${dbprocess}" = "stopped" ] ;
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  POST DB OPEN : ERROR: Database state is DOWN. EXITING !!" | tee -a "${logf}"
		exit 1

	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  POST DB OPEN : ERROR: Database processes status could not be validated.  " | tee -a "${logf}"
	fi
	}


##******************************************************************************************************##
#  **********  R M A N - D A T A B A S E - T A S K - F U N - S C R I P T - E N D **********
#********************************************************************************************************##