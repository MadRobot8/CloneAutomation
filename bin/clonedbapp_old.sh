#!/bin/bash
#******************************************************************************************************
# 	$Header 1.2 2022/07/29 dikumar $
#  Purpose  : Script will run application extraction, restore, configuration steps.
#
#  SYNTAX   : sh <instance name>.sh
#             sh orasupapp.sh
#
#  Author   : Dinesh Kumar
#  Synopsis : This script will perform following operations
#
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#
#******************************************************************************************************#

#******************************************************************************************************##
#
#  ********** A P P L I C A T I O N - I N S T A N C E - R E S T O R E - W R A P P E R - S C R I P T **********
#
#******************************************************************************************************##
#******************************************************************************************************##
##	Capture and decode input variables.
#   time_flag = Database recovery time string.
#   source_flag = Source database name, if it is not default source which is set to Production.
#   restart_flag = If you want to restart the last session instead of executing a fresh session.
#******************************************************************************************************##
export dbupper="CLONEDB"
export dblower=${dbupper,,}
export HOST_NAME=$(uname -n | cut -f1 -d".")

#******************************************************************************************************##
#	Local variable declaration.
#******************************************************************************************************##
export scr_home=/u05/oracle/autoclone
# Setup oem node log dir for oem node local logs
mkdir -p "${scr_home}"/instance/"${dbupper}"/lock > /dev/null 2>&1
export lock_dir="${scr_home}"/instance/"${dbupper}"/lock
sleep 1
if [ -f "${lock_dir}"/"${dblower}"app.lck ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Lock file exists for application script, another session is still running.\n\n"
  exit 1
fi

#******************************************************************************************************##
##	Source instance properties file
#******************************************************************************************************##

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [ ! -f ${envfile} ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="${clonerspfile}"
if [ ! -f "${envfile}" ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: clone.rsp file is not available on application node. Exiting!!\n"
    exit 1;
else
    source "${clonerspfile}"
    sleep 1
fi
unset envfile

#******************************************************************************************************##
##	Clone rsp fun
#******************************************************************************************************##
update_clonersp()
{
  keyrsp="${1}"
  valuersp="${2}"
  sed -i "/${keyrsp}/d" "${clonerspfile}"
  echo -e  "export ${keyrsp}=${valuersp}"  >> "${clonerspfile}"
  source "${clonerspfile}" >/dev/null 2>&1
}
#******************************************************************************************************##
## Application functions
#******************************************************************************************************##
check_connect()
{
source /home/$(whoami)/."${trgappname,,}"_profile >/dev/null 2>&1

export APPSUSER=$(/dba/bin/getpass "${trgappname}" apps)
export APPSCONNECTSTR="${APPSUSER}"@"${trgappname}"

unpw="${APPSUSER}"@"${trgappname^^}"
sqlplus /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
    return 1
else
   return 0
fi
}


# Check for both CDB and PDB status
check_dbstatus()
{
source /home/$(whoami)/."${trgappname,,}"_profile >/dev/null 2>&1

export APPSUSER=$(/dba/bin/getpass "${trgappname}" apps)
export APPSCONNECTSTR="${APPSUSER}"@"${trgappname}"


if check_connect ; then
  pstatus="UNKNOWN"
else
sqlplus /nolog > /dev/null 2>&1 <<EOF
CONNECT ${APPSUSER}
spool /tmp/pdbstatus${trgappname^^}.tmp
set head off
set feedback off
set pagesize 0
select open_mode from v\$pdbs;
exit;
EOF

pstatus=$(cat /tmp/pdbstatus"${trgappname^^}".tmp )
fi

case "$pstatus" in
    *MOUNT*)       export pdbstatus="MOUNT" ;;
    *WRITE*)       export pdbstatus="OPEN"
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS : PDB is open. " | tee -a "${mainlog}"
            ;;
    *READ*ONLY*)   export pdbstatus="READ_ONLY" ;;
    *UNKNOWN*)       export pdbstatus="UNREACHABLE" ;;
    *)      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS : Could not determine database status. " | tee -a "${mainlog}"
      ;;
esac

rm -f /tmp/pdbstatus${dbupper^^}.tmp >/dev/null 2>&1
}

create_extract_dir()
{
  mkdir  -p  "${currentextractdir}"/app_fnd_user  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/app_fnd_lookup  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs1/tns  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/tns  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs1/ctx  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/ctx  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs1/env  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/env  > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs1/app_others > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/app_others > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/fs1/pairs > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/pairs  > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/fs1/ssl > /dev/null 2>&1
  mkdir  -p  "${currentextractdir}"/fs2/ssl  > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/fs1/wls  > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/fs2/wls  > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/app_others/wallet/fmw > /dev/null  2>&1
	mkdir  -p  "${currentextractdir}"/app_others/wallet/java > /dev/null 2>&1
	mkdir  -p  "${currentextractdir}"/app_others/dbc > /dev/null 2>&1
	mkdir  -p  "${uploaddir}"/fnd_lookups > /dev/null 2>&1
	mkdir  -p  "${uploaddir}"/fnd_users > /dev/null 2>&1
	mkdir  -p  "${uploaddir}"/sql > /dev/null 2>&1

	chmod -R 777   "${currentextractdir}"  "${uploaddir}" > /dev/null 2>&1
}


extract_lookup_users()
{
  export APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
  export APPSPASS=$(echo "${APPUSER}" | cut -d/ -f 2)

  check_dbstatus

if [[ "${pdbstatus}" == "OPEN"  && -z "${appsqlextract}"  ]] ; then

sqlplus -s "${APPSUSER}"@"${trgappname^^}"  << EOF > /dev/null
set head off
set feed off
set line 999

spool ${currentextractdir}/app_fnd_lookup/app_extract_fndlookup.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile  > /dev/null' from dual;
select 'FNDLOAD $APPUSER O Y DOWNLOAD '||'$'||'FND_TOP/patch/115/import/aflvmlu.lct ${uploaddir}/fnd_lookups/'||lookup_type||'.ldt FND_LOOKUP_TYPE APPLICATION_SHORT_NAME=''XXEXPD'' LOOKUP_TYPE='''||lookup_type||'''' from fnd_lookup_values where lookup_type in ('EXPD_BASE_PATH_LOOKUP','EXPD_FILE_RENAME_PATH','EXPD_EXTENDED_PATH_LOOKUP','EXPD_WS_URL','EXPD_SOA_INSTANCE_LOOKUP','EXPD_TXBRIDGE_OAUTH_CREDS_LKP','EXPD_TXBRIDGE_INSTANCE_LOOKUP','EXPD_AWS_S3_BUKCETS_LKP') group by lookup_type;
select ' rm -f "${currentextractdir}"/app_fnd_lookup/L*.log ' from dual;
spool off
spool ${uploaddir}/fnd_lookups/app_upload_fndlookup.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile > /dev/null' from dual;
select 'FNDLOAD $APPUSER O Y UPLOAD '||'$'||'FND_TOP/patch/115/import/aflvmlu.lct ${uploaddir}/fnd_lookups/'||lookup_type||'.ldt'  from fnd_lookup_values where lookup_type in ('EXPD_BASE_PATH_LOOKUP','EXPD_FILE_RENAME_PATH','EXPD_EXTENDED_PATH_LOOKUP','EXPD_WS_URL','EXPD_SOA_INSTANCE_LOOKUP','EXPD_TXBRIDGE_OAUTH_CREDS_LKP','EXPD_TXBRIDGE_INSTANCE_LOOKUP','EXPD_AWS_S3_BUKCETS_LKP') group by lookup_type;
select ' rm -f "${currentextractdir}"/app_fnd_lookup/L*.log ' from dual;
select ' rm -f ${uploaddir}/fnd_lookups/L*.log ' from dual;
spool off

spool ${currentextractdir}/app_fnd_user/app_extract_fnd_user.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile > /dev/null' from dual;
select 'FNDLOAD $APPUSER 0 Y DOWNLOAD '||'$'||'FND_TOP/patch/115/import/afscursp.lct ${uploaddir}/fnd_users/'||USER_NAME||'.ldt FND_USER USER_NAME='''||USER_NAME||''' ' from fnd_user where last_logon_date >= sysdate-900 or trunc(creation_date)=trunc(sysdate);
select ' rm -f "${currentextractdir}"/L*.log ' from dual;
select ' rm -f ${uploaddir}/fnd_users/L*.log ' from dual;
select ' rm -f ${log_dir}/L*.log ' from dual;
spool off
spool ${uploaddir}/fnd_users/app_upload_fnd_user.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile  > /dev/null' from dual;
select 'FNDLOAD $APPUSER 0 Y UPLOAD '||'$'||'FND_TOP/patch/115/import/afscursp.lct ${uploaddir}/fnd_users/'||USER_NAME||'.ldt  ' from fnd_user where last_logon_date >= sysdate-900 or trunc(creation_date)=trunc(sysdate);
select ' rm -f "${currentextractdir}"/app_fnd_lookup/L*.log ' from dual;
select ' rm -f ${uploaddir}/fnd_users/L*.log ' from dual;
select ' rm -f ${log_dir}/L*.log ' from dual;
spool off

exit
EOF

chmod -R 777 "${extractdir}" > /dev/null 2>&1
chmod -R 777 "${uploaddir}" > /dev/null 2>&1
chmod -R 777 "${TNS_ADMIN}" > /dev/null 2>&1

  cd "${log_dir}"

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: *****   Executing FND Lookup Extracts...   *****" | tee -a "${appextractlog}" "${mainlog}"
  sh  "${currentextractdir}"/app_fnd_lookup/app_extract_fndlookup.sh  > "${log_dir}"/extract_lookup"${dbupper^^}".log  2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: *****   Executing FND User Extracts...   *****"  | tee -a "${appextractlog}"  "${mainlog}"
  sh "${currentextractdir}"/app_fnd_user/app_extract_fnd_user.sh   >  "${log_dir}"/extract_users"${dbupper^^}".log  2>&1

  rm -f L*.log "${log_dir}"/L*.log 2>&1
  update_clonersp "appsqlextract" "COMPLETED"
else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: Application database extraction is skipped. " | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "appsqlextract" "PASS"
fi
}

extract_file_backup()
{
if [ -z "${appfileextract}"  ] ; then
  log_dir="${extractlogdir}"
  chmod -R 777 "${extractdir}" > /dev/null 2>&1
  chmod -R 777 "${uploaddir}" > /dev/null 2>&1
  chmod -R 777 "${TNS_ADMIN}" > /dev/null 2>&1

#***************************************************************************************************###
#  Backup important files, to be restored as post clone process
#***************************************************************************************************###

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: Extracting TNS, CONTEXT, ENV, Certs files from Application node.   *****"  | tee -a "${appextractlog}" "${mainlog}"
	chmod 775 "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin > /dev/null 2>&1
  cp   -p "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin/*.*  "${currentextractdir}"/fs2/tns/.  > /dev/null 2>&1
	chmod 775 "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin  > /dev/null 2>&1
  cp   -p "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin/*.*  "${currentextractdir}"/fs1/tns/.  > /dev/null 2>&1

  cp   -p  "${FMW_HOME}"/webtier/instances/EBS_web_OHS1/config/OPMN/opmn/wallet/cwallet.sso "${currentextractdir}"/app_others/wallet/fmw/.   > /dev/null 2>&1
  cp   -p  "${FMW_HOME}"/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/proxy-wallet/cwallet.sso "${currentextractdir}"/app_others/wallet/fmw/.   > /dev/null 2>&1
  cp   -p  "${FMW_HOME}"/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/keystores/default/cwallet.sso "${currentextractdir}"/app_others/wallet/fmw/.  > /dev/null 2>&1
	cp -p "${OA_JRE_TOP}"/lib/security/cacerts "${currentextractdir}"/app_others/wallet/java/.  > /dev/null 2>&1
	cp -p "${OA_JRE_TOP}"/lib/security/../../../../jdk64/jre/lib/security/cacerts "${currentextractdir}"/app_others/wallet/java/.  > /dev/null 2>&1
	cp -pr "${apptargetbasepath}"/ibywallet  "${currentextractdir}"/app_others/wallet/.  > /dev/null 2>&1

  cp  -p  "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.xml "${currentextractdir}"/fs2/ctx/. > /dev/null 2>&1
	cp  -p "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.xml  "${currentextractdir}"/fs1/ctx/. > /dev/null 2>&1
	cp  -p  "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.env "${currentextractdir}"/fs2/env/. > /dev/null 2>&1
  cp  -p "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.env  "${currentextractdir}"/fs1/env/.  > /dev/null 2>&1

	cp  -p "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/appl/admin/custom"${CONTEXT_NAME}".env "${currentextractdir}"/fs1/env/.  > /dev/null 2>&1
	cp  -p "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/appl/admin/custom"${CONTEXT_NAME}".env "${currentextractdir}"/fs2/env/. > /dev/null 2>&1
	cp  -p  "${FND_SECURE}"/*.dbc  "${currentextractdir}"/app_others/dbc/.  > /dev/null 2>&1
  cp -p "${apptargetbasepath}"/fs1/EBSapps/appl/xdo/12.0.0/resource/xdo.cfg  "${currentextractdir}"/app_others/.  > /dev/null 2>&1
  cp -p "${apptargetbasepath}"/fs2/EBSapps/appl/xdo/12.0.0/resource/xdo.cfg  "${currentextractdir}"/app_others/. > /dev/null 2>&1

	cp  -p "${apptargetbasepath}"/fs1/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.txt "${currentextractdir}"/fs1/pairs/.  > /dev/null 2>&1
	cp  -p "${apptargetbasepath}"/fs2/inst/apps/"${CONTEXT_NAME}"/appl/admin/*.txt "${currentextractdir}"/fs2/pairs/.  > /dev/null 2>&1

	cp  -p "${apptargetbasepath}"/fs1/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/ssl.conf "${currentextractdir}"/fs1/ssl/.  > /dev/null 2>&1
	cp  -p "${apptargetbasepath}"/fs2/FMW_Home/webtier/instances/EBS_web_OHS1/config/OHS/EBS_web/ssl.conf "${currentextractdir}"/fs2/ssl/.   > /dev/null 2>&1

	cp  -p "${apptargetbasepath}"/fs1/FMW_Home/user_projects/domains/EBS_domain/config/config.xml "${currentextractdir}"/fs1/wls/.   > /dev/null 2>&1
	cp  -p "${apptargetbasepath}"/fs2/FMW_Home/user_projects/domains/EBS_domain/config/config.xml "${currentextractdir}"/fs2/wls/.  > /dev/null 2>&1

	grep s_apps_jdbc_connect_descriptor "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_apps_jdbc_connect_descriptor
	grep s_shared_file_system "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_shared_file_system
	grep s_active_webport "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_active_webport
	grep s_webssl_port "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_webssl_port
	grep s_https_listen_parameter "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_https_listen_parameter
	grep s_login_page "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_login_page
	grep s_external_url "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_external_url
	grep s_webentryhost "${CONTEXT_FILE}"  > "${currentextractdir}"/app_others/s_webentryhost

  update_clonersp "appfileextract" "COMPLETED"
else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:${current_task_id}: APP EXTRACT: Application file extraction is skipped. " | tee -a "${mainlog}" "${appextractlog}"
    update_clonersp "appfileextract" "PASS"
fi
}


extract_app()
{
  create_extract_dir
  #***************************************************************************************************###
  # Cleaning up old scripts and creating new extract scripts from Database for Post clone Upload part.
  #***************************************************************************************************###
  appextractlog="${extractlogdir}"/extractApplication"${trgappname^^}".log
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: logfile at ${HOST_NAME}: ${appextractlog}" | tee -a "${appextractlog}" "${mainlog}"

  cd "${extractdir}"
  if [ -d "${currentextractdir}" ] ; then
  		cp -pr  "${currentextractdir}"  "${bkpextractdir}"/$(date +'%d-%m-%Y') > /dev/null 2>&1
  fi

  mkdir -p "${currentextractdir}"  > /dev/null 2>&1

  extract_lookup_users
  extract_file_backup
}

stop_application()
{
  APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
  APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
  WLSUSER=$(/dba/bin/getpass "${trgappname^^}" weblogic)
  WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)
  export APPSUSER APPSPASS WLSUSER WLSPASS

  check_dbstatus
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP : Stopping Application services at ${HOST_NAME}" | tee -a "${mainlog}" "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}"
  if [ "${pdbstatus}" == "OPEN" ] ; then
    { echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstpall.sh  -nopromptmsg  >  "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}" 2>&1
  else
    { echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstpall.sh  -nodbchk >  "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}" 2>&1
  fi
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP : Application services are stopped at   ${HOST_NAME}" | tee -a "${mainlog}" "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}"
}


detach_oh()
{

source /home/$(whoami)/."${trgappname,,}"_profile >/dev/null 2>&1
detachlogf="${log_dir}"/detachOH."${HOST_NAME}"."${trgappname^^}"."${startdate}"
if [ -z "${ORACLE_HOME}" ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: Oracle Home is not set at  ${HOST_NAME}. Cannot detach Oracle Homes" | tee -a "${detachlogf}" "${mainlog}"
else
  {
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/webtier"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/oracle_common"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/Oracle_OAMWebGate1"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/FMW_Home/Oracle_EBS-app1"

  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/webtier"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/oracle_common"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/Oracle_OAMWebGate1"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/FMW_Home/Oracle_EBS-app1"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs1/EBSapps/10.1.2"
  "${ORACLE_HOME}"/oui/bin/runInstaller  -detachHome ORACLE_HOME="${apptargetbasepath}/fs2/EBSapps/10.1.2"
  } >> "${detachlogf}" 2>&1

fi

if [ -f "/etc/oraInst.loc"  ] ; then
  source /etc/oraInst.loc > /dev/null 2>&1
  export vinvloc="${inventory_loc}"
  cp "${vinvloc}"/ContentsXML/inventory.xml  "${vinvloc}"/ContentsXML/inventory.xml.before."${trgappname^^}"
  sed -i "/${trgappname^^}/d" "${vinvloc}"/ContentsXML/inventory.xml  2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: Detaching ORACLE_HOME is completed. " | tee -a "${detachlogf}" "${mainlog}"
elif [ ! -f "/etc/oraInst.loc" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: oraInst.loc file is not available. Detaching ORACLE_HOME is not completed. " | tee -a "${detachlogf}" "${mainlog}"
fi
}

restore_apps_tier()
{

  #******************************************************************************************************#
  # Validate backup location and backup file to be restored.
  #******************************************************************************************************#
 source "${clonerspfile}" > /dev/null 2>&1
if [[ "${appscopy_stage}" == "COMPLETED" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: APP COPY stage is already completed. Moving on."
elif   [[ "${current_task_id}" == 3000 ]] ; then
  if [[ -n "${appbkpfilefullpath}" ]]; then
	  appbkpfile=$(cat "${appsourcebkupdir}"/runfs.latest)
	  appbkpfilefullpath="${appsourcebkupdir}"/"${appbkpfile}"
	  if [[ ! -f "${appbkpfilefullpath}" ]]; then
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: ERROR: Application backup for ${srcappname} not found. Please check.EXITING!!"
		  exit 1;
	  else
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Application backup for ${srcappname} found."
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: File name: ${appbkpfilefullpath}. "
		  sleep 2
	  fi
	fi

  update_clonersp "appbkpfilefullpath" "${appbkpfilefullpath}"
  source "${clonerspfile}" > /dev/null 2>&1
	# Determine run fs from backup file
	if [[ -n "${runfs}" ]] || [[ -n "${patchfs}" ]] ; then
	  if [[ "${appbkpfile}" == *"fs1"* ]]; then
			export runfs=fs1
			export patchfs=fs2
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Run fs is set to ${runfs}.  "
	  elif [[ "${appbkpfile}" == *"fs2"* ]]; then
			export runfs=fs2
			export patchfs=fs1
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Run fs is set to ${runfs}.  "
	  else
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: ERROR: Run fs could not be identified. Backup file will not be restored. Exiting!!\n.  "
		  exit 1
	  fi
	fi

  update_clonersp "runfs" "${runfs}"
  update_clonersp "patchfs" "${patchfs}"
  source "${clonerspfile}" > /dev/null 2>&1
	#Unzip backup file
	targetrunfs="${apptargetbasepath}"/"${runfs}"
	cd "${targetrunfs}" || echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: ERROR: Could not move to runfs location Exiting !!" &&  exit 1
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Target runfs location is set to:  ${targetrunfs}.  "

	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Initiating Source application backup copy to Target application node.  "
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: SCP target string: ${appsosuser}@${trgapphost}.${labdomain}:${targtrunfs}/. "
	  sleep 5
	  scp -q -o TCPKeepAlive=yes "${appbkpfilefullpath}" "${appsosuser}"@"${trgapphost}"."${labdomain}":"${targtrunfs}"/.

	  rcode=${?}
	  if (( rcode > 0 )); then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: ERROR: Application backup file could not be copied. EXITING !! \n "
		  exit 1
	  else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP COPY: Application backup file copied to ${trgapphost}.${labdomain}.  "
		  sleep 2
	  fi
	  unset rcode
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:APP COPY "
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"

	  update_clonersp "appscopy_stage" "COMPLETED"
	  update_clonersp "current_module_task" 4000
	  update_clonersp "current_task_id" 4000

	  source "${clonerspfile}" > /dev/null 2>&1

fi

}

	#Validate and cleanup old stack
	cleanup_and_restore_apps()
	{
	markerfile=${apptargetbasepath}/${runfs}/EBSapps/restore.complete

	if [ -f ${markerfile} ];
	then
		chkrestorefile=`cat ${markerfile}`
		if [ "${chkrestorefile}" = "${apps_bkp_file}" ];
		then
			# Detach Oracle homes from Inventory.
			detach_apps_oh

			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Apps tier backup file already restored. No need to restore backup." | tee -a ${logf}
			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Clearing up last session directories." | tee -a ${logf}

			rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null
			sleep 2
		else
			# Detach Oracle homes from Inventory.
			detach_apps_oh

			echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: MESSAGE: Clearing up old  directories." | tee -a ${logf}
			# If marker file does not have same value as apps_bkp_file, then move old stack.
			#move_old_stack
			rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/EBSapps 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
			rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null

			# Restore apps tier backup
			restore_apps_tier
		fi
	elif [ ! -f ${markerfile} ];
	then
		# Detach Oracle homes from Inventory.
		detach_apps_oh

		# If marker file not found, it means last untar session failed. Hence remove everything.
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP CLEANUP: This is a fresh session." | tee -a ${logf}
		echo -e "`date +"%d-%m-%Y %H:%M:%S"`: ${HOST_NAME}: APP CLEANUP: Run and Patch fs will be removed." | tee -a ${logf}

		rm -rf ${apptargetbasepath}/${patchfs}/EBSapps 2>/dev/null
		rm -rf ${apptargetbasepath}/${patchfs}/inst 2>/dev/null
		rm -rf ${apptargetbasepath}/${patchfs}/FMW_Home 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/inst 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/FMW_Home 2>/dev/null
		rm -rf ${apptargetbasepath}/${runfs}/EBSapps 2>/dev/null

		# Restore apps tier backup
		restore_apps_tier
	fi

	}

#******************************************************************************************************##
##	Execute application steps
#******************************************************************************************************##

if [[ "${current_task_id}" -ge 600 ]]  && [[ "${current_task_id}"  -le 3500 ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP TASK ID CHECK: TASK ID is out of range for Application script execution."
  exit 1
fi

mainlog="${log_dir}"/mainlogapplication."${startdate}"

for task in $(seq "${current_task_id}" 1 3500 )
do
  case $task in
    "50")
          update_clonersp "current_task_id" 500  ;;
    "500")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START MODULE:PREPARE APP "
          update_clonersp "current_task_id" 520 ;;
    "520")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          extract_app
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 530  ;;
    "530")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          stop_application
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 540  ;;
    "540")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          detach_oh
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 550  ;;
    "600")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END MODULE:PREPARE APP "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1000  ;
          exit 0  ;;

    "3000")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START MODULE:CONFIG APP "
          update_clonersp "current_task_id" 520 ;;


  *)
    :
    #echo "Task not found - step: $task not present in stage ${session_stage}"  | tee -a "${logf}"
    ;;
  esac
done

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : >>>>>>> Application tier clone steps are completed. <<<<<<< " | tee -a  "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP : "

exit

#******************************************************************************************************##
#  **********   E N D - O F - A P P L I C A T I O N - R E S T O R E - S C R I P T   **********
#******************************************************************************************************##