#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/10 dikumar fundbarchivebkp.sh
#  Purpose  : Function to request ad-hoc archive backup from source database
#  SYNTAX   :  getdbarchivebkp <Source instance name> <archive log backup location> <oem node log dir>
#
#              getdbarchivebkp GAHPRD /backuprman/ebs_backups/GAHPRD/archivelogs /u05/oracle/autoclone/log/oem/CLONEDB
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  R E Q U E S T - A D - H O C - A R C H I V E - F U N - S C R I P T **********
#******************************************************************************************************##

getdbarchivebkp()
{
dbupper="${1^^}"
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
varchbkplocation="${2}"
vstateresult="${3}"

if [ -f "${varchbkplocation}"/adhocarch.complete ]; then
  rm -f "${varchbkplocation}"/adhocarch.complete > /dev/null 2>&1
fi

date > "${varchbkplocation}"/adhocarch.request
${ECHO} "DB ARCH BKP: Ad-hoc archive backup is submitted for ${dbupper}. "
# Check for ad-hoc backup completion.
while [ ! -f "${varchbkplocation}"/adhocarch.complete  ];
do
sleep 5m
if [ -f "${varchbkplocation}"/adhocarch.error ]; then
  break
fi
done

if [ -f "${varchbkplocation}"/adhocarch.error ] ; then
  ${ECHO} "DB ARCH BKP: Ad-hoc archive backup has failed for ${dbupper}. "
  echo "failed" > "${vstateresult}"/adhocarch.state
  return 1
fi

if [ -f "${varchbkplocation}"/adhocarch.complete ] ; then
  ${ECHO} "DB ARCH BKP: Ad-hoc archive backup is completed for ${dbupper}. "
  echo "success" > "${vstateresult}"/adhocarch.state
  rm -f  "${varchbkplocation}"/adhocarch.complete > /dev/null 2>&1
fi

return 0
}

##******************************************************************************************************##
#  **********  R E Q U E S T - A D - H O C - A R C H I V E - B A C K U P - F U N - E N D **********
#******************************************************************************************************##