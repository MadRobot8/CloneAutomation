#!/bin/bash
#******************************************************************************************************
# $Header 1.0 2022/08/15 dikumar funclonersp.sh
#  Purpose  : Function library for clonersp related  operations.
#
#  SYNTAX   :
#
#  Author   : Dinesh Kumar
#******************************************************************************************************#
#******************************************************************************************************##
#  **********  C L O N E - R S P - F I L E - M A N A G E M E N T - T A S K - F U N - S C R I P T **********
#******************************************************************************************************##
clonersp()
{

HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "

#Checking if log_dir is null or not
if [ -z "${log_dir}" ]; then
    ${ECHO} "Log directory is not set. Make sure script assign log_dir value."
    exit 0
fi 

#Checking if log_dir directory exists otherwise creating it.
if [ ! -d "${log_dir}" ]; then
    mkdir -p "${log_dir}"
    if [ ! -d "${log_dir}" ]; then
        ${ECHO} "Log directory could not be created. Exiting !!"
        exit 0
    else 
        chmod -R 775 "${log_dir}"  > /dev/null 2>&1
    fi
fi 

#Checking if restart directory exists otherwise creating it.
restart_dir=${log_dir}/restore/restart
if [ ! -d "${restart_dir}" ]; then
    mkdir -p "${restart_dir}"
    if [ ! -d "${restart_dir}" ]; then
        ${ECHO} "Restart directory could not be created. Exiting !!"
        exit 0
    else 
        chmod -R 775 "${restart_dir}"
    fi
fi 


clonerspfile="${restart_dir}"/clone.rsp

rm -f "${restart_dir}"/clone.rsp >/dev/null 2>&1
#genrating session id from current date
randomsid=$(date '+%Y%m%d')

{
echo -e "startdate=${randomsid}"
#Add recovery date to clone.rsp
echo -e "recover_time=\"${time_flag}\""
echo -e "session_type=\"${restart_flag}\""
} >> "${clonerspfile}"

${ECHO} "CLONE RSP: clone.rsp file is created as ${clonerspfile}"

source "${restart_dir}"/clone.rsp
#echo ${startdate}
}

load_clonersp()
{

HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: Reload clone.rsp"

if [ ! -f "${restart_dir}"/clone.rsp ]; then
   ${ECHO} "CLONE RSP: clone.rsp could not be found. Exiting !!"
   exit 0
fi

source "${restart_dir}"/clone.rsp

}

#******************************************************************************************************##
#  **********  C L O N E - R S P - F I L E - M A N A G E M E N T - T A S K - F U N - S C R I P T - E N D**********
#******************************************************************************************************##