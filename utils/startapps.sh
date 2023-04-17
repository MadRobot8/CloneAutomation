#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to stop application tier services and kill leftover sessions.
#
#  SYNTAX   : sh startapps.sh instance
#             sh startapps.sh ORASUP
#
#  Author   : Dinesh Kumar
#
#  Synopsis : This script will perform following operations
#			  1.
#
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - S T O P - S C R I P T **********
#
#******************************************************************************************************##

#******************************************************************************************************#
#
#	Local variable declaration.
#
#******************************************************************************************************#
dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
startdate=$(date '+%Y%m%d')
scr_home=/u05/oracle/autoclone
etc_home="${scr_home}/etc"
bin_home="${scr_home}/bin"
lib_home=${scr_home}/lib
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"
log_home="${scr_home}"/log/${dbupper^^}/startup

mkdir -p "${log_home}"  > /dev/null 2>&1
chmod -R 775  "${log_home}" >/dev/null 2>&1
logf=${log_home}/startApplication_"${HOST_NAME}"."${startdate}"

#******************************************************************************************************#
#
# Fetch and validate APPS password.
#
#******************************************************************************************************#

envfile="/home/$(whoami)/.${dblower}_profile"
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n" | tee -a "${logf}"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
WLSUSER=$(/dba/bin/getpass "${dbupper}" weblogic)
WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)
export APPSUSER APPSPASS WLSUSER WLSPASS

unpw="${APPSUSER}@${dbupper}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: WARNING: APPS passwords are not working, script will be exit." | tee -a "${logf}"
   exit 1
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: *******  APPS Password is working  *******" | tee -a "${logf}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Starting Application services on ${HOST_NAME}. " | tee -a "${logf}"
{ echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstrtal.sh  -nopromptmsg >  "${logf}" 2>&1
if [ ${?} -gt 0 ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: ERROR: Could not start all application services. " | tee -a "${logf}"
	exit 1
else
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Application services start completed successfully. " | tee -a "${logf}"
	sleep 2
fi

exit


#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - S T A R T - S C R I P T - E N D **********
#
#******************************************************************************************************##