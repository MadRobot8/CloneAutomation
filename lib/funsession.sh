#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/21 dikumar funsession.sh
#  Purpose  : Function library for post database restore operations.
#  SYNTAX   : add_tempfile          # To add temp files to restored database.
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  ********** R E S T O R E - S E S S I O N - F U N - S C R I P T **********
#******************************************************************************************************##
HOST_NAME=$(uname -n | cut -f1 -d".")
#session_stage=
#               "VALIDATE_DB"
#               "VALIDATE_APP"
#               "PREPARE_APP"
#               "PREPARE_DB"
#               "RESTORE_DB"
#               "POSTRESTORE_DB"
#               "PRERESTORE_APP"
#               "APP_CONFIG"
#               "POSTCONFIG_APP"
#               "PREMULTI_NODE"
#               "MULTI_NODE"
#               "VALIDATION"
gah_clone_new()
{
# Generate clone.rsp in restart directory
clonersp
#******************************************************************************************************##
##  Creating missing directories
#******************************************************************************************************##
#To check and create os directories if missing.
os_check_dir

# Set stage
session_stage="PREPARE_DB"
session_task=0
source_database="${srcdbname}"

sed -i '/^session_stage/d; /^session_task/d;/^source_database/d' "${restart_dir}"/clone.rsp  >/dev/null

{
echo -e "session_stage=\"${session_stage}\""
echo -e "session_task=0"
echo -e "source_database=\"${source_database}\""
}  >> "${restart_dir}"/clone.rsp


# Check and submit ad-hoc backups
getdbarchivebkp "${dbupper}" "${dbarchivebkploc}" "${oemlog_dir}"

#******************************************************************************************************##
#  Submit ad-hoc application backup and copy
#******************************************************************************************************##
nohup sh "${exe_home}"/utils/copyapps.sh  "${dbupper}"  > "${oemlog_dir}"/copyapps"${trginstname}"."${startdate}" 2>&1 &
if [ $? != 0 ]; then
    ${ECHO} "COPY APPS: ERROR received while submitting application ad-hoc backup. Exiting !!"
    cat "${oemlog_dir}"/copyapps"${trginstname}"."${startdate}"
    exit 1
else
    ${ECHO} "COPY APPS: Ad-hoc application job submitted successfully in nohup at  ${HOST_NAME}. "
fi

#******************************************************************************************************##
#  Submit database restore over ssh
#******************************************************************************************************##
if [ -z "${dbosuser}" ] || [ -z "${trgdbhost}" ] || [ -z "${labdomain}" ] || [ -z "${trginstname}" ] ; then
    ${ECHO} "All the required values are not set. Make sure property file is sourced. Exiting !!"
    exit 1
fi

# Call the database restore script over ssh with source apps password as input.
ssh -q "${dbosuser}"@"${trgdbhost}"."${labdomain}" " nohup sh ${exe_home}/clonedbrestore.sh  ${workappspass}  > ${restore_log}/maindbrestore${trginstname}.${startdate} 2>&1 & "
if [ $? != 0 ]; then
    ${ECHO} "DB RESTORE: ERROR received while submitting database restore job via ssh. Please check. Exiting !!"
    cat "${restore_log}"/maindbrestore."${startdate}"
    exit 1
else
    ${ECHO} "DB RESTORE: Restore job submitted successfully in nohup at ${trgdbhost}.${labdomain} "
fi

#To check session status for Database restore completion.
#******************************************************************************************************##
#  Monitor Database restore session for completion
#******************************************************************************************************##


sleep 5
while :
do
load_clonersp
if [ "${session_stage}" = "ERROR_STOP" ]; then
  $ECHO " ${dbupper} : Database restore stage is stopped with error. Exiting !!"
  exit 1
elif [ "${session_stage}" = "DB_RESTORED" ]; then
  $ECHO " ${dbupper} : Database restore stage is completed."
  break
fi
sleep 1m
mailstatus
done

#To check copy apps session is completed.
while :
do
load_clonersp
if [ "${session_copyapps}" = "ERROR" ]; then
  $ECHO " ${dbupper} : Application backup session request is error out. Please review and restart. Exiting !!"
  exit 1
elif [ "${session_copyapps}" = "COMPLETED" ]; then
  $ECHO " ${dbupper} : Application backup script is completed."
  break
fi
sleep 1m
mailstatus
done

#Submit Application restore

}
#******************************************************************************************************##
#  ********** R E S T O R E - S E S S I O N - F U N - S C R I P T - E N D **********
#******************************************************************************************************##