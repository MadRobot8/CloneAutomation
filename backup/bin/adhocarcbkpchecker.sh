#!/bin/bash
#******************************************************************************************************#
#  Purpose: To check and run adhoc application backups from  Oracle EBS Application file system
#
#  SYNTAX : sh adhocarchbkpchecker.sh   # For running backup
#           sh adhocarchbkpchecker.sh
#
#  Author : Dinesh Kumar
# Version 1.0 : Adhoc Archive backup
#******************************************************************************************************#

#******************************************************************************************************##
#  ********** A D - H O C -  D A T A B A S E - A R C H I V E - B A C K U P - C H E C K E R - S C R I P T **********
#******************************************************************************************************##

    # Ad-hoc backup checking and submission for ORAPRD
    dbupper="GAHPRD"
    dblower=${dbupper,,}
    stagebkplocation=/backuprman/ebs_backups/${dbupper}/archivelogs

    if [ -f "${stagebkplocation}"/adhocarch.request ]; then
        if [ -f /dba/tmp/"${dblower}"archbkp.lock ]; then
        printf " %s Archive Backup is already running. Ad-hoc backup will be queued." "${dbupper}"
        mv "${stagebkplocation}"/adhocarch.request "${stagebkplocation}"/adhocarch.wait
        exit 1
        else
        printf "\n Submitting Ad hoc Archive backup for %s at %s.\n" "${dbupper}" "$(date)"
        nohup sh /dba/bin/gahprd_rman_archive_bkp.sh >> /dba/cron/gahprd_rman_archive_bkp.log 2>&1 &
        mv "${stagebkplocation}"/adhocarch.request "${stagebkplocation}"/adhocarch.running
        fi
    fi

    if [ -f "${stagebkplocation}"/adhocarch.wait ]; then
        if [ -f /dba/tmp/"${dblower}"archbkp.lock ]; then
        printf " %s Archive Backup is already running. Ad-hoc backup will still wait." "${dbupper}"
        exit 1
        else
        printf "\n Submitting Ad hoc Archive backup for %s at %s.\n" "${dbupper}" "$(date)"
        nohup sh /dba/bin/gahprd_rman_archive_bkp.sh >> /dba/cron/gahprd_rman_archive_bkp.log 2>&1 &
        mv "${stagebkplocation}"/adhocarch.wait "${stagebkplocation}"/adhocarch.running
        fi
    fi

    # Ad-hoc backup checking and submission for ORAPRD
    dbupper="ORAPRD"
    dblower=${dbupper,,}
    stagebkplocation=/backuprman/ebs_backups/${dbupper}/archivelogs

    if [ -f "${stagebkplocation}"/adhocarch.request ]; then
        if [ -f /dba/tmp/"${dblower}"archbkp.lock ]; then
        printf " %s Archive Backup is already running. Ad-hoc backup will be queued." "${dbupper}"
        mv "${stagebkplocation}"/adhocarch.request "${stagebkplocation}"/adhocarch.wait
        exit 1
        else
        printf "\n Submitting Ad hoc Archive backup for %s at %s.\n" "${dbupper}" "$(date)"
        nohup /dba/bin/rman_archive_bkp.sh >> /dba/cron/rman_archive_bkp.log 2>&1 &
        mv "${stagebkplocation}"/adhocarch.request "${stagebkplocation}"/adhocarch.running
        fi
    fi

    if [ -f "${stagebkplocation}"/adhocarch.wait ]; then
        if [ -f /dba/tmp/"${dblower}"archbkp.lock ]; then
        printf " %s Archive Backup is already running. Ad-hoc backup will still wait." "${dbupper}"
        exit 1
        else
        printf "\n Submitting Ad hoc Archive backup for %s at %s.\n" "${dbupper}" "$(date)"
        nohup /dba/bin/rman_archive_bkp.sh >> /dba/cron/rman_archive_bkp.log 2>&1 &
        mv "${stagebkplocation}"/adhocarch.wait "${stagebkplocation}"/adhocarch.running
        fi
    fi

    exit
#******************************************************************************************************##
#  ********** A D - H O C -  D A T A B A S E - A R C H I V E - B A C K U P - C H E C K E R - S C R I P T - E N D**********
#******************************************************************************************************##
