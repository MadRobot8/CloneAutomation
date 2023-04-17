#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to stop local Container database and listener.
#
#  SYNTAX   : sh stopdb.sh instance
#             sh stopdb.sh ORACSUP   <<== Please not it is CDB name
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
#  **********  D A T A B A S E - S T O P - S C R I P T - S T A R T ***********
#******************************************************************************************************##

#******************************************************************************************************#
#	Local variable declaration.
#******************************************************************************************************#
dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
startdate=$(date '+%Y%m%d')
scr_home=/u05/oracle/autoclone
util_home="${scr_home}/utils"
log_home="${scr_home}"/log/${dbupper^^}/startup

mkdir -p "${log_home}"  > /dev/null 2>&1
chmod -R 775  "${log_home}" >/dev/null 2>&1
logf=${log_home}/stopDatabase_"${HOST_NAME}"."${startdate}"

#******************************************************************************************************#
#   Source env file
#******************************************************************************************************#
envfile=/home/"$(whoami)"/."${dblower}"_profile
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n" | tee -a "${logf}"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

#******************************************************************************************************#
#   Stop local DB services
#******************************************************************************************************#

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: DB Stopping listener processes" | tee -a "${logf}"
"${ORACLE_HOME}"/bin/lsnrctl stop "${dbupper}"  > /dev/null 2>&1

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Checking for Target Database processes" | tee -a "${logf}"
if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -gt 0 ] ; then
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database processes are running." | tee -a "${logf}"
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Stopping ${ORACLE_SID} on ${HOST_NAME}." | tee -a "${logf}"
sqlplus -s '/ as sysdba'  << EOF > /dev/null
SHUTDOWN IMMEDIATE;
spool off
exit
EOF

  if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database is stopped." | tee -a "${logf}"
  fi

elif [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
    "${ORACLE_HOME}"/bin/lsnrctl stop "${dbupper}"  > /dev/null 2>&1
      if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
        echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database is stopped." | tee -a "${logf}"
      fi
else
           echo " " > /dev/null
fi

${ORACLE_HOME}/bin/srvctl stop service -d "${dbupper}" > /dev/null 2>&1
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Remote database stop script completed. " | tee -a "${logf}"

exit


#******************************************************************************************************##
#  **********  D A T A B A S E - S T O P - S C R I P T - E N D **********
#******************************************************************************************************##