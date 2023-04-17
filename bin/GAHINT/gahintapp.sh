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
export dbupper="GAHINT"
export dblower="${dbupper,,}"
export HOST_NAME=$(uname -n | cut -f1 -d".")

#******************************************************************************************************##
#	Local variable declaration.
#******************************************************************************************************##
export scr_home=/u05/oracle/autoclone
# Setup oem node log dir for oem node local logs
if [[ ! -d  "${scr_home}/instance/${dbupper}/lock" ]] ; then
  mkdir -p "${scr_home}"/instance/"${dbupper}"/lock > /dev/null 2>&1
fi

export lock_dir="${scr_home}/instance/${dbupper}/lock"
sleep 1
if [ -f "${lock_dir}"/"${dblower}"app.lck ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Lock file exists for application script, another session is still running.\n\n"
  exit 1
fi

#******************************************************************************************************##
##	Source instance properties file
#******************************************************************************************************##

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [[ ! -f ${envfile} ]];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="${clonerspfile}"
if [[ ! -f "${envfile}" ]];  then
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

export APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
export APPSCONNECTSTR="${APPSUSER}"@"${trgappname}"

unpw="${APPSUSER}"@"${trgappname^^}"
sqlplus /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [[ $? -ne 0 ]]; then
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
else
  pstatus="UNKNOWN"
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


	# Load up all passwords needed from getpass
load_getpass_password()
	{
	dbupper="${trgappname^^}"

	#Load Target passwords
	export SYSTUSER=$(/dba/bin/getpass "${dbupper}" system)
	#echo ${SYSTUSER}
	export SYSTPASS=$(echo $SYSTUSER | cut -d/ -f 2)
	export APPSUSER=$(/dba/bin/getpass ${dbupper} apps)
	export APPSPASS=$(echo $APPSUSER | cut -d/ -f 2)
	#echo ${APPSUSER}
	export EXPDUSER=$(/dba/bin/getpass ${dbupper} xxexpd)
	export EXPDPASS=$(echo $EXPDUSER | cut -d/ -f 2)
	export OALLUSER=$(/dba/bin/getpass ${dbupper} alloracle)
	export OALLPASS=$(echo $OALLUSER | cut -d/ -f 2)
	export SYSADUSER=$(/dba/bin/getpass ${dbupper} sysadmin)
	export SYSADPASS=$(echo $SYSADUSER | cut -d/ -f 2)
	export WLSUSER=$(/dba/bin/getpass ${dbupper} weblogic )
	export WLSPASS=$(echo $WLSUSER | cut -d/ -f 2)
	export VSAPPREADUSER=$(/dba/bin/getpass ${dbupper} sappreaduser  )
	export VSAPPREADPASS=$(echo $VSAPPREADUSER | cut -d/ -f 2)
	export VSAPPWRITEUSER=$(/dba/bin/getpass ${dbupper} sappwriteuser  )
	export VSAPPWRITEPASS=$(echo $VSAPPWRITEUSER | cut -d/ -f 2 )

	}

	# Password validate function ######
	chk_apps_password()
	{
	unpw="apps/${1}@${2}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

	if [[ $? -ne 0 ]]; then
		return 1
	else
	  return 0
	fi
	}


	# Validate which APPS password is working - Source or Target
	validate_working_apps_password()
	{
	#echo -e "checking  ${SRCAPPSPASS} for validation."
	chk_apps_password "${SRCAPPSPASS}" "${trgappname^^}"
	_chkTpassRC1=$?
	sleep 1
	chk_apps_password "${APPSPASS}" "${trgappname^^}"
	_chkTpassRC2=$?
	sleep 1
	if [[ "${_chkTpassRC1}" -eq 0 ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:   " | tee -a  "${mainlog}"
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK: *******  Source APPS Password is working  ******* " | tee -a  "${mainlog}"
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:   " | tee -a  "${mainlog}"
		workappspass="${SRCAPPSPASS}"
	elif [[ "${_chkTpassRC2}" -eq 0 ]]; then
    workappspass="${APPSPASS}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:   " | tee -a  "${mainlog}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:  *******  Target APPS Password is working  ******* " | tee -a  "${mainlog}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:   " | tee -a  "${mainlog}"
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHECK:   ERROR: Source and Target - Both APPS passwords are not working. Exiting !" | tee -a  "${mainlog}"
		exit 1
	fi
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
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  export APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
  export APPSPASS=$(echo "${APPUSER}" | cut -d/ -f 2)

  check_dbstatus

if [[ "${pdbstatus}" == "OPEN" ]]  && [[ -z "${appsqlextract}"  ]] ; then

sqlplus  -s  "${APPSUSER}"@"${trgappname}"  << EOF > /dev/null
set head off
set feed off
set line 999

spool ${currentextractdir}/app_fnd_lookup/app_extract_fndlookup.sh
set head off
set feed off
set line 999

spool ${currentextractdir}/app_fnd_lookup/app_extract_fndlookup.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile  > /dev/null' from dual;
select 'FNDLOAD $APPSUSER O Y DOWNLOAD '||'$'||'FND_TOP/patch/115/import/aflvmlu.lct ${uploaddir}/fnd_lookups/'||lookup_type||'.ldt FND_LOOKUP_TYPE APPLICATION_SHORT_NAME=''XXEXPD'' LOOKUP_TYPE='''||lookup_type||'''' from fnd_lookup_values where lookup_type in ('EXPD_BASE_PATH_LOOKUP','EXPD_FILE_RENAME_PATH','EXPD_EXTENDED_PATH_LOOKUP','EXPD_WS_URL','EXPD_SOA_INSTANCE_LOOKUP','EXPD_TXBRIDGE_OAUTH_CREDS_LKP','EXPD_TXBRIDGE_INSTANCE_LOOKUP','EXPD_AWS_S3_BUKCETS_LKP') group by lookup_type;
select ' rm -f ${currentextractdir}/app_fnd_lookup/L*.log ' from dual;
spool off
spool ${uploaddir}/fnd_lookups/app_upload_fndlookup.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile > /dev/null' from dual;
select 'FNDLOAD $APPSUSER O Y UPLOAD '||'$'||'FND_TOP/patch/115/import/aflvmlu.lct ${uploaddir}/fnd_lookups/'||lookup_type||'.ldt'  from fnd_lookup_values where lookup_type in ('EXPD_BASE_PATH_LOOKUP','EXPD_FILE_RENAME_PATH','EXPD_EXTENDED_PATH_LOOKUP','EXPD_WS_URL','EXPD_SOA_INSTANCE_LOOKUP','EXPD_TXBRIDGE_OAUTH_CREDS_LKP','EXPD_TXBRIDGE_INSTANCE_LOOKUP','EXPD_AWS_S3_BUKCETS_LKP') group by lookup_type;
select ' rm -f ${currentextractdir}/app_fnd_lookup/L*.log ' from dual;
select ' rm -f ${uploaddir}/fnd_lookups/L*.log ' from dual;
spool off

spool ${currentextractdir}/app_fnd_user/app_extract_fnd_user.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile > /dev/null' from dual;
select 'FNDLOAD $APPSUSER 0 Y DOWNLOAD '||'$'||'FND_TOP/patch/115/import/afscursp.lct ${uploaddir}/fnd_users/'||USER_NAME||'.ldt FND_USER USER_NAME='''||USER_NAME||''' ' from fnd_user where last_logon_date >= sysdate-900 or trunc(creation_date)=trunc(sysdate);
select ' rm -f ${currentextractdir}/L*.log ' from dual;
select ' rm -f ${uploaddir}/fnd_users/L*.log ' from dual;
select ' rm -f ${log_dir}/L*.log ' from dual;
spool off
spool ${uploaddir}/fnd_users/app_upload_fnd_user.sh
select '. ${HOME}/.'||lower('${dblower}')||'_profile  > /dev/null' from dual;
select 'FNDLOAD $APPSUSER 0 Y UPLOAD '||'$'||'FND_TOP/patch/115/import/afscursp.lct ${uploaddir}/fnd_users/'||USER_NAME||'.ldt  ' from fnd_user where last_logon_date >= sysdate-900 or trunc(creation_date)=trunc(sysdate);
select ' rm -f ${currentextractdir}/app_fnd_lookup/L*.log ' from dual;
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
if [[ -z "${appfileextract}"  ]] ; then
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
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: Application file extraction is skipped. " | tee -a "${mainlog}" "${appextractlog}"
    update_clonersp "appfileextract" "PASS"
fi
}


extract_app()
{
  create_extract_dir

    if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
      source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP EXTRACT: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
      update_clonersp "session_state" "FAILED"
      exit 1
    fi

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
    if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
      source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
      update_clonersp "session_state" "FAILED"
      exit 1
    fi

  APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
  APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
  WLSUSER=$(/dba/bin/getpass "${trgappname^^}" weblogic)
  WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)
  export APPSUSER APPSPASS WLSUSER WLSPASS

  check_dbstatus
  if [[ -z "${appstopservice}" ]] ; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP: Stopping Application services at ${HOST_NAME}" | tee -a "${mainlog}" "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}"
    if [[ "${pdbstatus}" == "OPEN" ]] ; then
      { echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstpall.sh  -nopromptmsg  >  "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}" 2>&1
    else
    { echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstpall.sh  -nodbchk >  "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}" 2>&1
    fi
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP: Application services are stopped at   ${HOST_NAME}" | tee -a "${mainlog}" "${log_dir}"/stopApplication"${trgappname^^}"."${startdate}"

    update_clonersp "appstopservice" "COMPLETED"
  else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STOP APP: Application service step is skipped. " | tee -a "${mainlog}" "${appextractlog}"
      update_clonersp "appstopservice" "PASS"
  fi
}


detach_oh()
{
  envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
  if [[ ! -f ${envfile} ]];  then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
      exit 1;
  else
      source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
      sleep 1
  fi
  unset envfile

if [[ -z "${appsdetachhome}" ]] || [[ "${appsdetachhome}" == "RESET" ]] ; then
  detachlogf="${log_dir}"/detachOH."${HOST_NAME}"."${trgappname^^}"."${startdate}"
  if [[ -z "${ORACLE_HOME}" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: Oracle Home is not set at  ${HOST_NAME}. Cannot detach Oracle Homes" | tee -a "${detachlogf}" "${mainlog}"
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: Oracle Home is not set at  ${HOST_NAME}. Running detach Oracle Homes" | tee -a "${detachlogf}" "${mainlog}"
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

  if [[ -f "/etc/oraInst.loc"  ]]; then
    source /etc/oraInst.loc > /dev/null 2>&1
    export vinvloc="${inventory_loc}"
    cp "${vinvloc}"/ContentsXML/inventory.xml  "${vinvloc}"/ContentsXML/inventory.xml.before."${trgappname^^}"
    sed -i "/${trgappname^^}/d" "${vinvloc}"/ContentsXML/inventory.xml  2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: Detaching ORACLE_HOME is completed. " | tee -a "${detachlogf}" "${mainlog}"
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DETACH OH: oraInst.loc file is not available. Detaching ORACLE_HOME is not completed. " | tee -a "${detachlogf}" "${mainlog}"
  fi
fi
  update_clonersp "appsdetachhome" "COMPLETED"
  source "${clonerspfile}" > /dev/null 2>&1

}

	# restore/untar mentioned tar file in the given runfs.
	restore_apps_tier()
	{
	  envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    if [[ ! -f ${envfile} ]];  then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
        exit 1;
    else
        source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
        sleep 1
    fi
    unset envfile

  source "${clonerspfile}" > /dev/null 2>&1
  cd "${targetrunfs}" || echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Could not enter into ${targetrunfs}. Exiting !! " && exit 1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Decompressing backup file, it may take 15-20mins." | tee -a  "${mainlog}"
	tar -xzvf "${apps_bkp_file}" >> "${log_dir}"/untar_appsbkp"${trgappname}"."${startdate}"

	if [[  -d "${targetrunfs}"/EBSapps ]] ; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Application tier backup file decompress completed." | tee -a  "${mainlog}"
    echo "${apps_bkp_file}" > "${apptargetbasepath}"/"${runfs}"/EBSapps/restore.complete
  else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Tar file  could not create EBSapps. Exiting !!" | tee -a  "${mainlog}"
	  echo "${apps_bkp_file}" > "${targetrunfs}"/EBSapps/restore.failed
	  update_clonersp "apprestorestage" "COMPLETED"
    source "${clonerspfile}" > /dev/null 2>&1
		exit 1
	fi
	}

	#Validate and cleanup old stack
	cleanup_and_restore_apps()
	{
  envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
  if [[ ! -f ${envfile} ]];  then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
      exit 1;
  else
      source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
      sleep 1
  fi
  unset envfile

  source "${clonerspfile}" > /dev/null 2>&1
  if [[ "${apprestorestage}" == "COMPLETED" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Application tier backup file is already restored. No need to restore backup." | tee -a  "${mainlog}"
    if [[ "${appadcfgclonestage}" == "COMPLETED" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: Application tier adcfgclone is already completed. Moving on .. " | tee -a  "${mainlog}"
      return 0
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Running cleanup for old directories." | tee -a  "${mainlog}"
      # Detach Oracle homes from Inventory.
      detach_oh
      rm -rf "${apptargetbasepath}"/"${patchfs}"/EBSapps 2>/dev/null
      rm -rf "${apptargetbasepath}"/"${patchfs}"/inst 2>/dev/null
      rm -rf "${apptargetbasepath}"/"${patchfs}"/FMW_Home 2>/dev/null
      rm -rf "${apptargetbasepath}"/"${runfs}"/inst 2>/dev/null
      rm -rf "${apptargetbasepath}"/"${runfs}"/FMW_Home 2>/dev/null
      rm -rf "${apptargetbasepath}"/"${runfs}"/EBSapps 2>/dev/null
      sleep 2
    fi
  else
		# Detach Oracle homes from Inventory.
		detach_oh
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Running cleanup for old directories from old session." | tee -a  "${mainlog}"
		rm -rf "${apptargetbasepath}"/"${patchfs}"/EBSapps 2>/dev/null
		rm -rf "${apptargetbasepath}"/"${patchfs}"/inst 2>/dev/null
		rm -rf "${apptargetbasepath}"/"${patchfs}"/FMW_Home 2>/dev/null
		rm -rf "${apptargetbasepath}"/"${runfs}"/inst 2>/dev/null
		rm -rf "${apptargetbasepath}"/"${runfs}"/FMW_Home 2>/dev/null
		# Restore apps tier backup
		restore_apps_tier
  fi

	update_clonersp "apprestorestage" "COMPLETED"
  source "${clonerspfile}" > /dev/null 2>&1
	}

	# Pre-checks before executing adcfgclone
	validate_pre_adcfgclone()
	{
    envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    if [[ ! -f ${envfile} ]];  then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
        exit 1;
    else
        source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
        sleep 1
    fi
    unset envfile

  if [[ "${appadcfgclonestage}" == "COMPLETED" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: Application tier adcfgclone is already completed. Moving on .. " | tee -a  "${mainlog}"
  else
	  # Restored File system fs and edition validation
	  _pcontextf="${apptargetbasepath}"/"${runfs}"/EBSapps/comn/clone/context/apps/"${srcappname^^}"_"${srcadminapphost}".xml
	  _chkfs=$(grep "file_edition_name" "${_pcontextf}")
	  _chked=$(grep "file_edition_type" "${_pcontextf}")

	  if [[ "${_chkfs}" == *"${runfs}"* ]] ; then
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: Supplied fs is ${runfs}. " | tee -a  "${mainlog}"
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: Validated fs from restored backup is ${_chkfs}. " | tee -a  "${mainlog}"
	  elif [[ "${_chked}" == *"run"* ]] && [[ "${_chkfs}" == *"${runfs}"* ]] ; then
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: Validated edition from restored backup is ${runfs}.. " | tee -a  "${mainlog}"
	  else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: ERROR: Restore Backup File system validation failed. Restored backup is not from RUN fs. Please validate. EXITING !!. " | tee -a  "${mainlog}"
		  exit 1
	  fi

	  # Validating txkWfClone.sh file exists and it have exit 0 added in first 2 lines to avoid long running adcfgclone.pl
	  _FILE1="${apptargetbasepath}/${runfs}/EBSapps/appl/fnd/12.0.0/admin/template/txkWfClone.sh"
	  if [[ -f "${_FILE1}" ]] ; then
		  sed -i '2 i exit 0 \n'  "${_FILE1}"
	  else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: Warning: txkWfClone.sh file not found. Please review " | tee -a  "${mainlog}"
		  exit 1
	  fi
	  unset _FILE1

		# Validating pairs file and adcfgclone
  	unset apppairsfile
  	unset appadcfgclonefile
  	apppairsfile="${etc_home}"/"${trgappname}"_"${trgadminapphost}"_"${runfs}".txt
  	appadcfgclonefile="${apptargetbasepath}/${runfs}/EBSapps/comn/clone/bin/adcfgclone.pl"
  	if [[ -f "${apppairsfile}" ]] && [[ -f "${appadcfgclonefile}" ]] ; then
  	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: ${runfs} Pairs file found. Proceeding further.. " | tee -a  "${mainlog}"
  		sleep 2
  	elif [[ ! -f "${apppairsfile}" ]]; then
  		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PAIRS VALIDATION: ${runfs} Pairs file not found. Application configuration cannot proceed. exiting !! " | tee -a  "${mainlog}"
  		exit 1
  	elif [[ ! -f "${appadcfgclonefile}" ]]; then
  		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP BKP VALIDATION: adcfgclone file not found. Application configuration cannot proceed. exiting !!. " | tee -a  "${mainlog}"
  		exit 1
  	fi

	  update_clonersp "apppairsfile" "${apppairsfile}"
	  update_clonersp "appadcfgclonefile" "${appadcfgclonefile}"
    source "${clonerspfile}" > /dev/null 2>&1
	fi
	}

	#execute autoconfig
	run_autoconfig()
	{
	  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
      source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
      update_clonersp "session_state" "FAILED"
      exit 1
    fi
  source "${clonerspfile}" > /dev/null 2>&1

	#Load Target passwords
	load_getpass_password
	#Validate working apps password, this will also validate connectivity.
	validate_working_apps_password

	#To keep track of autoconfig runs.
	autoconfigcnt=$((autoconfigcnt+1))
	sed -i '/connection/d' "${EBS_DOMAIN_HOME}"/config/config.xml

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: " | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: Running autoconfig....  Execution count ${autoconfigcnt}. " | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: " | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: Logfile ${log_dir}/run_appautoconfig${autoconfigcnt}.${startdate}" | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: " | tee -a  "${mainlog}"

	sh "${ADMIN_SCRIPTS_HOME}"/adautocfg.sh  appspass="${workappspass}"  > "${log_dir}"/run_appautoconfig"${autoconfigcnt}"."${startdate}"
	rcode=$?
	if (( rcode > 0 )); then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: ERROR: autoconfig failed on application host ${HOST_NAME}. EXITING !!" | tee -a  "${mainlog}"
   exit 1
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: Autoconfig execution count ${autoconfigcnt} completed successfully." | tee -a  "${mainlog}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP AUTOCONFIG: " | tee -a  "${mainlog}"
    sleep 2
	fi
	unset rcode
	sed -i '/connection/d' "${EBS_DOMAIN_HOME}"/config/config.xml
	}

	# run adcfgclone.pl with available values.
	run_adcfgclone()
	{
  source "${clonerspfile}" > /dev/null 2>&1
  envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
  if [[ ! -f ${envfile} ]];  then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
      exit 1;
  else
      source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
      sleep 1
  fi
  unset envfile

 if [[ -z "${apps_bkp_file}" ]] ; then
    sleep 2
    apps_bkp_file=$(cat "${appsourcebkupdir}"/runfs.latest)
    appbkpfilefullpath="${appsourcebkupdir}"/"${apps_bkp_file}"
    update_clonersp "appbkpfilefullpath" "${appbkpfilefullpath}"
    update_clonersp "apps_bkp_file" "${apps_bkp_file}"
    source "${clonerspfile}" > /dev/null 2>&1
  fi

	  if echo "${apps_bkp_file}" | grep -q "fs1"; then
	    echo -e "Inside fs1 block "
			export runfs=fs1
			export patchfs=fs2
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Run fs is set to ${runfs}." | tee -a  "${mainlog}"
	  elif echo "${apps_bkp_file}" | grep -q "fs2"; then
			export runfs=fs2
			export patchfs=fs1
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Run fs is set to ${runfs}." | tee -a  "${mainlog}"
	  else
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: ERROR: Run fs could not be identified. Backup file will not be restored. Exiting!!\n." | tee -a  "${mainlog}"
	    sleep 2
		  exit 1
	  fi

  update_clonersp "runfs" "${runfs}"
  update_clonersp "patchfs" "${patchfs}"
  source "${clonerspfile}" > /dev/null 2>&1
	targetrunfs="${apptargetbasepath}"/"${runfs}"
	if [[ -d "${targetrunfs}" ]] ; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Target Run fs is set to ${runfs}." | tee -a  "${mainlog}"
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Target runfs location ${targetrunfs} could not be reached. Cannot proceed. Exiting !!." | tee -a  "${mainlog}"
	  exit 1
	fi

	update_clonersp "targetrunfs" "${targetrunfs}"
  source "${clonerspfile}" > /dev/null 2>&1

  if [[ -f "${appbkpfilefullpath}"  ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: Application backup file found: ${apps_bkp_file}" | tee -a  "${mainlog}"
  else
    sleep 2
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP RESTORE: ERROR: Application backup for ${srcappname} not found. Please check.EXITING!!"
    exit 1
  fi

  if [[ "${appadcfgclonestage}" == "COMPLETED" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: Application tier adcfgclone is already completed. Moving on .. " | tee -a  "${mainlog}"
  else
    cleanup_and_restore_apps
    validate_pre_adcfgclone
	  # Validate pre-adcfgclone run checks
		export CONFIG_JVM_ARGS="-Xms2048m -Xmx4096m"
		if [[ "${runfs}" == "fs1" ]] || [[ "${runfs}" == "fs2" ]] ; then
		  adcfgclonelog="${log_dir}"/adcfgcloneRun"${trgappname}"."${startdate}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: ********  starting adcfgclone from ${runfs} *******. " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: Logfile :${adcfgclonelog}" | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: " | tee -a  "${mainlog}"

			{ echo "${SRCAPPSPASS}" ; echo "${SRCWLSPASS}" ; echo "n" ; } | perl "${apptargetbasepath}"/"${runfs}"/EBSapps/comn/clone/bin/adcfgclone.pl component=appsTier pairsfile="${apppairsfile}" dualfs=yes >  "${adcfgclonelog}"  2>&1
			_exitSt1=$?
		else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: Run fs is not validated. Make sure you have supplied fs1 or fs2. EXITING !!" | tee -a  "${mainlog}"
			exit 1
		fi

    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: Exit status for adcfgclone is ${_exitSt1} " | tee -a  "${mainlog}"
		if [[ "${_exitSt1}" == "0" ]] ; then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}: " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: ********  adcfgclone.pl is completed successfully  *******  " | tee -a  "${mainlog}"
      update_clonersp "appadcfgclonestage" "COMPLETED"
      source "${clonerspfile}" > /dev/null 2>&1
		else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP CFGCLONE: ERROR:  adcfgclone.pl was failed. Please check the logs and restart. EXITING !! " | tee -a  "${mainlog}"
		  update_clonersp "appadcfgclonestage" "FAILED"
      source "${clonerspfile}" > /dev/null 2>&1
			exit 1
		fi
  fi
	}

  # Post adcfgclone steps part of POST clone.
  postadcfgclone()
  {

  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP POST RESTORE: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1

	runfsctx="${apptargetbasepath}/${runfs}/inst/apps/${CONTEXT_NAME}/appl/admin/${CONTEXT_NAME}.xml"
	patchfsctx="${apptargetbasepath}/${patchfs}/inst/apps/${CONTEXT_NAME}/appl/admin/${CONTEXT_NAME}.xml"

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP POST RESTORE: Restoring TNS files.  " | tee -a  "${mainlog}"
	chmod -R 775 "${currentextractdir}"/"${runfs}"/tns >/dev/null 2>&1
	chmod -R 775 "${currentextractdir}"/"${patchfs}"/tns   >/dev/null 2>&1
	cp -r  "${currentextractdir}"/"${runfs}"/tns/*  "${apptargetbasepath}"/"${runfs}"/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin/.   >> "${mainlog}"2>&1
	cp -r  "${currentextractdir}"/"${patchfs}"/tns/*  "${apptargetbasepath}"/"${patchfs}"/inst/apps/"${CONTEXT_NAME}"/ora/10.1.2/network/admin/. >> "${mainlog}" 2>&1
	sleep 2
  run_autoconfig
  }

	change_other_application_password()
	{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
    source "${clonerspfile}" > /dev/null 2>&1

  if [[ "${changeotherappspass}" != "COMPLETED"  ]] || [[ -z "${changeotherappspass}" ]]; then
	  #gives workappspass
	 validate_working_apps_password

	  cd "${log_dir}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Changing SYSADMIN,ALLORACLE, XXEXPD Passwords. " | tee -a  "${mainlog}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Executing APPS password validation  " | tee -a  "${mainlog}"
	  "${FND_TOP}"/bin/FNDCPASS apps/"${workappspass}" 0 Y system/"${SYSTPASS}" USER   SYSADMIN  "${SYSADPASS}"  > "${log_dir}"/changeOtherPasswords."${startdate}" 2>&1
	  "${FND_TOP}"/bin/FNDCPASS apps/"${workappspass}" 0 Y system/"${SYSTPASS}" ALLORACLE "${OALLPASS}"    >> "${log_dir}"/changeOtherPasswords."${startdate}" 2>&1
	  "${FND_TOP}"/bin/FNDCPASS apps/"${workappspass}" 0 Y system/"${SYSTPASS}" ORACLE  XXEXPD "${EXPDPASS}"    >> "${log_dir}"/changeOtherPasswords."${startdate}" 2>&1
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: SYSADMIN,ALLORACLE, XXEXPD Password change -- Completed. " | tee -a  "${mainlog}"

	  update_clonersp "changeotherappspass" "COMPLETED"
	  source "${clonerspfile}" > /dev/null 2>&1
	fi

	}


	change_runfs_password()
	{

    if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
      source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
      update_clonersp "session_state" "FAILED"
      exit 1
    fi


  source "${clonerspfile}" > /dev/null 2>&1
	#Load target passwords
	load_getpass_password

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Executing APPS password validation  " | tee -a  "${mainlog}"
	chk_apps_password "${APPSPASS}" "${trgappname^^}"
	_chkTpassRC=$?
	sleep 2
	if [[ "${_chkTpassRC}" -eq 0 ]] ; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: ====> APPS Password Change is not needed.<<====   " | tee -a  "${mainlog}"
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
	  workappspass="${APPSPASS}"
	  sleep 2
	elif [[ "${_chkTpassRC}" -ne 0 ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   Testing connectivity with Source APPS password." | tee -a  "${mainlog}"
		chk_apps_password  "${SRCAPPSPASS}" "${trgappname^^}"
		_chkSrcpassRC=$?
		sleep 2
		if [[ "${_chkSrcpassRC}" -eq 0 ]] && [[ "${workappspass}" != "${APPSPASS}" ]]; then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Database connection established with SOURCE APPS password." | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Changing APPS password for Runfs. " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: Logfile: ${log_dir}/resetAPPSpassword_${trgappname^^}.${startdate}  " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   ====> Changing APPS Password <<==== " | tee -a  "${mainlog}"
			workappspass=${SRCAPPSPASS}
			sleep 2
			#FNDCPASS commands
			"${FND_TOP}"/bin/FNDCPASS apps/"${workappspass}" 0 Y system/"${SYSTPASS}" SYSTEM APPLSYS "${APPSPASS}"  > "${log_dir}"/resetAPPSpassword_"${trgappname^^}"."${startdate}"  2>&1
			chk_apps_password "${APPSPASS}" "${trgappname^^}"
			_chkTpassRC=$?
			sleep 2
			if [[ "${_chkTpassRC}" -ne 0 ]]; then
			  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: ERROR: Database connection could not be established with NEW APPS password.  " | tee -a  "${mainlog}"
				exit 1
			else
			  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
			  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:  ====> APPS Password Changed Successfully by FNDCPASS. <<====   " | tee -a  "${mainlog}"
			  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
			workappspass="${APPSPASS}"
			fi

		elif [[ "${_chkSrcpassRC}" -ne 0 ]] && [[ "${_chkTpassRC}" -ne 0 ]]; then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE: ERROR: Database connection could not be established with any apps password (SOURCE and TARGET).  " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:        ABORTING Operation, Please make sure atleast one(source or target) password is working.  " | tee -a  "${mainlog}"
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:        Also check if database is available and listener is up." | tee -a  "${mainlog}"
			sleep 2
			exit 1
		else
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP PASS CHANGE:   " | tee -a  "${mainlog}"
		fi
	fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Starting ADMIN server on RUNFS  " | tee -a  "${mainlog}"
	if [[ "${FILE_EDITION}" == "run" ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Starting AdminServer with Source WLS Credentials " | tee -a  "${mainlog}"
		{ echo "${workwlspass}" ; echo "${workappspass}" ; } | "${ADMIN_SCRIPTS_HOME}"/adadminsrvctl.sh start '-nopromptmsg'  > "${log_dir}"/startAdminServer1."${startdate}" 2>&1
		exit_code=$?
	elif [[ "${FILE_EDITION}" == "patch" ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: You are running Run FS AdminServer startup from PATCH FS.  " | tee -a  "${mainlog}"
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: File System Edition could not be determined. It should be run or patch. Environment not set.  " | tee -a  "${mainlog}"
	fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Exit code returned from AdminServer Start ${exit_code}.  " | tee -a  "${mainlog}"
	if [[ $exit_code -eq 0 ]] || [[  $exit_code -eq 2 ]]; then
		sleep 2
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: AdminServer is available now  " | tee -a  "${mainlog}"
	elif [[ $exit_code -eq 9 ]] || [[ $exit_code -eq 1 ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Source credentials not working, Starting AdminServer with Target Credentials.  " | tee -a  "${mainlog}"
		{ echo "${WLSPASS}" ; echo "${workappspass}" ; } | "${ADMIN_SCRIPTS_HOME}"/adadminsrvctl.sh start '-nopromptmsg' > "${log_dir}"/startAdminServer2."${startdate}" 2>&1
		exit_code=$?
		if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 2 ]]; then
			sleep 2
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: **** AdminServer is available, Weblogic Password Change is not needed ****  " | tee -a  "${mainlog}"
			workwlspass=${WLSPASS}
		elif [[ $exit_code -eq 9 ]] || [[  $exit_code -eq 1 ]]; then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Both Source and Target Weblogic password is also Invalid. Please validate the passwords.  " | tee -a  "${mainlog}"
		exit 1
		fi
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Weblogic Password validation failed, Both Source and Target weblogic passwords are not working.  " | tee -a  "${mainlog}"
		exit 1
	fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Running Context File Sync  (IGNORE stty errors).  " | tee -a  "${mainlog}"
	{ echo "${workappspass}" ; echo "${workwlspass}" ; } |perl "${AD_TOP}"/bin/adSyncContext.pl -contextfile="${CONTEXT_FILE}"  > "${log_dir}"/Context_filesync1."${startdate}" 2>&1
	exit_code=$?
	sleep 5
	if [[ $exit_code -eq 0 || $exit_code -eq 1 ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Context File Sync completed Successfully." | tee -a  "${mainlog}"
	elif [[  $exit_code -eq 9 || $exit_code -eq 1 ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Context file sync failed. Invalid credentials passed.  " | tee -a  "${mainlog}"
		exit_code=1
		exit 0
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Context File Sync exit status Could not be identified !!  " | tee -a  "${mainlog}"
		exit 1
	fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Updating NEW apps Password to WLS Console. " | tee -a  "${mainlog}"
	{ echo 'updateDSPassword' ; echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${workappspass}" ; } |perl "${FND_TOP}"/patch/115/bin/txkManageDBConnectionPool.pl > "${log_dir}"/Console_apps_passwordUpdate."${startdate}" 2>&1
	exit_code=$?
	sleep 2
	if [[ $exit_code -eq 0 ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: New APPS password updated in EbsDataSource Successfully. " | tee -a  "${mainlog}"
	elif [[  $exit_code -eq 1 ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Datasource password update failed, Invalid credentials passed. " | tee -a  "${mainlog}"
		exit 1
	else
	    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: EbsDataSource Update Status Could not be identified.  " | tee -a  "${mainlog}"
		exit 1
	fi

	if [[ "${workwlspass}" == "${WLSPASS}" ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: **** Weblogic Password is already changed. **** " | tee -a  "${mainlog}"
	elif [   "${workwlspass}" != "${WLSPASS}" ]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Changing Weblogic Password (IGNORE stty errors).  " | tee -a  "${mainlog}"
		{ echo "Yes" ; echo "${CONTEXT_FILE}" ; echo "${workwlspass}" ; echo "${WLSPASS}" ; echo "${workappspass}" ;} | perl "${FND_TOP}"/patch/115/bin/txkUpdateEBSDomain.pl -action=updateAdminPassword > "${log_dir}"/WLS_password_changeRunfs1."${startdate}" 2>&1
		exit_code=$?;
		if [[ $exit_code -eq 0 ]]; then
			sleep 2
			echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: **** Weblogic Password is changed successfully. **** " | tee -a  "${mainlog}"
			workwlspass=${WLSPASS}
		elif [[   $exit_code -ne 0 ]] ; then
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Error received while changing weblogic password. Please check. " | tee -a  "${mainlog}"
		else
		  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Weblogic Password change status could not be validated, make sure you verify." | tee -a  "${mainlog}"
		fi
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Both weblogic passwords are invalid. " | tee -a  "${mainlog}"
	fi

	# Autoconfig run
	run_autoconfig
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: Stopping ADMINSERVER on Application Node. " | tee -a  "${mainlog}"
	{ echo "${workwlspass}" ; echo "${workappspass}" ; } | "${ADMIN_SCRIPTS_HOME}"/adadminsrvctl.sh stop '-nopromptmsg'  > "${log_dir}"/stopAdminServerRunfs4."${startdate}" 2>&1
	exit_code=$?
	if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 2 ]] ; then
	sleep 2
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: AdminServer is down for runfs. " | tee -a  "${mainlog}"
		workwlspass=${WLSPASS}
	elif [[ $exit_code -eq 9  ]] || [[ $exit_code -eq 1 ]]; then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WLS PASS CHANGE: ERROR: Target Weblogic password is also Invalid. Please validate the passwords." | tee -a  "${mainlog}"
		exit 1
	fi

	# Changing other Application passwords.
	change_other_application_password
	}


	xxexpd_top_softlink()
	{
   if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
     source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
   else
     echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CUSTOM SOFTLINKS: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
     update_clonersp "session_state" "FAILED"
     exit 1
   fi
  source "${clonerspfile}" > /dev/null 2>&1

	# Create SOFTLINKS in XXEXPD_TOP
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CUSTOM SOFTLINKS: Create SOFTLINKS in XXEXPD_TOP. " | tee -a  "${mainlog}"
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CUSTOM SOFTLINKS: Logfile: ${log_dir}/xxexpd_top_softlinks.${startdate} " | tee -a  "${mainlog}"
	cd "${XXEXPD_TOP}"/bin

	case ${XXEXPD_TOP} in
	*xxexpd* )
	   cd "${XXEXPD_TOP}"/bin
	   sh  ./recreate_softlink_runFS.sh  > "${log_dir}"/xxexpd_top_softlinks."${startdate}"
	  ;;
	* ) echo "Error : XXEXPD_TOP not set, Softlinks not created !!"  ;;
	esac
	sleep 2
	update_clonersp "appssoftlink" "COMPLETED"
  source "${clonerspfile}" > /dev/null 2>&1

	}

	gen_custom_env()
	{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CUSTOM ENV: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1
	####### Create RUN and PATCH fs Custom env file
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: Create RUN and PATCH fs Custom env file. " | tee -a  "${mainlog}"
	if [[ -f "${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env" ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: Runfs Custom ENV exits as ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env. " | tee -a  "${mainlog}"
	else
		echo "export XXEXPD_PMTS=/u05/oracle/BANKS/${trgappname}/Payments"  > ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_DD=/u05/oracle/BANKS/${trgappname}/DirectDebit" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export PATH=/u04/oracle/perforce:\$PATH:/dba/bin" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export P4PORT=tcp:perforce:1985"  >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_TOP_NE=/u04/oracle/R12/${trgappname}/XXEXPD/12.0.0" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export CONFIG_JVM_ARGS=\"-Xms2048m -Xmx4096m\""  >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_JAVA11_HOME=/usr/local/jdk11" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXGAH_TOP_NE=/u04/oracle/R12/${trgappname^^}/XXGAH/12.0.0" >> ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		chmod 775 "${RUN_BASE}"/inst/apps/"${CONTEXT_NAME}"/appl/admin/custom"${CONTEXT_NAME}".env >/dev/null 2>&1
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: Runfs Custom ENV created as : " | tee -a  "${mainlog}"
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: ${RUN_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env. " | tee -a  "${mainlog}"
	fi

	if [[ -f "${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env" ]]; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: Patchfs Custom ENV exits as ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env" | tee -a  "${mainlog}"
	else
		echo "export XXEXPD_PMTS=/u05/oracle/BANKS/${trgappname}/Payments"  > ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_DD=/u05/oracle/BANKS/${trgappname}/DirectDebit" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export PATH=/u04/oracle/perforce:\$PATH:/dba/bin" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export P4PORT=tcp:perforce:1985"  >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_TOP_NE=/u04/oracle/R12/${trgappname}/XXEXPD/12.0.0" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export CONFIG_JVM_ARGS=\"-Xms2048m -Xmx4096m\""  >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXEXPD_JAVA11_HOME=/usr/local/jdk11" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		echo "export XXGAH_TOP_NE=/u04/oracle/R12/${trgappname^^}/XXGAH/12.0.0" >> ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env
		chmod 775 "${PATCH_BASE}"/inst/apps/"${CONTEXT_NAME}"/appl/admin/custom"${CONTEXT_NAME}".env >/dev/null 2>&1
		echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: Patchfs Custom ENV created as : " | tee -a  "${mainlog}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Custom ENV: ${PATCH_BASE}/inst/apps/${CONTEXT_NAME}/appl/admin/custom${CONTEXT_NAME}.env. " | tee -a  "${mainlog}"
	fi
	}

	compile_jsp()
	{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CUSTOM JSP: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Compile JSP: Compiling JSP - Will take 10mins." | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Compile JSP: Logfile: ${log_dir}/Compile_jsp${trgappname^^}.${startdate}" | tee -a  "${mainlog}"
	# Compiling JSP
	perl "${FND_TOP}"/patch/115/bin/ojspCompile.pl --compile --flush -p 80 > "${log_dir}"/Compile_jsp"${trgappname^^}"."${startdate}" 2>&1
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:Compile JSP: Compiling JSP - COMPLETED." | tee -a  "${mainlog}"
	}


	run_app_etcc()
	{
	  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
      source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP ETCC JSP: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
      update_clonersp "session_state" "FAILED"
      exit 1
    fi

  source "${clonerspfile}" > /dev/null 2>&1

	#gives workappspass
	validate_working_apps_password
	cd "${common_home}/etcc/"
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP ETCC JSP: Running ETCC on application node." | tee -a  "${mainlog}"
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP ETCC JSP: Logfile: ${log_dir}/appnode_etcc_${trgappname^^}.${startdate}" | tee -a  "${mainlog}"
	{ echo "${workappspass}" ; } | sh "${common_home}"/etcc/checkMTpatch.sh  > "${log_dir}"/appnode_etcc_"${trgappname^^}"."${startdate}" 2> /dev/null  &
	sleep 2
	}




misc_housekeeping()
{

  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:MISC APP: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1

  if [[ "${appmiscsteps}" != "COMPLETED"  ]] || [[ -z "${appmiscsteps}" ]]; then
  xxexpd_top_softlink
  gen_custom_env
  compile_jsp
  run_app_etcc

  update_clonersp "appmiscsteps" "COMPLETED"
  source "${clonerspfile}" > /dev/null 2>&1
  fi
}

	user_password_reset()
	{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi

  source "${clonerspfile}" > /dev/null 2>&1
	#gives workappspass
	validate_working_apps_password

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Generating Application User Password reset scripts." | tee -a  "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Script: ${log_dir}/${trgappname^^}_resetpassword_fnd_user.sh" | tee -a  "${mainlog}"

sqlplus -s apps/"${workappspass}"@"${trgappname^^}" << EOF > /dev/null
set head off
set feed off
set line 999
set pages 200
set lines 300

spool ${log_dir}/${trgappname^^}_resetpassword_fnd_user.sh
select '. /home/applmgr/.'||lower('${trgappname,,}')||'_profile  > /dev/null' from dual;
select '  FNDCPASS apps/${workappspass} 0 Y system/${SYSTPASS} USER  '|| USER_NAME || ' welcome123 '  from fnd_user where last_logon_date >= sysdate-120 or trunc(creation_date)=trunc(sysdate)
and end_date is null and user_name
not in ('AME_INVALID_APPROVER','APPLSYS','APPS','XXEXPD',
'ANONYMOUS',
'APPSMGR',
'ASADMIN',
'ASGADM',
'ASGUEST',
'AUTOINSTALL',
'CHAINSYS',
'CONCURRENT MANAGER',
'CORP_CONVERSION',
'CTLMSCHD',
'CTLMSCHD2',
'EXPD_INT',
'FEEDER SYSTEM',
'GUEST',
'IBE_ADMIN',
'IBE_GUEST',
'IBEGUEST',
'IEXADMIN',
'INITIAL SETUP',
'IRC_EMP_GUEST',
'IRC_EXT_GUEST',
'MERCH_CONVERSION',
'MOBILEADM',
'MOBILEDEV',
'OAMACCESS',
'OP_CUST_CARE_ADMIN',
'OP_SYSADMIN',
'PORTAL30',
'PORTAL30_SSO',
'STANDALONE BATCH PROCESS',
'SYSADMIN',
'VBANK_CONVERSION',
'WIZARD',
'XML_USER');
spool off

exit
EOF

  if [[ -f "${log_dir}/${trgappname^^}_resetpassword_fnd_user.sh" ]]; then
	  sed -i '/SYSADMIN/d' "${log_dir}"/"${trgappname^^}"_resetpassword_fnd_user.sh
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: ****************** Resetting FND User Passwords  ***********************************" | tee -a  "${mainlog}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Logfile: ${log_dir}/${trgappname^^}_resetpassword_fnd_user.${startdate}" | tee -a  "${mainlog}"
	  sh "${log_dir}"/"${trgappname^^}"_resetpassword_fnd_user.sh > "${log_dir}"/reset_user_password"${trgappname^^}"."${startdate}"  2>&1
	  sleep 2
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Password reset script: COMPELTED" | tee -a  "${mainlog}"
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER PASS CHANGE: Password reset script not found, FND USER Password reset could not be completed." | tee -a  "${mainlog}"
  fi

	}


fnd_upload()
{

  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND UPLOAD: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1

	if [[ ! -d "${log_dir}/uploadlog" ]] ; then
		mkdir -p "${log_dir}/uploadlog" >/dev/null 2>&1
	fi

	cd "${log_dir}/uploadlog"

	if [[ -f "${uploaddir}/fnd_lookups/app_upload_fndlookup.sh" ]] ; then
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND LOOKUP: Uploading FND Lookups. " | tee -a  "${mainlog}"
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND LOOKUP: Logfile: ${log_dir}/Upload_lookups${trgappname^^}.${startdate} " | tee -a  "${mainlog}"
	  sh "${uploaddir}"/fnd_lookups/app_upload_fndlookup.sh  > "${log_dir}"/Upload_lookups"${trgappname^^}"."${startdate}"  2>&1
	  update_clonersp "appsfndlookup" "COMPLETED"
    source "${clonerspfile}" > /dev/null 2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND LOOKUP: Uploading FND Lookups - COMPLETED " | tee -a  "${mainlog}"
	else
	  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND LOOKUP: Uploading script not found. FND LOOKUPS will not be uploaded. " | tee -a  "${mainlog}"
  fi

  if [[ -f "${uploaddir}/fnd_users/app_upload_fnd_user.sh" ]] ; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER RESP: Uploading FND User Responsibilities. " | tee -a  "${mainlog}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER RESP: Logfile: ${log_dir}/Upload_fnd_userResp${trgappname^^}.${startdate} " | tee -a  "${mainlog}"
    sh "${uploaddir}"/fnd_users/app_upload_fnd_user.sh  > "${log_dir}"/Upload_fnd_userResp"${trgappname^^}"."${startdate}"
    update_clonersp "appsfnduserresp" "COMPLETED"
    source "${clonerspfile}" > /dev/null 2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER RESP: Uploading FND User Responsibilities. - COMPLETED " | tee -a  "${mainlog}"
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND USER RESP: Uploading FND User Responsibilities.script not found. FND USER RESP will not be uploaded. " | tee -a  "${mainlog}"
  fi

	rm -f L*.log  /home/applmgr/L*.log >/dev/null 2>&1
	rm -f "${log_dir}"/uploadlog/L*log >/dev/null 2>&1
	user_password_reset

}

	compileinvalids()
	{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:COMPILE INVALIDS: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:COMPILE INVALIDS: Compiling invalid objects." | tee -a  "${mainlog}"
	export SYSTUSER=$(/dba/bin/getpass "${trgappname^^}" system)
	export SYSTPASS=$(echo "${SYSTUSER}" | cut -d/ -f 2)

sqlplus  sys/"${SYSTPASS}@${trgappname}" 'as sysdba'  << EOF > /dev/null
set echo on ;
spool ${log_dir}/spool_CompileInvalidObjects${trgappname^^}.${startdate}
exec sys.utl_recomp.recomp_parallel(10) ;
exec sys.utl_recomp.recomp_parallel(10) ;
exec sys.utl_recomp.recomp_parallel(10) ;
SPOOL OFF ;
exit
EOF
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:COMPILE INVALIDS: Compiling invalid objects: COMPLETED" | tee -a  "${mainlog}"
	}

start_application()
{
  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
  source "${clonerspfile}" > /dev/null 2>&1

  export APPSUSER=$(/dba/bin/getpass "${trgappname^^}" apps)
  export APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
  export WLSUSER=$(/dba/bin/getpass "${trgappname^^}" weblogic)
  export WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)

  unpw="${APPSUSER}@${trgappname}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

  if [[ $? -ne 0 ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: APPS passwords are not working, Application services will not be started." | tee -a  "${mainlog}"
    exit 1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: *******  APPS Password is working  *******" | tee -a  "${mainlog}"
  fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: Starting Application services on ${HOST_NAME}" | tee -a  "${mainlog}"

  { echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstrtal.sh  -nopromptmsg > "${log_dir}"/startApplication"${HOST_NAME}"."${startdate}"
  if [[ ${?} -gt 0 ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: ERROR: Could not start all application services on ${HOST_NAME}" | tee -a  "${mainlog}"
  	exit 1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP START SERVICES: Application services start completed successfully on ${HOST_NAME}" | tee -a  "${mainlog}"
  	sleep 2
  fi

  update_clonersp "startapplication" "COMPLETED"
  source "${clonerspfile}" > /dev/null 2>&1
}

final_steps()
{

  if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
    source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP FINAL: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
    update_clonersp "session_state" "FAILED"
    exit 1
  fi
source "${clonerspfile}" > /dev/null 2>&1
compileinvalids
run_autoconfig
start_application
#start_concurrent_manager
}

#******************************************************************************************************##
##	Execute application steps
#******************************************************************************************************##
SRCAPPSPASS=$1
SRCWLSPASS=$2

if [[ "${current_task_id}" -ge 600 ]]  && [[ "${current_task_id}"  -le 2900 ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APP TASK ID CHECK: TASK ID is out of range for Application script execution."
  exit 1
fi

mainlog="${log_dir}"/mainlogapplication."${startdate}"

for task in $(seq "${current_task_id}" 1 5000 )
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
          update_clonersp "current_task_id" "1000"
          update_clonersp "current_module_task" "${current_task_id}"
          exit 0  ;;

    "3000")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START MODULE:RESTORE APP "
          update_clonersp "current_task_id" 3100 ;;
    "3100")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          run_adcfgclone
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "3500" ;;
    "3500")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END MODULE:RESTORE APP "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "4000"
          update_clonersp "current_module_task" "${current_task_id}"  ;;
    "4000")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START MODULE:POST APP RESTORE "
          if [[ -f "/home/$(whoami)/.${trgappname,,}_profile" ]]; then
            source /home/"$(whoami)"/."${trgappname,,}"_profile  >/dev/null 2>&1
          else
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:POST APP RESTORE: Target Env file not found. Exiting !! "  | tee -a "${appextractlog}"  "${mainlog}"
            update_clonersp "session_state" "FAILED"
            exit 1
          fi
          source "${clonerspfile}" > /dev/null 2>&1
          update_clonersp "current_task_id" 4100 ;;
    "4100")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          postadcfgclone
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "4200" ;;
    "4200")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          change_runfs_password
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "4300" ;;
    "4300")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          misc_housekeeping
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "4400" ;;
    "4400")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          fnd_upload
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "4500" ;;
    "4500")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          final_steps
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "5000" ;;
    "5000")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S")${HOST_NAME}:${current_task_id}:END MODULE:RESTORE APP "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" "5000"
          update_clonersp "current_module_task" "${current_task_id}"  ;;

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