db_ready()
{
source_profile ${dbupper}
check_dbname ${dbupper}

check_dbprocess ${dbupper}
if [ ${dbprocess} = "running" ] ;  then
	${ECHO} " DB VALIDATE: Database processes are running: Validated.  " | tee -a "${logf}"
	check_dbstatus ${dbupper}
	if [ ${db_state} = "NOMOUNT" ] ; then
		${ECHO} " DB VALIDATE: Database state is ${db_state}: Need validation  " | tee -a "${logf}"
		${ECHO} " DB VALIDATE: STOPPING DATABASE for Validation.  " | tee -a "${logf}"
		stopdb_sqlplus ${dbupper}
		${ECHO} " DB VALIDATE: Checking DATABASE STARTUP for state validation.  " | tee -a "${logf}"
		check_startdb_sqlplus ${dbupper}
		if [ ${db_state} = "NOMOUNT" ] ; then
			${ECHO} " DB VALIDATE: Database state is ${db_state}: Validated  " | tee -a "${logf}"
			${ECHO} " DB VALIDATE: STOPPING DATABASE.  " | tee -a "${logf}"
			stopdb_sqlplus ${dbupper}
				
		elif [ ${db_state} = "OPEN" ] || [ ${db_state} = "MOUNT" ] ;  then
			${ECHO} " DB VALIDATE: Database state is ${db_state}: Validated.  " | tee -a "${logf}"
			${ECHO} " DB VALIDATE: Deleting ARCHIVE LOGS.  " | tee -a "${logf}"
			del_archivelog ${dbupper}
			${ECHO} " DB VALIDATE: Executing DROP database. " | tee -a "${logf}"
			dropdb ${dbupper}
			#Backup spfile as it is deleted with DROP DATABASE
			cp  ${bkpinitdir}/spfile${ORACLE_SID}.ora     ${ORACLE_HOME}/dbs/.	
		fi
			
	elif [ ${db_state} = "OPEN" ] || [ ${db_state} = "MOUNT" ] ;  then
		${ECHO} " DB VALIDATE: Database state is ${db_state}: Validated.  " | tee -a "${logf}"
		${ECHO} " DB VALIDATE: Deleting ARCHIVE LOGS.  " | tee -a "${logf}"
		del_archivelog ${dbupper}
		${ECHO} " DB VALIDATE: Executing DROP database. " | tee -a "${logf}"
		dropdb ${dbupper}
		#Backup spfile as it is deleted with DROP DATABASE
		cp  ${bkpinitdir}/spfile${ORACLE_SID}.ora     ${ORACLE_HOME}/dbs/.
	fi

elif [ ${dbprocess} = "stopped" ] ;  then
	${ECHO} " DB VALIDATE: Database processes are stopped: Validated.  " | tee -a "${logf}"
	${ECHO} " DB VALIDATE: Checking database startup. " | tee -a "${logf}"
	check_startdb_sqlplus ${dbupper}
	if [ ${db_state} = "OPEN" ] || [ ${db_state} = "MOUNT" ] ;  then
		${ECHO} " DB VALIDATE: Database state is ${db_state}: Validated.  " | tee -a "${logf}"
		${ECHO} " DB VALIDATE: Deleting ARCHIVE LOGS.  " | tee -a "${logf}"
		del_archivelog ${dbupper}
		#Backup spfile as it is deleted with DROP DATABASE
		cp  ${bkpinitdir}/init/spfile${ORACLE_SID}.ora     ${ORACLE_HOME}/dbs/.
		${ECHO} " DB VALIDATE: Executing DROP database. " | tee -a "${logf}"
		dropdb ${dbupper}
		#Backup spfile as it is deleted with DROP DATABASE
		cp  ${bkpinitdir}/spfile${ORACLE_SID}.ora     ${ORACLE_HOME}/dbs/.

	elif [ ${db_state} = "NOMOUNT" ] ;  then
		${ECHO} " DB VALIDATE: Database state is ${db_state}: Validated.  " | tee -a "${logf}"
		${ECHO} " DB VALIDATE: STOPPING DATABASE.  " | tee -a "${logf}"
		stopdb_sqlplus ${dbupper}
	fi

else 
	${ECHO} " DB VALIDATE: Database processes status could not be validated.  " | tee -a "${logf}"
fi


#1. Db running normal --> Bounce and start MOUNT Exclusive and DROP, then start with pfile 
##2. DB is in mount state --> Bounce and start MOUNT exclusive and DROP, then start with pfile 
#3. DB is down   --> Bounce and start with pfile 
#4. DB is in NOMOUNT --> STOP and start with pfile 
	
#Start instance in NOMOUNT
${ECHO} "Starting database in NOMOUNT for restore." | tee -a "${logf}"
startdb_restore ${dbupper}
rt_code=$?
if [ "${rt_code}" -gt 0 ];  then
	${ECHO} " DB VALIDATE: ERROR: Database could not be started in NOMOUNT.EXITING !!\n" | tee -a "${logf}"
	exit 1
fi
unset rt_stat

${ECHO} "***** dbready task is completed   *****"  | tee -a "${logf}"
}
