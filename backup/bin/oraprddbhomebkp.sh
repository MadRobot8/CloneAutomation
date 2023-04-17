#!/bin/bash
#******************************************************************************************************#
#  Purpose: To run dbhomebkp.sh Database Oracle Home file system
#
#  SYNTAX : sh dbhomebkp.sh    # For running backup
#           sh dbhomebkp.sh
#
#  Author : Dinesh Kumar
# Version 2.0 : Adhoc backup and lock file updated.
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  D A T A B A S E - O R A C L E - H O M E - B A C K U P - S C R I P T **********
#
#******************************************************************************************************##

#******************************************************************************************************##
#
#       Local variable declaration.
#
#******************************************************************************************************##

        trgdbupper="ORAPRD"
        trgdblower=${trgdbupper,,}
        HOST_NAME=$(uname -n | cut -f1 -d".")
        ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
        scr_home="/dba/backupmgr"
        log_dir="${scr_home}/log"
        logf="${log_dir}/backup_${trgdbupper}_database.log"
        switchdir=/u01/app/oracle/ORAPRD/db/tech_st

#******************************************************************************************************##
#       Lock file for single instance run
#******************************************************************************************************##

        if [ -f /tmp/adhocdb"${trgdbupper}".lock ]; then
        printf 'Backup script is already running. Exiting this run at %s !!\n' "$(date)"
        exit 1
        else
        echo $$ > /tmp/adhocdb"${trgdbupper}".lock
        fi

#******************************************************************************************************##
#       Source profile file
#******************************************************************************************************##

        envfile="/home/$(whoami)/.${trgdblower}_profile"
        if [ ! -f "${envfile}" ]; then
        ${ECHO} "${trgdbupper}:ERROR: Environment file $envfile is not found.\n"  | tee -a  "${logf}"
        rm -f /tmp/adhocdb"${trgdbupper}".lock
        exit 1;
        else
        source "${envfile}" > /dev/null
        sleep 2
        fi

        mkdir -p "${log_dir}"
        dbhstgloc=/backuprman/ebs_backups/ORAPRD/db_home/"${ORACLE_SID}"
        dbstglocdown=/backuprman/ebs_backups/ORAPRD/db_home


        vday=$(date +"%u")
        vhour=$(date +"%H")
        vmin=$(date +"%M")
        if [ -f "${dbstglocdown}"/adhocdb.request ]; then
          ${ECHO} "${trgdbupper}: Submitting ah-hoc backup request  $(hostname)"
          rm -f "${dbstglocdown}"/adhocdb.request  > /dev/null 2>&1
        elif [ "${vday}" = 5 ] && [ "${vhour}" = 6 ] && [ "${vmin}" = 1 ] ; then
          ${ECHO} "${trgdbupper}: Submitting backup for Friday morning  $(hostname)"
        else
          exit 0
        fi



        ${ECHO} "${trgdbupper}: Logfile for this session is at  $(hostname)" | tee -a "${logf}"
        ${ECHO} "${trgdbupper}:                            "${logf}". " | tee -a "${logf}"

#******************************************************************************************************##
#       Run adpreclone.pl from admin node.
#******************************************************************************************************##

        APPSUSER=$(/dba/bin/getpass "${trgdbupper}" apps)
        APPSPASS=$(echo "$APPSUSER" | cut -d/ -f 2)
        #echo ${APPSPASS}

        unset rcode
        cd "${ORACLE_HOME}"/appsutil/scripts/"${CONTEXT_NAME}" || exit
        #Running adpreclone.pl
        if [ ! -f "${ORACLE_HOME}"/appsutil/scripts/"${CONTEXT_NAME}"/adpreclone.pl ]; then
        ${ECHO} "${trgdbupper}: ERROR: adpreclone.pl could not be located on db node ${HOST_NAME}. EXITING !! " | tee -a  "${logf}"
        rm -f /tmp/adhocdb"${trgdbupper}".lock
        exit 1
        else
          while [  -f "${dbstglocdown}"/.adpreclone.lock  ];
          do
          sleep 5m
          ${ECHO} "${trgdbupper}: MESSAGE: Waiting for adpreclone.pl lock to clear on db node ${HOST_NAME}. " | tee -a  "${logf}"
          done

        ${ECHO} "${trgdbupper}: Executing adpreclone.pl..." | tee -a  "${logf}"
        date > ${dbstglocdown}/.adpreclone.lock
        { echo "${APPSPASS}" ;  } | perl adpreclone.pl dbTier  >> "${logf}"
        rcode=$?
        fi

        if (( rcode > 0 )); then
        ${ECHO} "${trgdbupper}: ERROR: adpreclone.pl did not completed successfully on db node ${HOST_NAME}. EXITING !! \n " | tee  -a  "${logf}"
        rm -f /tmp/adhocdb"${trgdbupper}".lock
        exit 1
        else
        ${ECHO} "${trgdbupper}:   ***** ${trgdbupper} : adpreclone.pl completed completed successfully on db node ${HOST_NAME}. ***** " | tee -a  "${logf}"
        rm -f "${dbstglocdown}"/.adpreclone.lock > /dev/null 2>&1
        fi

#******************************************************************************************************##
#       Create database Oracle Home file system backup tar files.
#******************************************************************************************************##


        if [ ! -d "${dbhstgloc}" ];
        then
        mkdir -p "${dbhstgloc}"
        chmod -R 775 "${dbhstgloc}"
        fi

        dbhbkpfile="${ORACLE_SID}.$(date +"%m%d%Y").tar.gz"

        # Cleaning up very old files
        cd "${dbhstgloc}" || exit
        currentdir=$(pwd)
        if [ "${dbhstgloc}" = "${currentdir}" ]; then
        ${ECHO} "${trgdbupper}: Cleaning up stage backup directory. " | tee -a  "${logf}"
        find "${dbhstgloc}" -name "*.gz" -type f -mtime +90 -delete  | tee -a  "${logf}"
        sleep 2
        else
        ${ECHO} "${trgdbupper}: ERROR: Backup directory not set properly. EXITING. !!"   | tee -a  "${logf}"
        rm -f /tmp/adhocdb"${trgdbupper}".lock
        exit 1
        fi

        ${ECHO} "${trgdbupper}: Running Tar backup for full database home. "   | tee -a  "${logf}"

        cd "${switchdir}" || exit
        currentdir=$(pwd)
        if [ "${switchdir}" = "${currentdir}" ];     then
		      rm "${dbhstgloc}"/dbhbkp.complete
		      echo "${dbhbkpfile}" >  "${dbhstgloc}"/dbhbkp.running
		      echo "${dbhbkpfile}" >  "${dbhstgloc}"/dbhbkp.latest

		      tar -czvf  "${dbhstgloc}"/"${dbhbkpfile}"  12.1.0  > /dev/null
		      mv "${dbhstgloc}"/dbhbkp.running  "${dbhstgloc}"/dbhbkp.complete
          sleep 2
          ${ECHO} "${trgdbupper}:  ${ORACLE_SID} Oracle Home  Tar backup completed. "   | tee -a  "${logf}"
	      else
          ${ECHO} "${trgdbupper}: ERROR: Oracle Home directory not set properly. EXITING. !!"   | tee -a  "${logf}"
          rm -f /tmp/adhocdb"${trgdbupper}".lock
          exit 1
        fi

	      ${ECHO} "${trgdbupper}:    Tar backup completed. \n\n"

        # Removing session lockfile
        if [ -f /tmp/adhocdb"${trgdbupper}".lock ]; then
        rm -f /tmp/adhocdb"${trgdbupper}".lock
        fi

exit

#******************************************************************************************************##
#
#  **********  D A T A B A S E - O R A C L E - H O M E - B A C K U P - S C R I P T - E N D **********
#
#******************************************************************************************************##