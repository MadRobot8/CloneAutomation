#!/bin/bash -n
#******************************************************************************************************
# 	$Header 1.2 2022/07/29 dikumar $
#  Purpose  : Script to Check and restore instance from specified date.
#
#  SYNTAX   : sh <instance name>.sh
#             sh gahdev.sh  -t "29-Jul-2022 17:00:00"
#
#  Author   : Dinesh Kumar
#  Synopsis : This script will perform following operations
#
#  Assumptions: 1. Script assumes that ssh is working from management node(OEM) to client nodes.
#
#******************************************************************************************************
#
# Setup steps
# 1. Change dbupper to desired instance
# 2. Change password source file to correct source file name.
# 3. Update default source DATABASE name as ORAPRD/GAHPRD or any other as required.
# 4. renamedb function works differently for ORAPRD and GAHPRD based lab instances due to encryption steps.
#    Use the function code carefully.
#
#******************************************************************************************************#
echo -e "\n\n\n\n"
#******************************************************************************************************##
#
#  **********  I N S T A N C E - R E S T O R E - W R A P P E R - S C R I P T **********
#
#******************************************************************************************************##
#******************************************************************************************************##
##	Capture and decode input variables.
#   time_flag = Database recovery time string.
#   source_flag = Source database name, if it is not default source which is set to Production.
#   restart_flag = If you want to restart the last session instead of executing a fresh session.
#******************************************************************************************************##
export dbupper="ORASUP"
export dblower="${dbupper,,}"
export HOST_NAME=$(uname -n | cut -f1 -d".")

while getopts ":t:r:s" opt
do
  case "$opt" in
  t ) export time_flag="$OPTARG"
       #echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "                    Recovery Time is ${time_flag}"
  ;;
  r ) export restart_flag="Y"
      #echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "                     Restart flag is ${restart_flag}"
      ;;
  s ) export source_flag="$OPTARG"
      #echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "                     Source is ${source_flag}"
      ;;
  f ) export bkpfile_flag="$OPTARG"
      #echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "                     Backup file is ${bkpfile_flag}"
      ;;
  ? )
      echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "                     Invalid set of arguments."
      exit 1
      ;; # Print Full syntax if case parameter is non-existent
  esac
done

#******************************************************************************************************##
#	Locking for single session
#******************************************************************************************************##
export scr_home=/u05/oracle/autoclone
# Setup oem node log dir for oem node local logs
mkdir -p "${scr_home}"/instance/"${dbupper}"/lock > /dev/null 2>&1
export lock_dir="${scr_home}"/instance/"${dbupper}"/lock
sleep 1
if [ -f "${lock_dir}"/"${dblower}"main.lck ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Lock file exists, another session is still running.\n\n"
  exit 1
fi

#******************************************************************************************************##
##	Source instance properties file
#******************************************************************************************************##

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper^^}".prop
if [ ! -f ${envfile} ];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found.\n"
    exit 1;
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper^^}".prop
    sleep 1
fi
unset envfile


if [[ "${srdbname}" == "ORAPRD" ]]; then
  source /dba/etc/.egebs
  export workappspass="${srcappspass}"
else
  APPSUSER=$(/dba/bin/getpass "${srdbname^^}" apps)
  export srcappspass=$(echo "${APPSUSER}" | cut -d/ -f 2)
  export workappspass="${srcappspass}"
  export workwlspass="${srcwlspass}"
fi

if [[ -z "${workappspass}" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Source Environment password is not loaded.\n"
  exit 1
fi

#******************************************************************************************************##
##	Clone rsp fun
#******************************************************************************************************##
update_clonersp()
{
  keyrsp="${1}"
  valuersp="${2}"
  if [[ ! -f "${clonerspfile}" ]] ; then
    touch "${clonerspfile}"  >/dev/null 2>&1
  fi
  sed -i "/${keyrsp}/d" "${clonerspfile}"
  echo -e  "export ${keyrsp}=${valuersp}"  >> "${clonerspfile}"
  source "${clonerspfile}" >/dev/null 2>&1
}
#******************************************************************************************************##
##	Banner
#******************************************************************************************************##
new_session_banner()
{
echo -e "\n\n\n\n"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:***********************************************************************"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                        STARTING NEW SESSION                         *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Source SYSTEM          : ${srdbname^^}                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Target SYSTEM          : ${trgdbname^^}                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Database recovery time : ${recover_time}       *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:***********************************************************************"
echo -e "\n"
}

restart_session_banner()
{
echo -e "\n\n\n\n"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*********************************************************************"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                   *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                   *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                       RE-STARTING PREVIOUS SESSION                *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Source SYSTEM          : ${srdbname^^}                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Target SYSTEM          : ${trgdbname^^}                     *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 Database recovery time : ${recover_time}       *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                 CURRENT TASK ID        : ${current_task_id}       *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*                                                                   *"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:*********************************************************************"
echo -e "\n"
}
#******************************************************************************************************##
#  **********  C L O N E - R S P - G E N E R A T I O N -  **********
# Clone.rsp file contain all running parameters as well as session progress status.
# It will be located at  "${scr_home}"/instance/"${dbupper}"/etc
# If restart_flag is set to "Y" then simply confirm file location and source it otherwise create it with startup parameters.
#   A clone.rsp will have below starting parameters
#   startdate = Current date
#   session_type = [NEW|RESTART]
#   recover_time = Recovery date for RMAN database restore in format : "29-Jul-2022 17:00:00"
#   current_task_id = task id to start execution 50 for fresh session, restart session will start from restart_task_id
#   next_task_id   = task id to make sure correct next task is executed.
#   module_task = Basically a restart point from where any failure will restart the session
#   session_state = [RUNNING|FAILED]
#******************************************************************************************************##

export clonerspfile="${inst_etc}"/clone.rsp
if [[ "${restart_flag}" == "Y" ]]; then
    source "${inst_etc}"/clone.rsp >/dev/null 2>&1
    #echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART: Last session will be restarted. "
    #echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART: Checking clone.rsp file used for last session. "
    if [[ -f "${clonerspfile}" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART: clone.rsp file found as ${clonerspfile} "
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART:\n"
    #cat "${clonerspfile}"
    #echo -e "\n"
    sleep 2
    #echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART:"
    #echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART: Updating clone.rsp file. "
    update_clonersp "session_type" "\"RESTART\""
    update_clonersp "current_task_id" "${current_module_task}"
    update_clonersp "next_task_id" "${current_module_task}"
    update_clonersp "session_state" "\"RUNNING\""
    restart_session_banner

    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART: Restarting Last session with updated clone.rsp. "
    source "${inst_etc}"/clone.rsp >/dev/null 2>&1
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART:\n"
    cat "${clonerspfile}"
    echo -e "\n"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SESSION RESTART:"
    sleep 2
    else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: :CLONE RSP: clone.rsp file could not be found. Exiting !!"
        exit 1
    fi
else
  rm -f "${inst_etc}"/clone.rsp >/dev/null 2>&1
  export startdate=$(date '+%Y%m%d')
  export log_dir="${instance_dir}"/log/"${startdate}"
  mkdir -p "${log_dir}"  >/dev/null 2>&1
  chmod -R 777 "${log_dir}"   >/dev/null 2>&1

  update_clonersp "startdate" "${startdate}"
  update_clonersp "session_type" "\"NEW\""
  update_clonersp "recover_time" "\"${time_flag}\""
  update_clonersp "current_task_id" 50
  update_clonersp "next_task_id" 500
  update_clonersp "current_module_task" 500
  update_clonersp "session_state" "\"RUNNING\""
  update_clonersp "log_dir" "${log_dir}"
  update_clonersp "clonerspfile" "${clonerspfile}"

  new_session_banner
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: 0:CLONE RSP: clone.rsp file is created as ${clonerspfile}"
  chmod 777 "${clonerspfile}" >/dev/null 2>&1
  source "${clonerspfile}" >/dev/null 2>&1
fi

  #******************************************************************************************************##
  # Prepare Application extraction
  #******************************************************************************************************#
if [[ "${prepareapp_stage}" == "COMPLETED" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:PREPARE APP: PREPARE Application for restore stage is already completed. Moving on."
  update_clonersp "current_task_id" 1000
  update_clonersp "current_module_task" 1000
  source "${clonerspfile}" >/dev/null 2>&1
elif [[ "${current_task_id}" -ge 50 ]] && [[ "${current_task_id}" -le 600 ]] ; then
    #******************************************************************************************************##
    #  Submit application extract over ssh
    #******************************************************************************************************##
    if [[ -z "${trgappsosuser}" ]] || [[ -z "${trgapphost}" ]] || [[ -z "${labdomain}" ]] || [[ -z "${trgappname}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: All the required values are not set. Make sure property file is sourced. Exiting !!"
      exit 1
    fi

    if [[ -f "${inst_bin}/${trgappname,,}app.sh" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:REMOTE Operation Execution at ${trgadminapphost}. "
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:PREPARE APP: Submitting Application prepare job in nohup at ${trgadminapphost}. "
      ssh -q "${trgappsosuser}"@"${trgapphost}"."${labdomain}" " nohup sh ${inst_bin}/${trgappname,,}app.sh  2>&1  & "
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:PREPARE APP: Application clone script is not available. Cannot proceed. Exiting !!"
      exit 1
    fi
    #******************************************************************************************************##
    #  Monitor Application extract session for completion
    #******************************************************************************************************##
    sleep 5
    while :
      do
      source "${clonerspfile}" > /dev/null 2>&1
      if [[ "${session_state}" == "FAILED" ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:PREPARE APP: Application prepare stage is stopped with error!!"
        exit 1
      elif [[ "${current_task_id}" -ge 600 ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:PREPARE APP: Extraction stage is completed."
        break
      fi
      #sleep 20m
      #echo -e  "Waiting in the loop"
      #mailstatus
      done
fi
  update_clonersp "prepareapp_stage" "COMPLETED"

  #******************************************************************************************************##
  #  Submit database extraction, prepare and restore script over ssh
  #******************************************************************************************************##
  source "${clonerspfile}" > /dev/null 2>&1
if [[ "${db_stage}" == "COMPLETED" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB STAGE: Database restore and postclone stage is already completed. Moving on."
    update_clonersp "current_task_id" 3000
    update_clonersp "current_module_task" 3000
    source "${clonerspfile}" >/dev/null 2>&1
else
  if [[ "${current_task_id}" -ge 1000 ]]  && [[ "${current_task_id}" -le 1800  ]] ; then
    if [[ -z "${trgdbosuser}" ]] || [[ -z "${trgdbhost}" ]] || [[ -z "${labdomain}" ]] || [[ -z "${trgdbname}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: All the required values are not set. Make sure property file is sourced. Exiting !!"
      exit 1
    fi

    if [[ -f "${inst_bin}/${trgdbname,,}db.sh" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB STAGE: Submitting Database prepare and restore job in nohup at ${trgdbhost}. "
      ssh -q "${trgdbosuser}"@"${trgdbsshhost}"."${labdomain}" " nohup sh ${inst_bin}/${trgdbname,,}db.sh   2>&1 & "
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB STAGE: Database clone script is not available. Cannot proceed. Exiting !!"
      exit 1
    fi
  #******************************************************************************************************##
  #  Monitor Database restore session for completion
  #******************************************************************************************************##
  sleep 5
  while :
   do
    source "${clonerspfile}" > /dev/null 2>&1
    if [[ "${session_state}" == "FAILED" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB STAGE: Database configuration stage is stopped with errors!! Exiting !!"
      exit 1
    elif [[ "${current_task_id}" == "1800" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB STAGE: Database configuration stage is completed."
      break
    fi
  #sleep 20
  #echo -e  "Waiting in the loop"
  #mailstatus
  done
  fi
fi

   update_clonersp "db_stage" "\"COMPLETED\""
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: Exiting after completing Database configuration."
#exit 0
  #******************************************************************************************************##
  # Restore and Configure Application tier
  #******************************************************************************************************#

if [[ "${configapp_stage}" == "COMPLETED" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: CONFIG Application for restore stage is already completed. Moving on."
else
  if [[ "${current_task_id}" -ge 4000 ]] ; then
    #******************************************************************************************************##
    #  Submit application extract over ssh
    #******************************************************************************************************##
    if [[ -z "${trgappsosuser}" ]] || [[ -z "${trgapphost}" ]] || [[ -z "${labdomain}" ]] || [[ -z "${trgappname}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: All the required values are not set. Make sure property file is sourced. Exiting !!"
      exit 1
    fi

    if [[ -z "${workappspass}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: ERROR: Source Environment apps password is not loaded.\n"
      exit 1
    fi

    if [[ -z "${workwlspass}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: ERROR: Source Environment weblogic password is not loaded.\n"
      exit 1
    fi

    if [[ -f "${inst_bin}/${trgappname,,}app.sh" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: Submitting Application configure job in nohup at ${trgadminapphost}. "
      ssh -q "${trgappsosuser}"@"${trgapphost}"."${labdomain}" " nohup sh ${inst_bin}/${trgappname,,}app.sh   2>&1  & "
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: Application clone script is not available. Cannot proceed. Exiting !!"
      exit 1
    fi

    #******************************************************************************************************##
    #  Monitor Application restore and configure session for completion
    #******************************************************************************************************##
    sleep 5
    while :
      do
      source "${clonerspfile}" > /dev/null 2>&1
      if [[ "${session_state}" == "FAILED" ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: Application Configure stage is stopped with error!!"
        exit 1
      elif [[ "${current_task_id}" -ge 5000 ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:CONFIG APP: Extraction stage is completed."
        break
      fi
      #sleep 5
      #echo -e  "Waiting in the loop"
      #mailstatus
      done
  fi
fi

  update_clonersp "configapp_stage" "COMPLETED"

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL:  >>>>>>> ${trgname} clone is Completed. <<<<<<< " | tee -a  "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: CONTROL: "
echo -e "\n\n\n\n"

exit 0
#******************************************************************************************************##
#
#  **********   E N D - O F - I N S T A N C E - R E S T O R E - W R A P P E R - S C R I P T   **********
#
#******************************************************************************************************##
