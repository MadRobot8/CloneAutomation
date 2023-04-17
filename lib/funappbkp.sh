#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/10 dikumar funappbkp.sh
#  Purpose  : Function to request ad-hoc archive backup from source database
#
#  SYNTAX   :  Submit backup for application
#              req_appbkp <Source instance name> <archive log backup location>
#              req_appbkp GAHPRD /backuprman/ebs_backups/GAHPRD/app_tar
#
#              Check backup status
#              getappbkpstatus <Source Application Backup location>  <oem node log dir> <parallel flag>
#              getappbkpstatus /backuprman/ebs_backups/GAHPRD/app_tar /u05/oracle/autoclone/log/oem/CLONEDB  2
#              Note: parallel flag = 1 or 2
#                               1 = When checked serially, no other task is running in parallel
#                               2 = When checked parallel, when db restore or any other script is running parallel
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  R E Q U E S T - A D - H O C - A P P L I C A T I O N - F U N - S C R I P T **********
#******************************************************************************************************##

req_appbkp()
{
dbupper="${1^^}"
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
vappbkplocation="${2}"

if [ -f "${vappbkplocation}"/adhoc.complete ]; then
  rm -f "${vappbkplocation}"/adhoc.complete > /dev/null 2>&1
fi

date > "${vappbkplocation}"/adhoc.request
${ECHO} "APP BKP: Ad-hoc application backup is submitted for ${dbupper}. "
${ECHO} "APP BKP: application backup will run in parallel while clone script is running. "
return 0
}

getappbkpstatus()
{

HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
vappbkplocation="${1}"
vappbkpstateresult="${2}"
p_flag=$3

if [ "${p_flag}" = 1 ]; then
# Check for ad-hoc backup completion.
  while [ ! -f "${vappbkplocation}"/pull.completed  ];
  do
  sleep 10m
  if [ -f "${vappbkplocation}"/adhoc.error ]; then
  ${ECHO} "APP BKP: Ad-hoc application backup has failed for ${dbupper}. "
  echo "failed" > "${vappbkpstateresult}"/adhocappbkp.state
    break
  fi
  done
fi


if [ "${p_flag}" = 2 ]; then
# Check for ad-hoc backup completion.
  if [ ! -f "${vappbkplocation}"/pull.completed  ]; then
    if [ -f "${vappbkplocation}"/adhoc.error ]; then
      ${ECHO} "APP BKP: Ad-hoc application backup has failed for ${dbupper}. "
      echo "failed" > "${vappbkpstateresult}"/adhocappbkp.state
      return 1
    fi
    ${ECHO} "APP BKP: Ad-hoc application backup has failed for ${dbupper}. "
    return 0
  fi
fi

if [ -f "${vappbkplocation}"/pull.completed ] ; then
  ${ECHO} "APP BKP: Ad-hoc application backup is completed for ${dbupper}. "
  echo "success" > "${vappbkpstateresult}"/adhocappbkp.state
fi

return 0
}


##******************************************************************************************************##
#  **********  R E Q U E S T - A D - H O C - A P P L I C A T I O N - B A C K U P - F U N - E N D **********
#**********************************************************************************