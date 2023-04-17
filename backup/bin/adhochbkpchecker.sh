#!/bin/bash
#******************************************************************************************************#
#  Purpose: To check and run adhoc application backups from  Oracle EBS Application file system 
#
#  SYNTAX : sh adhocbkpchecker.sh <Instance name>  # For running backup 
#           sh adhocbkpchecker.sh  ORAPRD
#
#  Author : Dinesh Kumar
# Version 1.0 : Adhoc backup 
#******************************************************************************************************#

#******************************************************************************************************##
#
#  ********** A D - H O C -  A P P L I C A T I O N - B A C K U P - C H E C K E R - S C R I P T **********
#
#******************************************************************************************************##

    dbupper=${1^^}
    stagebkplocation=/u05/oracle/backupmgr/stagebackup/apps/${dbupper}

    if [ -f "${stagebkplocation}"/adhoc.request ]; then
        if [ -f /tmp/tmp/adhoc"${dbupper}".lock]; then
        printf "Bakcup is already running. Ad-hoc backup will not be submitted."
        exit 1
        else
        printf "\n Submitting Ad hoc backup for %s at %s.\n" "${dbupper}" "$(date)"
        nohup sh /u05/oracle/backupmgr/bin/appsfullbackup.sh "${dbupper}"  >> /u05/oracle/backupmgr/log/"${dbupper}"/cronappsfullbackuplog.log  2>&1 &
        fi
    rm -f "${stagebkplocation}"/adhoc.request
    fi

    exit 
#******************************************************************************************************##
#
#  ********** A D - H O C -  A P P L I C A T I O N - B A C K U P - C H E C K E R - S C R I P T - E N D **********
#
#******************************************************************************************************##
