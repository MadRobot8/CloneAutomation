
#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/17 dikumar funlibdb.sh
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
#******************************************************************************************************
#
#  **********   D A T A B A S E - F U N C T I O N - L I B R A R Y - S C R I P T - **********
#
#******************************************************************************************************

#******************************************************************************************************
#
#	Local variable declaration.
#******************************************************************************************************

HOST_NAME=$(uname -n | cut -f1 -d".")

#******************************************************************************************************##
#
#  Library functions list
#	os_user_check   oracle			: To validate current os user
#	source_profile  dbname			: To source profile file for DB
#	check_dbname 	dbname			: To validate given database name with current environment
#	check_dbprocess dbname			: Check running database process at OS level
#	check_dbstatus  dbname			: Check database state- OPEN, MOUNT, NOMOUNT, DOWN
#	startdb_sqlplus dbname mode		: Start database from sqlplus
#	abortdb 		dbname			: Stop abort database from sqlplus
#	stopdb_sqlplus 	dbname			: Stop immediate database from sqlplus
#	dropdb			dbname 			: Drop database from sqlplus
#
#******************************************************************************************************##
	
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
	



	cleanup_trace()
	{
	dbupper=${1^^}
	
	os_user_check oracle 
	source_profile ${dbupper}

	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Cleaning up old trace and log files for Database." | tee -a "${logf}"
	adrci exec="purge -age 0 -type alert "
	adrci exec="purge -age 0 -type incident "
	adrci exec="purge -age 0 -type trace "
	adrci exec="purge -age 0 -type cdump "
	adrci exec="purge -age 0 -type hm "
	adrci exec="purge -age 0 -type utscdmp "
	
	rm /tmp/adump${ORACLE_SID}.tmp 
	
sqlplus -s '/ as sysdba'  << EOF > /dev/null
set heading off
set echo off
set timing off
set time off
set feedback 0
set verify OFF
spool /tmp/adump${ORACLE_SID}.tmp
select value from v\$parameter where name='audit_file_dest';
spool off
exit
EOF
	check_stat=`cat /tmp/adump${ORACLE_SID}.tmp | tr -d [:space:]`
	cd ${check_stat}/..
	
	if [ -d adump ];
	then
		echo "adump directory found !!" >> "${logf}"
		mv adump adump.rm
		mkdir adump
		rm -fr adump.rm
	fi 
	echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:  \t\t Cleanup up old trace and log files completed." | tee -a "${logf}"
	}


restore_db_oh()
{
	
		bkpfile=${dbtargethomepath}/../${dbhome_bkp_file}
	stat_value="$(< ${restore_statedir}/2copydbhomebkp.crm)"
	if [ -f ${bkpfile} ];
		then
		echo -e "Oracle Home Backup file Already copied."  | tee -a  "${logf}"
		
	elif [ ${stat_value} = 'F' ];
	then 
	
		bkpfile=${dbhome_bkp_loc}/${dbhome_bkp_file}
		if [ ! -f ${bkpfile} ];
		then
			echo -e  "ERROR: Oracle Home Backup file not found.\n"  | tee -a  "${logf}"
			echo "F" > ${restore_statedir}/1locatedbhomebkp.crm
			exit 1;
		else
			echo -e  "Oracle Home Backup file found as ${dbhome_bkp_loc}/${dbhome_bkp_file} "  | tee -a  "${logf}"
			echo "Y" > ${restore_statedir}/1locatedbhomebkp.crm
			stat_value='Y'
			sleep 2				 
			echo -e "Copying Oracle Home Backup."  | tee -a  "${logf}"
			cp ${dbhome_bkp_loc}/${dbhome_bkp_file} ${dbtargethomepath}/../.
			rcode=$?
			if (( ${rcode} > 0 )); then
				echo -e "ERROR: Oracle Home backup file copy failed.  EXITING !! \n " | tee -a "${logf}"
				echo "F" > ${restore_statedir}/2copydbhomebkp.crm
				exit 1
			else 
				echo -e "Oracle Home backup copy completed successfully." | tee -a "${logf}"
				echo "Y" > ${restore_statedir}/2copydbhomebkp.crm
				stat_value='Y'
				sleep 2
			fi
		fi
	fi
	
}

rename_pdb()
{

srcpdb='GAHPRD'
srccdb='GAHCDB'
trgpdb='CLONEDB'
trgcdb='CLONECDB'
asmdbfdg='+DATHCX7'


sqlplus -s '/ as sysdba'  << EOF > /dev/null
set echo on
set time on
spool /tmp/renamepdb$"{trgpdb}".log
alter tablespace temp add tempfile '${asmdbfdg}' size 30g ;
alter pluggable database ${srcpdb} close;
alter pluggable database ${srcpdb} unplug into '$ORACLE_HOME/dbs/${srcpdb}_unplug.xml';
drop pluggable database ${srcpdb}  ;
create pluggable database ${trgpdb} using '$ORACLE_HOME/dbs/${srcpdb}_unplug.xml' NOCOPY SERVICE_NAME_CONVERT=('ebs_${srcpdb}','ebs_${trgpdb}');
alter pluggable database ${trgpdb} open read write;
alter pluggable database all save state instances=all;
show pdbs
alter session set container=${trgpdb} ;
alter tablespace temp1 add tempfile '${asmdbfdg}' size 30g ;
alter tablespace temp1 add tempfile '${asmdbfdg}' size 30g ;
alter tablespace temp2 add tempfile '${asmdbfdg}' size 30g ;
alter tablespace temp2 add tempfile '${asmdbfdg}' size 30g ;
spool off
exit
EOF

}

create_service()
{
srcpdb='GAHPRD'
srccdb='GAHCDB'
trgpdb='CLONEDB'
trgcdb='CLONECDB'
asmdbfdg='+DATHCX7'

sqlplus -s '/ as sysdba'  << EOF > /dev/null
set echo on
set time on
set lines 200
set pages 200
col NAME for a50
col NETWORK_NAME for a50
spool /tmp/createservice$"{trgpdb}".log
show pdbs
select name, SERVICE_ID, NETWORK_NAME, CREATION_DATE ,AQ_HA_NOTIFICATIONS from dba_services order by 2  ;
exec dbms_service.stop_service('GAHCPRD') ;
exec dbms_service.stop_service('GAHCPRDXDB') ;
exec dbms_service.stop_service('GAHCPRD.sea.corp.expecn.com') ;
exec dbms_service.stop_service('GAHCPRD_CFG') ;
exec dbms_service.delete_service('GAHCPRD') ;
exec dbms_service.delete_service('GAHCPRDXDB') ;
exec dbms_service.delete_service('GAHCPRD.sea.corp.expecn.com') ;
exec dbms_service.delete_service('GAHCPRD_CFG') ;

exec DBMS_SERVICE.create_service('${trgpdb}.karmalab.net','${trgpdb}.karmalab.net');
exec DBMS_SERVICE.start_service('${trgpdb}.karmalab.net') ;

select name, SERVICE_ID, NETWORK_NAME, CREATION_DATE ,AQ_HA_NOTIFICATIONS from dba_services order by 2  ;
alter session set container=${trgpdb} ;
select name, SERVICE_ID, NETWORK_NAME, CREATION_DATE ,AQ_HA_NOTIFICATIONS from dba_services order by 2  ;
exec DBMS_SERVICE.create_service('${trgpdb}','${trgpdb}');
exec DBMS_SERVICE.create_service('ebs_${trgpdb}','ebs_${trgpdb}');
exec DBMS_SERVICE.create_service('KARMALAB.NET','KARMALAB.NET');
exec DBMS_SERVICE.create_service('SYS$APPLSYS.WF_CONTROL.${trgpdb}.KARMALAB.NET','SYS$APPLSYS.WF_CONTROL.${trgpdb}.KARMALAB.NET');
exec DBMS_SERVICE.create_service('ebs_patch','ebs_patch');
exec DBMS_SERVICE.create_service('${trgpdb}_ebs_patch','${trgpdb}_ebs_patch');

exec DBMS_SERVICE.start_service('${trgpdb}');
exec DBMS_SERVICE.start_service('ebs_${trgpdb}');
exec DBMS_SERVICE.start_service('KARMALAB.NET');
exec DBMS_SERVICE.start_service('SYS$APPLSYS.WF_CONTROL.${trgpdb}.KARMALAB.NET');
exec DBMS_SERVICE.start_service('ebs_patch');
exec DBMS_SERVICE.start_service('${trgpdb}_ebs_patch');
select name, SERVICE_ID, NETWORK_NAME, CREATION_DATE ,AQ_HA_NOTIFICATIONS from dba_services order by 2  ;
spool off
exit
EOF

}

#******************************************************************************************************
#
#  **********   D A T A B A S E - F U N C T I O N - L I B R A R Y - S C R I P T - E N D **********
#
#******************************************************************************************************