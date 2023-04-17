#!/bin/bash
#******************************************************************************************************#
#  Purpose: pulldbhomebkp.sh will check remote backup location and pull tar backup for clone tasks.
#
#  SYNTAX : sh pulldbhomebkp.sh
#
#  $Header 1.1  base version 2022/02/21 dikumar $
#  $Header 1.2  2022/08/09 Ad hoc backup update  dikumar $
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  D A T A B A S E - O R A C L E - H O M E - B A C K U P - P U L L -  S C R I P T **********
#
#******************************************************************************************************##

#******************************************************************************************************##
#
#       Local variable declaration.
#
#******************************************************************************************************##


        HOST_NAME=$(uname -n | cut -f1 -d".")
        ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
        scr_home="/u01/tools/tools/common/pullbackup"
        bin_home="${scr_home}/bin"
        log_dir="${scr_home}/log"
        logf="${log_dir}/pullbackup_GAHPRD_apps.log"
        SSHAPP="ssh -q -o TCPKeepAlive=yes "
        SCP="scp -q -o TCPKeepAlive=yes "


        echo -e "\n\n\n\n\n"
        sleep 2
        ${ECHO} "     **************************************************************************************"
        ${ECHO} "    "
        ${ECHO} "                        THIS IS START OF THIS PRODUCTION BACKUP SESSION.   "
        ${ECHO} "    "
        ${ECHO} "     **************************************************************************************"
        sleep 4

#******************************************************************************************************##
#
#       Source tools profile to setup tools environment
#
#******************************************************************************************************##

        envfile="/home/$(whoami)/.tools_profile"
        if [ ! -f "${envfile}" ];
        then
        ${ECHO} "OEM:ERROR: Tools Environment file $envfile is not found.\n"  | tee -a  "${logf}"
        exit 1;
        else
        . "${envfile}" > /dev/null
        sleep 2
        fi

        mkdir -p ${log_dir}

        ${ECHO} "OEM: Logfile for this session is at  $(hostname)" | tee "${logf}"
        ${ECHO} "OEM:                      "${logf}". " | tee -a "${logf}"

#******************************************************************************************************##
#
#       This section will check if another instance of this script is still running.
#
#******************************************************************************************************##

    trgappsbkploc="/backuprman/ebs_backups/GAHPRD/app_tar"
    srcappsbkploc="/u05/oracle/backupmgr/stagebackup/apps/GAHPRD"

        if [  -f ${trgappsbkploc}/newrunfs.backup ];
        then
		${ECHO} "OEM: GAHPRD : Another session of this script is already running. Exiting !!\n"  | tee -a  "${logf}"
        exit 0
        fi

#******************************************************************************************************##
#
#       This section will check if there is a ad-hoc backup requested.
#
#******************************************************************************************************##

    if [  -f ${trgappsbkploc}/adhoc.request ];  then
    chmod 744 ${trgappsbkploc}/adhoc.request > /dev/null 2>&1
    ${ECHO} "OEM: GAHPRD : Ad-hoc backup request is found. Sending backup request."  | tee -a  "${logf}"
    scp -q ${trgappsbkploc}/adhoc.request  applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/.
    rcode=$?

        if (( rcode > 0 )); then
            ${ECHO} "OEM: ERROR: Ad-hoc request could not be submitted. EXITING !! \n " | tee  -a  "${logf}"
            mv  ${trgappsbkploc}/adhoc.request ${trgappsbkploc}/adhoc.error > /dev/null 2>&1
            chmod 775 adhoc.*  > /dev/null 2>&1
            exit 1
        else
            mv  ${trgappsbkploc}/adhoc.request ${trgappsbkploc}/adhoc.submitted
        fi
        unset rcode
    exit 0
    fi

#******************************************************************************************************##
#
#       This section will check if a new backup file is available for pulling.
#
#******************************************************************************************************##

    if [ ! -d ${trgappsbkploc} ];
    then
    ${ECHO} "OEM: GAHPRD Target backup location ${trgappsbkploc} not available at $(hostname). Exiting!!." | tee "${logf}"
    sleep 2
    exit 1
    fi


    cd ${trgappsbkploc} || exit
    unset rcode
    scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/runfs.latest  ${trgappsbkploc}/.
    rcode=$?
    if (( rcode > 0 )); then
    ${ECHO} "OEM: ERROR: runfs.latest could not be copied. EXITING !! \n " | tee  -a  "${logf}"
    exit 1
    fi
    unset rcode

    appsbkfile=$(cat ${trgappsbkploc}/runfs.latest)
    if [ ! -f "${trgappsbkploc}"/"${appsbkfile}" ];
    then
    ${ECHO} "OEM: GAHPRD : New application backup is found.\n"  | tee -a  "${logf}"
    touch ${trgappsbkploc}/newrunfs.backup
    else
    exit 0
    fi


    # Check if any backup is running.
    scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/fullappsbkp.running  ${trgappsbkploc}/.

    if [  -f ${trgappsbkploc}/fullappsbkp.running ]; then
    ${ECHO} "OEM: GAHPRD Application full backup is running. We will wait while it completes."  | tee -a  "${logf}"
        while [ ! -f ${trgappsbkploc}/fullappsbkp.complete ];
        do
        sleep 5m
        scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/fullappsbkp.complete  ${trgappsbkploc}/.
        done
    fi

    scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/runfs.running  ${trgappsbkploc}/.
    if [  -f ${trgappsbkploc}/runfs.running ]; then
    ${ECHO} "OEM: GAHPRD Application Runfs backup is running. We will wait while it completes."  | tee -a  "${logf}"
    while [ ! -f ${trgappsbkploc}/runfs.complete ];
    do
    sleep 5m
    scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/runfs.complete  ${trgappsbkploc}/.
    done
    fi

#******************************************************************************************************##
#
#       This section will check if a new backup file is available for pulling.
#
#******************************************************************************************************##

    echo "${appsbkfile}" > ${trgappsbkploc}/pull.running
    scp -q applmgr@chcxoraebsap201.sea.corp.expecn.com:${srcappsbkploc}/"${appsbkfile}"  ${trgappsbkploc}/.
    rcode=$?
    if (( rcode > 0 )); then
            ${ECHO} "OEM: ERROR: GAHPRD apps run fs backup file ${appsbkfile} could not be copied. EXITING !! \n " | tee  -a  "${logf}"
            mv  ${trgappsbkploc}/pull.running ${trgappsbkploc}/pull.error
            rm -f ${trgappsbkploc}/runfs.complete
            rm -f ${trgappsbkploc}/runfs.running
            rm -f ${trgappsbkploc}/fullappsbkp.running
            rm -f ${trgappsbkploc}/fullappsbkp.complete
            rm -f ${trgappsbkploc}/pull.running
            rm -f ${trgappsbkploc}/newrunfs.backup
            rm -f ${trgappsbkploc}/adhoc.submitted > /dev/null 2>&1
            rm -f ${trgappsbkploc}/adhoc.error > /dev/null 2>&1
            exit 1
    else
            ${ECHO} "OEM: GAHPRD apps run fs backup file ${appsbkfile} copied successfully " | tee  -a  "${logf}"
            mv  ${trgappsbkploc}/pull.running  ${trgappsbkploc}/pull.completed
    fi
    unset rcode


    rm -f ${trgappsbkploc}/runfs.complete
    rm -f ${trgappsbkploc}/runfs.running
    rm -f ${trgappsbkploc}/fullappsbkp.running
    rm -f ${trgappsbkploc}/fullappsbkp.complete
    rm -f ${trgappsbkploc}/pull.running
	  rm -f ${trgappsbkploc}/newrunfs.backup
    rm -f ${trgappsbkploc}/adhoc.submitted > /dev/null 2>&1
    rm -f ${trgappsbkploc}/adhoc.error > /dev/null 2>&1

    exit


#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - B A C K U P - P U L L -  S C R I P T **********
#
#******************************************************************************************************#
