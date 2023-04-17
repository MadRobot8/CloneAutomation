#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to restore application backup to application tier.
#
#  SYNTAX   : sh appsautoconfig.sh instance
#             sh appsautoconfig.sh ORASUP
#
#  Author   : Dinesh Kumar
#
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#  Execution summary:

#******************************************************************************************************#
#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - A U T O C O N F I G - S C R I P T **********
#
#******************************************************************************************************##
#******************************************************************************************************#
#	Local variable declaration.
#******************************************************************************************************#

dbupper=${1^^}
dblower=${dbupper,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
unset envfile
envfile="/home/$(whoami)/.${dblower}_profile"
if [ ! -f "${envfile}" ]; then
  echo -e "ERROR: Target Environment profile ${envfile} file not found. while checking Database status\n"
  exit 1;
else
  source "${envfile}" > /dev/null
  sleep 2
fi

export APPSUSER=$(/dba/bin/getpass "${dbupper}" apps)
export APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)
export WLSUSER=$(/dba/bin/getpass "${dbupper}" weblogic)
export WLSPASS=$(echo "${WLSUSER}" | cut -d/ -f 2)

unpw="${APPSUSER}@${dbupper}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): WARNING: APPS passwords are not working, autoconfig will be skipped."
   exit 1
fi

echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): *******  APPS Password is working  *******"
echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): *******  Running autoconfig locally.  *******"
echo "${APPSPASS}"
sh "${ADMIN_SCRIPTS_HOME}"/adautocfg.sh  appspass="${APPSPASS}"
if [ $? -ne 0 ]; then
   echo -e  "$(date +"%d-%m-%Y %H:%M:%S"): $(hostname): Autoconfig did not completed successfully. \n"
   exit 1
fi

sed -i '/^connection/d' "${EBS_DOMAIN_HOME}"/config/config.xml   >/dev/null

exit 0

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - A U T O C O N F I G - S C R I P T - E N D **********
#
#******************************************************************************************************##




