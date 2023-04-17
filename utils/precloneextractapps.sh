#!/bin/bash
#***************************************************************************************************#
#	Purpose    :  Script to extract/backup important files/details.
#   Script name:  precloneextractapps.sh
#   Usage      :  sh  precloneextractapps.sh <instance name>
#                 sh  precloneextractapps.sh ORASUP
#   Remarks    :  Ideally this script should be setup in crontab to have Extract run in advance.
#
#   $Header 1.2 2022/03/23 dikumar $
#   $Header 1.3 context file values backup addition 2022/03/23 dikumar $  
#***************************************************************************************************#

#***************************************************************************************************#
#  **********    A P P L I C A T I O N - E X T R A C T - S C R I P T   **********
#***************************************************************************************************#

#***************************************************************************************************##
#       Assigning Local variables.
#***************************************************************************************************#

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
if [ ! -f ${envfile} ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="/home/$(whoami)/.${dblower}_profile"
if [ ! -f "${envfile}" ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "ERROR: Target Environment profile ${envfile} file not found on application server.\n"
	exit 1;
else
	source "${envfile}" > /dev/null
	sleep 1
fi

#******************************************************************************************************##
#  Creating needed directories
#******************************************************************************************************##

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
#***************************************************************************************************###
# Cleaning up old scripts and creating new extract scripts from Database for Post clone Upload part.
#***************************************************************************************************###

log_dir="${extractlogdir}"
appextractlog="${log_dir}"/extractApplication"${dbupper^^}".log
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: logfile for this session is at  ${HOST_NAME}" | tee "${appextractlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:           ${appextractlog}. " | tee -a "${appextractlog}"

cd "${extractdir}"
if [ -d "${currentextractdir}" ] ; then
		cp -pr  "${currentextractdir}"  "${bkpextractdir}"/$(date +'%d-%m-%Y') > /dev/null
fi

mkdir -p "${currentextractdir}"  > /dev/null 2>&1
#***************************************************************************************************###
# Extracting sql from database
#***************************************************************************************************###

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP EXTRACT      : ***** Running Extraction for Post Clone Scripts.  *****" | tee -a "${appextractlog}"

export APPUSER=$(/dba/bin/getpass "${dbupper}" apps)
export APPPASS=$(echo "${APPUSER}" | cut -d/ -f 2)

sqlplus -s "${APPUSER}"@"${dbupper}"  << EOF > /dev/null
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

#***************************************************************************************************###
#  Backup important files, to be restored as post clone process
#***************************************************************************************************###

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: *****   Extracting TNS, CONTEXT, ENV, Certs files from Application node.   *****"  | tee -a "${appextractlog}"
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
	cp  -p  ${FND_SECURE}/*.dbc  "${currentextractdir}"/app_others/dbc/.  > /dev/null 2>&1
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

#***************************************************************************************************###
#  Executing Extract scripts
#***************************************************************************************************###

    cd "${log_dir}"

    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP EXTRACT      : *****   Executing FND Lookup Extracts...   *****" | tee -a "${appextractlog}"
    sh  "${currentextractdir}"/app_fnd_lookup/app_extract_fndlookup.sh  > "${log_dir}"/extract_lookup"${dbupper^^}".log  2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP EXTRACT      : *****   Executing FND User Extracts...   *****"  | tee -a "${appextractlog}"
    sh "${currentextractdir}"/app_fnd_user/app_extract_fnd_user.sh   >  "${log_dir}"/extract_users"${dbupper^^}".log  2>&1

    rm -f L*.log
    rm -f "${log_dir}"/L*.log

    #Cleaning up backup files older than 100 days.
    #find "${bkpextractdir}" -type d -mtime +100 -exec rm -rf {}\; >/dev/null 2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: APP EXTRACT      : ***** $(basename $0) Scripts completed   *****"  | tee -a "${appextractlog}"

    sleep 1
    exit
#***************************************************************************************************###
#
#  **********   E N D - O F - A P P L I C A T I O N - E X T R A C T - S C R I P T   **********
#
#***************************************************************************************************###