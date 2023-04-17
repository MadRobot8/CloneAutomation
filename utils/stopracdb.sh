#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to stop application tier services and kill leftover sessions.
#
#  SYNTAX   : sh stopracdb.sh instance
#             sh storre.sh ORASUP
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
#  **********  D A T A B A S E - R E M O T E - N O D E - S T O P - S C R I P T - S T A R T ***********
#******************************************************************************************************##

#******************************************************************************************************#
#	Local variable declaration.
#******************************************************************************************************#
dbupper=${1^^}
dblower=${1,,}
HOST_NAME=$(uname -n | cut -f1 -d".")

envfile=/home/"$(whoami)"/."${dblower}"_profile
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Checking for Target Database processes"
if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -gt 0 ] ; then
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database processes are running."
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Stopping ${ORACLE_SID} on ${HOST_NAME}."
sqlplus -s '/ as sysdba'  << EOF > /dev/null
SHUTDOWN ABORT;
spool off
exit
EOF

"${ORACLE_HOME}"/bin/lsnrctl stop "${dbupper}"
  if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -lt 2 ] ; then
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database is stopped."
  fi

else
  sleep 30   # Wait for 1 minutes
   if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -gt 0 ] ; then
sqlplus -s '/ as sysdba'  << EOF > /dev/null
SHUTDOWN ABORT;
spool off
exit
EOF

"${ORACLE_HOME}"/bin/lsnrctl stop "${dbupper}"

  if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
    echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database is stopped."
  fi

elif [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
    "${ORACLE_HOME}"/bin/lsnrctl stop "${dbupper}"
      if [ $(ps -fu oracle |grep smon |grep -ic "${dbupper}" ) -eq 0 ] ; then
        echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: ${ORACLE_SID} Database is stopped."
      fi
   else
           echo " " > /dev/null
   fi
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Remote database stop script completed. "

exit


#******************************************************************************************************##
#  **********  D A T A B A S E - R E M O T E - N O D E - S T O P - S C R I P T - E N D **********
#******************************************************************************************************##