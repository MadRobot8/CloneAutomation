#!/bin/bash
#******************************************************************************************************
# 	$Header 1.2 2022/09/19 dikumar $
#  Purpose  : Script to Check and restore application.
#
#  SYNTAX   : sh <instance name>appconfig.sh
#             sh orasupappconfig.sh
#
#  Author   : Dinesh Kumar
#
#******************************************************************************************************#

#******************************************************************************************************##
#  **********  A P P L I C A T I O N - C O N F I G U R A T I O N - S C R I P T **********
#******************************************************************************************************##

#******************************************************************************************************##
#
#	Local variable declaration.
#******************************************************************************************************##

dbupper="CLONEDB"
dblower=${dbupper,,}
HOST_NAME=$(uname -n | cut -f1 -d".")
ECHO="echo -e $(date +"%d-%m-%Y %H:%M:%S"): ${HOST_NAME}: "
scr_home=/u05/oracle/autoclone
exe_home="${scr_home}/exe"
etc_home="${scr_home}/etc"
bin_home="${scr_home}/bin"
lib_home="${scr_home}/lib"
util_home="${scr_home}/utils"
common_sql="${scr_home}/sql"
workappspass="${1}"
workwlspass="${2}"


echo -e "\n\n\n\n\n"
sleep 2
${ECHO} "     *********************************************************************************"
${ECHO} "    "
${ECHO} "                      THIS IS START OF THIS ${dbupper} Application configuration SESSION.   "
${ECHO} "    "
${ECHO} "     *********************************************************************************"
sleep 4

#******************************************************************************************************##
#
#	Source instance properties file
#
#******************************************************************************************************##

envfile="${etc_home}"/properties/"${dbupper}.prop"
if [ ! -f ${envfile} ];  then
    ${ECHO} "ERROR: Target Environment instance.properties file not found.\n"
    exit 1;
else
    source "${etc_home}"/properties/"${dbupper}".prop
    sleep 2
fi
unset envfile

envfile="${trgdbrestart_dir}"/clone.rsp
if [ ! -f "${envfile}" ];  then
    ${ECHO} "ERROR: Target Environment clone.rsp file not found.\n"
    exit 1;
else
    source "${trgdbrestart_dir}"/clone.rsp
    sleep 2
fi
unset envfile

#******************************************************************************************************##
#
#  Libraries for Database functions
#******************************************************************************************************##
source "${lib_home}"/funlibapps.sh
source "${lib_home}"/fundbcommon.sh
source "${lib_home}"/os_check_dir.sh
source "${lib_home}"/funclonersp.sh
source "${lib_home}"/funmailer.sh
source "${lib_home}"/funstate.sh
source "${lib_home}"/fundbarchivebkp.sh
source "${lib_home}"/funappbkp.sh

#******************************************************************************************************##
#  Creating missing directories
#******************************************************************************************************##

#To check and create os directories if missing.
os_check_dir >/dev/null 2>&1

#**************************************************************************************************
# Set session stage and session task
#
#
# session_stage=
##               "PREPARE_DB"
##                            genrman
##                            db_ready
##               "RESTORE_DB"
##                            execrman
##                            renamedb
##               "POSTRESTORE_DB"
##                               add_tempfile
#**************************************************************************************************


if [ "${session_task}" -gt 3000 ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}:" "DB RESTORE CHECK: TASK ID is beyond Database restore."
  return 0
fi


logf="${restore_log}"/main.dbrestore.local."${startdate}"
if [ ! -f "${logf}" ] ; then
  touch "${logf}"  > /dev/null 2>&1
fi

# For testing purpose, set task on ad-hoc basis
#session_task=1820
#session_state="RUNNING"
# Executing the tasks one by one.
for task in $(seq ${session_task} 1 3000 )
do
  case $task in
	"1500")
		${ECHO} "START TASK: $task : Updating stage" | tee -a "${logf}"
    session_stage="PREPARE_DB"
    session_preparedb="RUNNING"
    sed -i '/^session_stage/d; /^session_preparedb/d' "${trgdbrestart_dir}"/clone.rsp   >/dev/null
    echo -e  "session_stage=\"${session_stage}\"" >> "${trgdbrestart_dir}"/clone.rsp
    echo -e  "session_preparedb=\"${session_preparedb}\"" >> "${trgdbrestart_dir}"/clone.rsp
    ${ECHO} "          Stage change to ${session_stage}" | tee -a "${logf}"
		${ECHO} "END TASK: $task : Updating stage" | tee -a "${logf}"
			;;
	"1520")
		${ECHO} "START TASK: $task : Generate RMAN command" | tee -a "${logf}"
    #*************************************************
    #  Generate RMAN CMDFILE for restore.
    #*************************************************
    unset rcode
    genrman
    rcode=$?
    if (( rcode > 0 )); then
    ${ECHO} "ERROR: RMAN restore script creation failed.  EXITING !! \n " | tee  "${logf}"
    error_exit
    else
    ${ECHO} "RMAN restore CMD file is generated as below." | tee -a  "${logf}"
	  ${ECHO}  "\n\n    ****** RMAN CMD file start ****** \n "
	  cat "${rmancmd}"
	  ${ECHO} "\n    ****** RMAN CMD file end ****** \n\n"
    sleep 2
    fi

    ${ECHO} "END TASK: $task : Generate RMAN command" | tee -a "${logf}"
			;;

	"1550")
		${ECHO} "START TASK: $task : Ready database for RMAN restore." | tee -a "${logf}"
    #**********************************************
    #  Drop Database and Ready instance in NOMOUNT
    #**********************************************

    unset rcode
    db_ready
    rcode=$?
    if (( rcode > 0 )); then
      ${ECHO} "ERROR: Database ready script failed.  EXITING !! \n " | tee -a "${logf}"
      error_exit
    else
       ${ECHO} "Database is ready for RESTORE." | tee -a  "${logf}"
    #Capture database state
    #echo -e "NOMOUNT_RESTORE"     > "${restore_statedir}"/dbstate
    sleep 2
    fi
    ${ECHO} "END TASK: $task : Ready database for RMAN restore." | tee -a "${logf}"
  			;;

	"1600")
		${ECHO} "START TASK: $task : Updating stage" | tee -a "${logf}"
      session_stage="RESTORE_DB"
      session_preparedb="COMPLETED"
      session_restoredb="RUNNING"
      sed -i '/^session_stage/d; /^session_preparedb/d; /^session_restoredb/d' "${trgdbrestart_dir}"/clone.rsp   >/dev/null
          echo -e  "session_stage=\"${session_stage}\"" >> "${trgdbrestart_dir}"/clone.rsp
          echo -e  "session_preparedb=\"${session_preparedb}\"" >> "${trgdbrestart_dir}"/clone.rsp
          echo -e  "session_restoredb=\"${session_restoredb}\"" >> "${trgdbrestart_dir}"/clone.rsp
    ${ECHO} "          Stage change to ${session_stage}" | tee -a "${logf}"
		${ECHO} "END TASK: $task : Updating stage" | tee -a "${logf}"
    		;;

	"1620")
		${ECHO} "START TASK: $task : RMAN Restore" | tee -a "${logf}"
    ${ECHO} "           Initiating RMAN restore....."  | tee -a "${logf}"
    execrman
		${ECHO} "END TASK: $task : RMAN Restore" | tee -a "${logf}"
			;;
	"1650")
		${ECHO} "START TASK: $task : RENAME Database" | tee -a "${logf}"
    ${ECHO} "          : Initiating Database RENAME process...."  | tee -a  "${logf}"
    renamedb
		${ECHO} "END TASK: $task : RENAME Database" | tee -a "${logf}"
			;;
	"1800")
		${ECHO} "START TASK: $task : Updating stage" | tee -a "${logf}"
      session_stage="POSTRESTORE_DB"
      session_restoredb="COMPLETED"
      session_postrestoredb="RUNNING"
      sed -i '/^session_stage/d; /^session_postrestoredb/d; /^session_restoredb/d' "${trgdbrestart_dir}"/clone.rsp   >/dev/null
      echo -e  "session_stage=\"${session_stage}\"" >> "${trgdbrestart_dir}"/clone.rsp
      echo -e  "session_postrestoredb=\"${session_postrestoredb}\"" >> "${trgdbrestart_dir}"/clone.rsp
      echo -e  "session_restoredb=\"${session_restoredb}\"" >> "${trgdbrestart_dir}"/clone.rsp
    ${ECHO} "          Stage change to ${session_stage}" | tee -a "${logf}"
		${ECHO} "END TASK: $task : Updating stage" | tee -a "${logf}"
    	;;
	"1820")
		${ECHO} "START TASK: $task : SYS based Database POST RESTORE Tasks.... " | tee -a "${logf}"
		${ECHO} "            Add tempfiles  " | tee -a "${logf}"
		${ECHO} "            Adding tempfiles...."  | tee -a  "${logf}"
    add_tempfile
    ${ECHO} "            Bounce database...."  | tee -a "${logf}"
    bouncedb
    ${ECHO} "            Execute SYS based steps."  | tee -a "${logf}"
    gah_sys_updates
    ${ECHO} "            Create Password file."  | tee -a "${logf}"
    create_password_file
    ${ECHO} "END TASK: $task : SYS based Database POST RESTORE Tasks.... " | tee -a "${logf}"
			;;

	"1920")
	  ${ECHO} "START TASK: $task : APPS based Post Database restore tasks."  | tee -a "${logf}"
      load_getpass_password
      validate_apps_password
      ${ECHO} "        : Run Database autoconfig." | tee -a "${logf}"
      run_db_autoconfig
  	${ECHO} "          : Run APPS based sql updates."  | tee -a "${logf}"
      gah_apps_db_updates
	  ${ECHO} "END TASK: $task : APPS based Post Database restore tasks."  | tee -a "${logf}"
  		;;

	"1950")
		${ECHO} "START TASK: $task : Run Database ETCC" | tee -a "${logf}"
    run_db_etcc
		${ECHO} "END TASK: $task : Run Database ETCC" | tee -a "${logf}"
			;;
	"1980")
		${ECHO} "START TASK: $task : Compile INVALID Database objects." | tee -a "${logf}"
    compile_invalid_objects
		${ECHO} "END TASK: $task : Compile INVALID Database objects." | tee -a "${logf}"
			;;

	"3000")
    ${ECHO}  "START TASK: $task : END - OF -  ${dbupper} database Restore." | tee -a "${logf}"
      session_stage="DB_RESTORED"
      session_postrestoredb="COMPLETED"
      sed -i '/^session_stage/d; /^session_postrestoredb/d' "${trgdbrestart_dir}"/clone.rsp   >/dev/null
      echo -e  "session_stage=\"${session_stage}\"" >> "${trgdbrestart_dir}"/clone.rsp
      echo -e  "session_postrestoredb=\"${session_postrestoredb}\"" >> "${trgdbrestart_dir}"/clone.rsp
    ${ECHO}  "END   TASK: $task : END - OF - ${dbupper} database Restore."  | tee -a "${logf}"
			;;

  *)
    :
    #echo "Task not found - step: $task not present in stage ${session_stage}"  | tee -a "${logf}"
    ;;
  esac
done


${ECHO} " "
${ECHO} " "
${ECHO} "  >>>>>>> Database tier clone steps are completed. <<<<<<< " | tee -a  "${logf}"
${ECHO} " "
${ECHO} " "

exit

#******************************************************************************************************##
#  **********   E N D - O F - D A T A B A S E - R E S T O R E - S C R I P T   **********
#******************************************************************************************************##