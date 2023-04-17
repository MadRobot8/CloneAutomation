#!/bin/bash

os_check_dir()
{

HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}:"
${ECHO} "  inside os check dir"
if [ "${task_name}" == "refresh" ] || [ "${task_name}" == "bootstrap" ] ; then
    if [ -z "${startdate}" ]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "Start date could not be found. Make sure clone.rsp exists and have startdate set."
    exit 0
    fi
fi

etc_home="${scr_home}/etc"
exe_home="${scr_home}/exe"
bin_home="${scr_home}/bin"
lib_home=${scr_home}/lib
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"
log_dir="${scr_home}"/log/"${trgappname^^}"

#echo -e "Start date is ${startdate}"
restore_dir="${log_dir}"/restore/"${startdate}"
restore_log="${restore_dir}"
restore_statedir="${restore_dir}/state"
restart_dir="${log_dir}/restore/restart"

instance_dir="${scr_home}/instance/${trgdbname^^}/${HOST_NAME}"
extractdir="${instance_dir}/extract"
currentextractdir="${instance_dir}/extract/current"
bkpextractdir="${instance_dir}/extract/backup"
extractlog="${log_dir}/extract"
uploaddir=${instance_dir}/upload
uploadsqldir=${instance_dir}/upload/sql
bkpinitdir=${instance_dir}/init
mail_dir="${scr_home}/mailer"


for dir in ${etc_home} ${exe_home} ${bin_home} ${lib_home} ${util_home} ${common_sql} ${log_dir} ; do
chkdir=${dir}
#${ECHO} "CHECK DIR :Checking  ${chkdir}" 
if [ ! -d "${chkdir}" ];  then
    #${ECHO} "CHECK DIR :Creating  ${chkdir}" 
	mkdir -p "${chkdir}"
    chmod -R 777 "${chkdir}" >/dev/null
	if [  ! -d "${chkdir}" ];  then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : ERROR: ${chkdir} could not be created."
	fi
fi
unset chkdir
done

for dir in ${instance_dir} ${extractdir} ${currentextractdir} ${bkpextractdir} ${extractlog} ${uploaddir} ${uploadsqldir} ${bkpinitdir} ; do
chkdir=${dir}
#${ECHO} "CHECK DIR :Checking  ${chkdir}" 
if [ ! -d "${chkdir}" ];  then
    #${ECHO} "CHECK DIR :Creating  ${chkdir}" 
	mkdir -p "${chkdir}"
    chmod -R 777 "${chkdir}" >/dev/null
	if [  ! -d "${chkdir}" ];  then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : ERROR: ${chkdir} could not be created."
	fi
fi
unset chkdir
done

if [ "${task_name}" = "refresh" ]; then
for dir in ${restore_dir} ${restore_log} ${restore_statedir} ${restart_dir} ; do
chkdir=${dir}
#${ECHO} "CHECK DIR :Checking  ${chkdir}" 
if [ ! -d "${chkdir}" ];  then
	#${ECHO} "CHECK DIR :Creating  ${chkdir}" 
    mkdir -p "${chkdir}"
    chmod -R 777 "${chkdir}" >/dev/null
	if [  ! -d "${chkdir}" ];  then
		echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : ERROR: ${chkdir} could not be created."
	fi
fi
unset chkdir
done
echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : Restore log location for session ${startdate} is : ${restart_dir} "
echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : Session state directory for session ${startdate} is : ${restore_statedir} "
echo -e "$(date +"%d-%m-%Y %H:%M:%S")": "${HOST_NAME}" "CLONE CHECK DIR : Restart directory for session ${startdate} is : ${restore_dir} "
fi

}