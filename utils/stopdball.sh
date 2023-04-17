#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to stop all database services and listener.
#
#  SYNTAX   : sh stopdball.sh instance
#             sh stopdball.sh ORASUP
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
#   Source env and properties file
#******************************************************************************************************#

envfile="${etc_home}"/properties/"${dbupper}.prop"
echo ${envfile}
if [ ! -f "${envfile}" ];  then
    ${ECHO} "ERROR: Target Environment instance.properties file not found.\n" | tee -a "${logf}"
    exit 1;
else
    source "${etc_home}"/properties/"${dbupper}".prop
    sleep 2
fi
unset envfile

envfile=/home/"$(whoami)"/."${trgcdbname,,}"_profile
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n" | tee -a "${logf}"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

#******************************************************************************************************#
#   Stop node2 DB services first
#******************************************************************************************************#
dbhost2="${trgdbhost2}"

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Stopping database on remote node ${dbhost2}" | tee -a "${logf}"

if [ -n "${dbhost2}" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): DB STOP APPLICATION: Stopping Application services on ${apphost2}. " | tee -a "${logf}"
  ssh -q  oracle@"${dbhost2}"."${labdomain}"  " nohup sh ${util_home}/stopdb.sh  ${trgcdbname}   "
  if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): DB Database services stop did not completed successfully at ${apphost2}. \n" | tee -a "${logf}"
  fi
fi

sleep 2

#******************************************************************************************************#
#   Stop Node 1 DB services.
#******************************************************************************************************#
dbhost1="${trgdbhost}"

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Stopping database on remote node ${dbhost2}"  | tee -a "${logf}"

if [ -n "${dbhost1}" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): DB STOP APPLICATION: Stopping Application services on ${dbhost1}. " | tee -a "${logf}"
  ssh -q  oracle@"${dbhost1}"."${labdomain}"  " nohup sh ${util_home}/stopdb.sh  ${trgcdbname}   "
  if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(HOST_NAME): DB Database services stop did not completed successfully at ${dbhost1}. \n" | tee -a "${logf}"
  fi
fi

sleep 2



#******************************************************************************************************#
#   Stop srvctl services if any
#******************************************************************************************************#
${ORACLE_HOME}/bin/srvctl stop service -d "${dbupper}"  > ${logf}
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Remote database stop script completed. "  | tee -a "${logf}"

exit


#******************************************************************************************************##
#  **********  D A T A B A S E - S T O P - S C R I P T - E N D **********
#******************************************************************************************************##