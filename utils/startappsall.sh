#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to start application tier services and kill leftover sessions.
#
#  SYNTAX   : sh startappsall.sh instance
#             sh startappsall.sh ORASUP
#
#  Author   : Dinesh Kumar
#
#  Synopsis : This script will perform following operations
#			  1.
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - S T A R T - A L L - N O D E S - S C R I P T **********
#
#******************************************************************************************************##

#******************************************************************************************************#
#	Local variable declaration.
#******************************************************************************************************#
dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
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
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

envfile="${etc_home}"/properties/"${dbupper}".prop
if [ ! -f "${envfile}" ];  then
    ${ECHO} "ERROR: Target Environment instance.properties file not found.\n"  | tee -a "${logf}"
    exit 1;
else
    source "${etc_home}"/properties/"${dbupper}".prop
    sleep 2
fi
unset envfile

apphost2="${trgapphost2}"
apphost3="${trgapphost3}"
apphost4="${trgapphost4}"

APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
WLSUSER=$(/dba/bin/getpass "${dbupper}" weblogic)
WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)
export APPSUSER APPSPASS WLSUSER WLSPASS
echo $APPSUSER

#unpw="${APPSUSER}@${dbupper}"

sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${APPSUSER}
exit
EOF

if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: WARNING: APPS passwords are not working, script will be exit." | tee -a "${logf}"
   exit 1
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: *******  APPS Password is working  *******" | tee -a "${logf}"

echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Starting Application services on ${HOST_NAME}. " | tee -a "${logf}"
{ echo "apps" ; echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | "${ADMIN_SCRIPTS_HOME}"/adstrtal.sh  -nopromptmsg  >  "${logf}" 2>&1
if [ ${?} -gt 0 ]; then
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: ERROR: Could not start all application services. " | tee -a "${logf}"
	exit 1
else
	echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Application services start completed successfully. " | tee -a "${logf}"
	sleep 2
fi

if [ -n "${apphost2}" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Starting Application services on ${apphost2}. " | tee -a "${logf}"
  ssh -q  applmgr@"${apphost2}"."${labdomain}"  " nohup sh ${util_home}/startapps.sh  ${dbupper}   "
  if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Application services did not completed successfully at ${apphost2}. \n" | tee -a "${logf}"
  fi
fi

sleep 2

if [ -n "${apphost3}" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Starting Application services on ${apphost3}. " | tee -a "${logf}"
  ssh -q  applmgr@"${apphost3}"."${labdomain}"  " nohup sh ${util_home}/startapps.sh  ${dbupper}   "
  if [ $? -ne 0 ]; then
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Application services did not completed successfully at ${apphost3}. \n"  | tee -a "${logf}"
  fi
fi
sleep 2

if [ -n "${apphost3}" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: APP START APPLICATION: Starting Application services on ${apphost4}. "  | tee -a "${logf}"
  ssh -q  applmgr@"${apphost4}"."${labdomain}"  " nohup sh ${util_home}/startapps.sh  ${dbupper}   "
  if [ $? -ne 0 ]; then
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Application services did not completed successfully at ${apphost4}. \n"  | tee -a "${logf}"
  fi
fi
sleep 2

exit


#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - S T A R T - A L L - N O D E S - S C R I P T - E N D **********
#
#******************************************************************************************************##