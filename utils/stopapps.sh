#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to stop application tier services and kill leftover sessions.
#
#  SYNTAX   : sh stopapps.sh instance lod_dir
#             sh stopapps.sh ORASUP /u05/oracle/autoclone/ORASUP/log/01-JAN-2023
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
#  **********  A P P L I C A T I O N - S T O P- S C R I P T **********
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
scr_home=/u05/oracle/autoclone
util_home="${scr_home}/utils"
log_dir="${scr_home}"/instance/"${dbupper}"/log/extract

mkdir -p "${log_home}"  > /dev/null 2>&1
chmod -R 775  "${log_home}"  > /dev/null 2>&1
logf=${log_dir}/stopApplication_"${HOST_NAME}"."${startdate}"

#******************************************************************************************************#
# Fetch and validate APPS password.
#******************************************************************************************************#

envfile=/home/"$(whoami)"/."${dblower}"_profile
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
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
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): WARNING: APPS passwords are not working, script will be exit."
   exit 1
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): *******  APPS Password is working  *******"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): APP STOP APPLICATION: Stopping Application services on ${HOST_NAME}. "
{ echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstpall.sh  -nopromptmsg  >  "${logf}" 2>&1
if [ ${?} -gt 0 ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): APP STOP APPLICATION: ERROR: Could not stop all application services. "
	exit 1
else
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): APP STOP APPLICATION: Application services stop completed successfully. "
	sleep 2
fi

exit


#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - S T O P - S C R I P T - E N D **********
#
#******************************************************************************************************##