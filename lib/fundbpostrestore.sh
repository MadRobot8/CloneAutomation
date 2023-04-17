#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/17 dikumar fundbpostrestore.sh
#  Purpose  : Function library for post database restore operations.
#  SYNTAX   : add_tempfile          # To add temp files to restored database.
#             run_sys_updates       # To run SYS based sql statements.
#             create_password_file  # To create fresh password file.
#             run_db_autoconfig     # To run autoconfig on database node.
#             run_apps_db_updates   # To run apps sql statements on database node.
#             run_db_etcc           # To run etcc on current database node.
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  P O S T - D A T A B A S E - R E S T O R E -  T A S K - F U N - S C R I P T **********
#******************************************************************************************************##
HOST_NAME=$(uname -n | cut -f1 -d".")

	# Add tempfiles to temporary tablespace
add_tempfile()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	cd "${restore_log}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile  ${restore_log}/spool_addtempfile${trgdbname^^}.${startdate} " | tee -a "${logf}"
sqlplus '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
spool ${restore_log}/spool_addtempfile${trgdbname^^}.${startdate}
@${uploadsqldir}/add_tempfiles.sql
spool off
exit
EOF

	rt_stat=$?
	if [ "${rt_stat}" -gt 0 ];
		then
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tERROR: TEMP files could not be added. Please check errors. EXITING !!\n" | tee -a "${logf}"
	else
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\tTEMP files added Successfully." | tee -a "${logf}"
	fi
	unset rt_stat
	sleep 2
}


# Run SYS updates for system
run_sys_updates()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile  ${restore_log}/spool_sys_update${trgdbname^^}.${startdate} " | tee -a "${logf}"

  load_getpass_password

sqlplus '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
SET TIMING ON ;
spool ${restore_log}/spool_sys_update${trgdbname^^}.${startdate}
alter user sys identified by ${SYSTPASS} ;
alter user system identified by ${SYSTPASS} ;
alter user sappreaduser identified by ${VSAPPREADPASS};
alter user sappwriteuser identified by ${VSAPPWRITEPASS};
alter user S_EGDPDMS identified by Op3nMau1is92lin89;
alter user DBRO account unlock;
alter user DBRO identified by oracle123;
alter user EUL_US identified by Oracle2014;
alter user "S-HYPEDW" identified by Svcac4hyp;
alter user "S_OAS_EDW" identified by oramau1edw;
alter user "S_AFF_EDW" identified by saffedw123;
alter user "S-APPMDM"  identified by Svc4appmdm;
alter user "S-OBIETL" identified by Svc4obietl;
alter user "S-CYCLOTRON" identified by Svc4cyl0;
alter user sqltxplain identified by sqlt;
grant OEM_MONITOR to DBRO;
alter user dbsnmp identified by dbsnmp;
alter profile SERVICE_EXPD limit PASSWORD_REUSE_MAX UNLIMITED;
alter system set "_report_capture_cycle_time"=0 scope=both sid='*';
alter system set optimizer_index_cost_adj=100 scope=both sid='*';
alter system set optimizer_index_caching=0 scope=both sid='*';
alter system set plsql_code_type=NATIVE scope=both sid='*';
alter system set local_listener='${trgdbname^^}_LOCAL' scope=BOTH SID='*' ;
alter system set remote_listener='${trgdbname^^}_REMOTE' scope=BOTH SID='*' ;
alter system set service_names='${trgdbname^^},SYS$APPLSYS.WF_CONTROL.${trgdbname^^}.KARMALAB.NET,${trgdbname^^}_ebs_patch,ebs_patch' scope=BOTH SID='*' ;
purge dba_recyclebin;
@${uploadsqldir}/db_recreate_dba_directories.sql
spool off
exit
EOF

	#Bounce database for consistency
	bouncedb
	#Bounce listener
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Bouncing Database listener on $HOST_NAME " | tee -a "${logf}"
	"${ORACLE_HOME}"/bin/lsnrctl reload "${trgdbname^^}"  >> "${logf}"
  "${ORACLE_HOME}"/bin/lsnrctl status "${trgdbname^^}"  >> "${logf}"

	nohup "${ORACLE_HOME}"/bin/sqlplus '/ as sysdba' @"${common_sql}"/gg_sysupdate.sql > "${restore_log}"/spool_ggatesql"${trgdbname^^}"."${startdate}"  2>&1 &

	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Password for SYS,SYSTEM,DBRO changed successfully. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Password for SAPPREADUSER,SAPPWRITEUSER changed successfully. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ${trgdbname^^} service names updated successfully. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t DBA RECYCLEBIN PURGED. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t DBA directories created. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Golden Gate Scripts started in nohup. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile ${restore_log}/spool_ggatesql${trgdbname^^}.${startdate} " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t SYS update steps completed. " | tee -a "${logf}"

	}

gah_sys_updates()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile  ${restore_log}/spool_sys_update${trgdbname^^}.${startdate} " | tee -a "${logf}"

  load_getpass_password

sqlplus '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
SET TIMING ON ;
spool ${restore_log}/spool_sys_update${trgdbname^^}.${startdate}
alter user sys identified by ${SYSTPASS} ;
alter user system identified by ${SYSTPASS} ;
alter user sqltxplain identified by sqlt;
alter user dbsnmp identified by dbsnmp;
alter profile SERVICE_EXPD limit PASSWORD_REUSE_MAX UNLIMITED;
alter system set local_listener='${trgdbname^^}_LOCAL' scope=BOTH SID='*' ;
alter system set remote_listener='${trgdbname^^}_REMOTE' scope=BOTH SID='*' ;
alter system set service_names='${trgdbname^^},SYS$APPLSYS.WF_CONTROL.${trgdbname^^}.KARMALAB.NET,${trgdbname^^}_ebs_patch,ebs_patch' scope=BOTH SID='*' ;
purge dba_recyclebin;
@${uploadsqldir}/db_recreate_dba_directories.sql
spool off
exit
EOF

	#Bounce database for consistency
	bouncedb
	#Bounce listener
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Bouncing Database listener on $HOST_NAME " | tee -a "${logf}"
	"${ORACLE_HOME}"/bin/lsnrctl reload "${trgdbname^^}"  >> "${logf}"
  "${ORACLE_HOME}"/bin/lsnrctl status "${trgdbname^^}"  >> "${logf}"

	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Password for SYS,SYSTEM changed successfully. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ${trgdbname^^} service names updated successfully. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t DBA RECYCLEBIN PURGED. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t DBA directories created. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile ${restore_log}/spool_ggatesql${trgdbname^^}.${startdate} " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t SYS update steps completed. " | tee -a "${logf}"

	}

	# create password file for database
	create_password_file()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	cd "${ORACLE_HOME}"/dbs/ || return
	passwordfile="${ORACLE_HOME}"/dbs/orapw"${ORACLE_SID}"
	if [ ! -f "${passwordfile}" ];
	then
		rm -f "${passwordfile}"
		"${ORACLE_HOME}"/bin/orapwd file=orapw"${ORACLE_SID}"  password="${SYSTPASS}"  > /dev/null 2>&1
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ${ORACLE_SID} password file created successfully. " | tee -a "${logf}"
	else
		"${ORACLE_HOME}"/bin/orapwd file=orapw${ORACLE_SID}  password="${SYSTPASS}" > /dev/null 2>&1
		echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t ${ORACLE_SID} password file created successfully. " | tee -a "${logf}"
		sleep 2
	fi
	}


	# Run database node autoconfig
	run_db_autoconfig()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"

	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Running autoconfig on db node ${trgdbhost} " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t Logfile  ${restore_log}/db_autoconfig${trgdbname^^}.${startdate} " | tee -a "${logf}"
	sh "${ORACLE_HOME}"/appsutil/scripts/"${CONTEXT_NAME}"/adautocfg.sh  appspass="${workappspass}"  > "${restore_log}"/db_autoconfig"${trgdbname^^}"."${startdate}"
	rcode=$?
	if (( rcode > 0 )); then
    	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  WARNING: Database autoconfig failed on db node ${trgdbhost}. Check error. " | tee -a "${logf}"
	else
    	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Database autoconfig completed successfully on db node ${trgdbhost}. " | tee -a "${logf}"
    	sleep 2
	fi


	}


	# Running apps based sql from database
run_apps_db_updates()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Apps sql statements - Started " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile  ${restore_log}/spool_apps_dbnodeupdate${trgdbname^^}.${startdate} " | tee -a "${logf}"

sqlplus  apps/"${workappspass}"@"${trgdbname^^}"  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
SET TIMING ON ;
spool ${restore_log}/spool_apps_dbnodeupdate${trgdbname^^}."${startdate}"
@${common_sql}/apps_update.sql
@${common_sql}/apps_update${trgdbname^^}.sql
spool off
exit
EOF

	# Running database autoconfig.
	#run_db_autoconfig
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Running apps scrambling sql in nohup. " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t Logfile  ${restore_log}/spool_scramble_${trgdbname^^}.${startdate} " | tee -a "${logf}"
	nohup "${ORACLE_HOME}"/bin/sqlplus  apps/"${workappspass}" @"${common_sql}"/Scramble_main.sql > "${restore_log}"/spool_scramble_"${trgdbname^^}"."${startdate}" 2> /dev/null  &

	sleep 2
	}

# For GAH instances only
gah_apps_db_updates()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Apps sql statements - Started " | tee -a "${logf}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Logfile  ${restore_log}/spool_apps_dbnodeupdate${trgdbname^^}.${startdate} " | tee -a "${logf}"

sqlplus  apps/"${workappspass}"@"${trgdbname^^}"  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
SET TIMING ON ;
spool ${restore_log}/spool_apps_dbnodeupdate${trgdbname^^}.${startdate}
@${common_sql}/gah_apps_update.sql
@${common_sql}/gah_apps_update${trgdbname^^}.sql
spool off
exit
EOF
  echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  Apps sql statements - Completed " | tee -a "${logf}"
	sleep 2
	}



	# Running db node ETCC from database node
run_db_etcc()
	{
	os_user_check oracle
	source_profile "${trgdbname^^}"
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t Logfile  ${restore_log}/dbnode_etcc_${trgdbname^^}.${startdate} " | tee -a "${logf}"
	sh "${etc_home}"/etcc/checkDBpatch.sh  > "${restore_log}"/dbnode_etcc_"${trgdbname^^}"."${startdate}" 2> /dev/null  &
	sleep 2
	}



##******************************************************************************************************##
#  **********  P O S T - D A T A B A S E - R E S T O R E -  T A S K - F U N - S C R I P T **********
#********************************************************************************************************##