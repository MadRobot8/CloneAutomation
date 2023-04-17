#!/bin/bash
#******************************************************************************************************#
#  Purpose  : Script to restore application backup to application tier.
#
#  SYNTAX   : sh copyapps.sh instance
#             sh copyapps.sh ORASUP
#
#  Author   : Dinesh Kumar
#
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#  Execution summary:
## - 1. Execute latest run file backup
## - 2. determine run fs
## - 3. Finalize target run fs location for copy
## - 4. Copy tar file.
## - 5. Update clone.rsp file
#******************************************************************************************************#
#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - B A C K U P - R E S T O R E - S C R I P T **********
#
#******************************************************************************************************##
#******************************************************************************************************#
#
#	Local variable declaration.
#
#******************************************************************************************************#

dbupper=${1^^}
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
scr_home=/u05/oracle/autoclone
exe_home="${scr_home}/exe"
etc_home="${scr_home}/etc"
bin_home="${scr_home}/bin"
lib_home="${scr_home}/lib"
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"
log_dir="${scr_home}"/log/"${dbupper}"
mail_dir="${scr_home}/mailer"
SSHAPP="ssh -q -o TCPKeepAlive=yes "
SCP="scp -q -o TCPKeepAlive=yes "

# Setup oem node log dir for oem node local logs
mkdir -p "${scr_home}"/log/oem/"${dbupper}" > /dev/null 2>&1
oemlog_dir="${scr_home}"/log/oem/"${dbupper}"


if [ -f "${oemlog_dir}"/"cloneapps${dblower}".lck ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}:" "ERROR: Lock file exists, another session is still running.\n\n" > "${oemlog_dir}"/"cloneapps${dblower}".error
  exit 1
else
  echo -e date > "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null
fi


#******************************************************************************************************#
# Using instance.properties to load instance specific settings
#******************************************************************************************************#

envfile="${etc_home}/properties/${dbupper}.prop"
if [ ! -f "${envfile}" ];  then
    ${ECHO} "ERROR: Target Environment instance.properties file not found.\n"
    rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
    exit 1;
else
    source "${etc_home}"/properties/"${dbupper}".prop
    sleep 2
fi
unset envfile

# Update clone.rsp for copy apps script session.
clonersploc="${log_dir}"/restore/restart/clone.rsp
if [ ! -f "${clonersploc}" ]; then
  touch "${clonersploc}" > /dev/null 2>&1
  chmod 777 "${clonersploc}"
fi
logf="${oemlog_dir}"/"${dbupper}"copyapphome."${startdate}"
${ECHO} "Logfile for this session is at "  | tee "${logf}"
${ECHO} "			   ${logf}. " | tee -a "${logf}"
#******************************************************************************************************##
###  Libraries for Clone task functions
#******************************************************************************************************##

source ${lib_home}/os_check_dir.sh
source ${lib_home}/funclonersp.sh
source ${lib_home}/funmailer.sh
source ${lib_home}/fundbrestore.sh
source ${lib_home}/funbackup.sh
#******************************************************************************************************#
# Function - Run - ad-hoc -  application - backup - END
#******************************************************************************************************#
run_adhocappsbkp()
{


HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "

rm -f "${appsourcebkupdir}"/adhoc.error > /dev/null

if [ -f "${appsourcebkupdir}"/runfs.running ] || [ -f "${appsourcebkupdir}"/newruns.backup ] || [ -f "${appsourcebkupdir}"/adhoc.submitted ]; then
    $ECHO "Application backup is already running. It will be used for clone."
elif [ ! -f runfs.running  ]; then
    #Requesting
    echo  "${dbupper}" > "${appsourcebkupdir}"/adhoc.request
fi

sleep 10
while :
do
if [ -f "${appsourcebkupdir}"/adhoc.error ]; then
    $ECHO "Ad-hoc request for Application backup is in error state, application backup will not be generated/copied."
    rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
    exit 1
fi

if [ -f "${appsourcebkupdir}"/adhoc.submitted ]; then
    $ECHO "Ad-hoc request for Application backup is submitted."
    break
fi
sleep 10
done

while :
do
if [ -f "${appsourcebkupdir}"/adhoc.error ]; then
    $ECHO "Ad-hoc request for Application backup is in error state, application backup will not be generated/copied."
    exit 1
fi

if [ -f "${appsourcebkupdir}"/pull.completed ]; then
    $ECHO "Ad-hoc request for Application backup is completed."
    break
fi
sleep 10
done

rm -f "${appsourcebkupdir}"/adhoc.submitted > /dev/null
return
}
#******************************************************************************************************#
# Function - Run - ad-hoc -  application - backup - END
#******************************************************************************************************#
#******************************************************************************************************#
# Run ad-hoc application backup
#******************************************************************************************************#

run_adhocappsbkp
${ECHO} "APP BACKUP: Application backup file ready to be copied. "   | tee -a "${logf}"
sleep 2
#******************************************************************************************************#
# Validate backup location and backup file to be restored.
#******************************************************************************************************#

appbkpfile=$(< "${appsourcebkupdir}"/runfs.latest)
appbkpfilefullpath="${appsourcebkupdir}"/"${appbkpfile}"
if [ ! -f "${appbkpfilefullpath}" ]; then
	${ECHO} "APP COPY: ERROR: Application backup for ${srcappname} not found. Please check.EXITING!!\n"  | tee -a  "${logf}"
	rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
	exit 1;
else
		${ECHO} "APP COPY: Application backup for ${srcappname} found. "  | tee -a  "${logf}"
		${ECHO} "APP COPY: File name: ${appbkpfilefullpath} "  | tee -a  "${logf}"
		sleep 2
fi


# Determine run fs from backup file
if [[ ${appbkpfile} == *"fs1"* ]]; then
	runfs=fs1
	patchfs=fs2
	${ECHO} "APP COPY: Run fs is set to ${runfs}. "  | tee -a "${logf}"
elif [[ ${appbkpfile} == *"fs2"* ]]; then
	runfs=fs2
	patchfs=fs1
	${ECHO} "APP COPY: Run fs is set to ${runfs}. "  | tee -a  "${logf}"
else
	${ECHO} "APP COPY: ERROR: Run fs could not be identified. Backup file will not be restored. Exiting!!\n"   | tee -a "${logf}"
	rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
	exit 1
fi

#Copy  apps tier file to runfs
targtrunfs="${apptargetbasepath}"/"${runfs}"
${ECHO} "APP COPY: Run fs in target will be : ${targtrunfs} "   | tee -a "${logf}"
${ECHO} "APP COPY: Initiating Source application backup copy to Target application node. "   | tee -a "${logf}"
${ECHO} "APP COPY: Copy target : ${appsosuser}@${trgapphost}.${labdomain}:${targtrunfs}/. "   | tee -a "${logf}"
sleep 5
unset rcode
${SCP} "${appbkpfilefullpath}" "${appsosuser}"@"${trgapphost}"."${labdomain}":"${targtrunfs}"/.
rcode=$?
if (( rcode > 0 )); then
  echo -e "\n"
	${ECHO} "APP COPY: ERROR: Application backup file could not be copied. EXITING !! \n "   | tee -a "${logf}"
	session_copyapps="ERROR"
	sed -i '/^session_copyapps/d' "${clonersploc}"  >/dev/null
	echo -e "session_copyapps=\"${session_copyapps}\""  >> "${clonersploc}"
	rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
	exit 1
else
	${ECHO} "APP COPY: Application backup file copied to ${trgapphost}.${labdomain} "   | tee -a "${logf}"
	session_copyapps="COMPLETE"
	sleep 2
fi

#Remove old values
sed -i '/^apps_bkp_file/d; /^runfs/d; /^patchfs/d; /^appsrunfsbase/d; /^session_copyapps/d'  "${clonersploc}"  >/dev/null
{
echo -e "apps_bkp_file=\"${appbkpfile}\""
echo -e "runfs=\"${runfs}\""
echo -e "patchfs=\"${patchfs}\""
echo -e "appsrunfsbase=\"${targtrunfs}\""
echo -e "session_copyapps=\"${session_copyapps}\""
}  >> "${clonersploc}"
${ECHO} "APP COPY: clone.rsp file is updated. "   | tee -a "${logf}"

rm -f "${oemlog_dir}"/"cloneapps${dblower}".lck > /dev/null 2>&1
exit

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - B A C K U P - R E S T O R E - S C R I P T - E N D **********
#
#******************************************************************************************************##