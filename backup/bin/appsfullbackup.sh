#!/bin/bash
#******************************************************************************************************#
#  Purpose: To run appsfullbackup.sh Oracle EBS Application file system 
#
#  SYNTAX : sh appsfullbackup.sh instance   # For running backup 
#           sh appsfullbackup.sh ORAPRD 
#
#  Author : Dinesh Kumar
# Version 2.0 : Adhoc backup and lock file updated.
#******************************************************************************************************#

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - B A C K U P - S C R I P T **********
#
#******************************************************************************************************##

#******************************************************************************************************##
#
#       Local variable declaration.
#
#******************************************************************************************************##

        trgdbupper=${1^^}
        trgdblower=${1,,}
        HOST_NAME=$(uname -n | cut -f1 -d".")
        ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
        scr_home="/u05/oracle/backupmgr"
        etc_home="${scr_home}/etc"
        bin_home="${scr_home}/bin"
        lib_home=${scr_home}/lib
        util_home="${scr_home}/utils"
        common_sql="${scr_home}/sql"
        log_dir="${scr_home}/log/${trgdbupper}"
        logf="${log_dir}/backupmain_${trgdbupper}_application.log"

        echo -e "\n\n\n\n\n"
        sleep 2
        ${ECHO} "     **************************************************************************************"
        ${ECHO} "    "
        ${ECHO} "                        THIS IS START OF THIS PRODUCTION BACKUP SESSION.   "
        ${ECHO} "    "
        ${ECHO} "     **************************************************************************************"
        sleep 4

#******************************************************************************************************##
#       Lock file for single instance run
#******************************************************************************************************##
        
        if [ -f /tmp/adhoc"${trgdbupper}".lock ]; then
        printf "Backup script is already running. Exiting this run!!";
        exit 1
        else 
        echo $$ > /tmp/adhoc"${trgdbupper}".lock 
        fi

#******************************************************************************************************##
#       Source instance.properties and profile files
#******************************************************************************************************##

        envfile="${etc_home}/instance.properties" 
        if [ ! -f ${envfile} ];
        then
        ${ECHO} "${trgdbupper}:ERROR: Target Environment instance.properties file not found.\n"  | tee -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1;
        else
        . "${etc_home}"/instance.properties "${trgdbupper}"
        sleep 2
        fi
        unset envfile

        envfile="/home/$(whoami)/.${trgdblower}_profile" 
        if [ ! -f "${envfile}" ]; then
        ${ECHO} "${trgdbupper}:ERROR: Environment file $envfile is not found.\n"  | tee -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1;
        else
        . "${envfile}" > /dev/null  
        sleep 2
        fi

        mkdir -p "${log_dir}" 

        ${ECHO} "${trgdbupper}: Logfile for this session is at  $(hostname)" | tee -a "${logf}"
        ${ECHO} "${trgdbupper}:                            "${logf}". " | tee -a "${logf}"

#******************************************************************************************************##
#
#       Run adpreclone.pl from admin node. 
#
#******************************************************************************************************##

        APPSUSER=$(/dba/bin/getpass "${trgdbupper}" apps)
        APPSPASS=$(echo "$APPSUSER" | cut -d/ -f 2)
        #echo ${APPSPASS}
        WLSUSER=$(/dba/bin/getpass "${trgdbupper}" weblogic )
        WLSPASS=$(echo "$WLSUSER" | cut -d/ -f 2)
        #echo ${WLSPASS}
        unset rcode
        cd "${INST_TOP}"/admin/scripts || exit 
        #Running adpreclone.pl
        if [ ! -f "${INST_TOP}"/admin/scripts/adpreclone.pl ]; then
        ${ECHO} "${trgdbupper}: ERROR: adpreclone.pl could not be located. EXITING !! " | tee -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1
        else 
        ${ECHO} "${trgdbupper}: Executing adpreclone.pl..." | tee -a  "${logf}"
        { echo "${APPSPASS}" ; echo "${WLSPASS}" ; } | perl adpreclone.pl appsTier  >> "${logf}"
        rcode=$?
        fi

        if (( rcode > 0 )); then
        ${ECHO} "${trgdbupper}: ERROR: adpreclone.pl did not completed successfully. EXITING !! \n " | tee  -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1
        else 
        ${ECHO} "${trgdbupper}:   ***** ${trgdbupper} : adpreclone.pl completed completed successfully. ***** " | tee -a  "${logf}"
        fi

#******************************************************************************************************##
#
#       Create run and patch file system backup tar files. 
#
#******************************************************************************************************##

        if [ ! -d "${appstgbkp}" ];
        then
        mkdir -p "${appstgbkp}"
        chmod -R 775 "${appstgbkp}"
        fi

        # determine run file system
        case "$APPL_TOP" in
                *fs2* )  
                        runfs=fs2
                        patchfs=fs1 ;;
                *fs1* )  
                        runfs=fs1
                        patchfs=fs2  ;;
                * ) 
                        ${ECHO} "${trgdbupper}: ERROR: Run FS could not be determined.EXITING !!\n"   | tee -a  "${logf}"
                        rm -f /tmp/adhoc"${trgdbupper}".lock
                        exit 1

        ;;
        esac

        runebsappsbkpfile="EBSapps.${trgdbupper}.run${runfs}.$(date +"%m%d%Y").tar.gz"
        runfmwhomebkpfile="FMW_Home.${trgdbupper}.run${runfs}.$(date +"%m%d%Y").tar.gz"
        runinstbkpfile="inst.${trgdbupper}.run${runfs}.$(date +"%m%d%Y").tar.gz"
        patchebsappsbkpfile="EBSapps.${trgdbupper}.patch${patchfs}.$(date +"%m%d%Y").tar.gz"
        patchfmwhomebkpfile="FMW_Home.${trgdbupper}.patch${patchfs}.$(date +"%m%d%Y").tar.gz"
        patchinstbkpfile="inst.${trgdbupper}.patch${patchfs}.$(date +"%m%d%Y").tar.gz"

        cd "${appstgbkp}" || exit
        currentdir=$(pwd)
        if [ "${appstgbkp}" = "${currentdir}" ]; then
        ${ECHO} "${trgdbupper}: Cleaning up stage backup directory. " | tee -a  "${logf}"
        find "${appstgbkp}" -name "*.gz" -type f -mtime +90 -delete  | tee -a  "${logf}"
        sleep 2
	else
        ${ECHO} "${trgdbupper}: ERROR: Backup directory not set properly. EXITING. !!"   | tee -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1
        fi

        ${ECHO} "${trgdbupper}: Running Tar backup for full application tier. "   | tee -a  "${logf}"

        cd "${RUN_BASE}" || exit
        currentdir=$(pwd)
        if [ "${RUN_BASE}" = "${currentdir}" ];     then
		rm "${appstgbkp}"/fullappsbkp.complete
		rm "${appstgbkp}"/runfs.complete
		touch "${appstgbkp}"/fullappsbkp.running

		#Marking EBSapps tarfile for clone tasks
		echo -e "${runebsappsbkpfile}">  "${appstgbkp}"/runfs.latest
		echo -e "${runebsappsbkpfile}">  "${appstgbkp}"/runfs.running

		tar -czvf  "${appstgbkp}"/"${runebsappsbkpfile}"  EBSapps  > /dev/null
		mv "${appstgbkp}"/runfs.running  "${appstgbkp}"/runfs.complete
        sleep 2
        ${ECHO} "${trgdbupper}:  ${runfs} EBSapps  Tar backup for application tier. "   | tee -a  "${logf}"

        tar -czvf "${appstgbkp}"/"${runfmwhomebkpfile}"  FMW_Home  > /dev/null
        sleep 2
        ${ECHO} "${trgdbupper}:  ${runfs} FMW_Home  Tar backup for application tier. "   | tee -a  "${logf}"
        tar -czvf "${appstgbkp}"/"${runinstbkpfile}"  inst  > /dev/null
        sleep 2
        ${ECHO} "${trgdbupper}:  ${runfs} inst Tar backup for application tier. "   | tee -a  "${logf}"

	else
        ${ECHO} "${trgdbupper}: ERROR: Runfs directory not set properly. EXITING. !!"   | tee -a  "${logf}"
        rm -f /tmp/adhoc"${trgdbupper}".lock
        exit 1
        fi

        #cd ${PATCH_BASE}
        #currentdir=`pwd`
        #if [ "${PATCH_BASE}" = "${currentdir}" ];
        #then
        #tar -czvf ${appstgbkp}/${patchebsappsbkpfile}  EBSapps  > /dev/null
        #sleep 2
        #${ECHO} "${trgdbupper}:  ${patchfs} EBSapps  Tar backup for application tier. "   | tee -a  "${logf}"
        #tar -czvf ${appstgbkp}/${patchfmwhomebkpfile} FMW_Home  > /dev/null
        #sleep 2
        #${ECHO} "${trgdbupper}:  ${patchfs} FMW_Home  Tar backup for application tier. "   | tee -a  "${logf}"
        #tar -czvf ${appstgbkp}/${patchinstbkpfile}  inst  > /dev/null
        #sleep 2
        #${ECHO} "${trgdbupper}:  ${patchfs} inst Tar backup for application tier. "   | tee -a "${logf}"
		#else
        #${ECHO} "${trgdbupper}: ERROR: Patchfs directory not set properly. EXITING. !!"   | tee -a  "${logf}"
        #rm -f /tmp/adhoc"${trgdbupper}".lock
        #exit 1
        #fi

	mv "${appstgbkp}"/fullappsbkp.running "${appstgbkp}"/fullappsbkp.complete

	${ECHO} "${trgdbupper}:    Tar backup completed. \n\n" 

        # Removing session lockfile
        if [ -f /tmp/adhoc"${trgdbupper}".lock ]; then
        rm -f /tmp/adhoc"${trgdbupper}".lock
        fi 

exit 

#******************************************************************************************************##
#
#  **********  A P P L I C A T I O N - B A C K U P - S C R I P T - E N D **********
#
#******************************************************************************************************##