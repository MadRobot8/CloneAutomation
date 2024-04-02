#!/bin/bash -n
#******************************************************************************************************
# Script Name: orasupdb.sh
# Author: Dinesh Kumar
# Created: 2021-06-29
# Last Updated: 2024-02-10
#
# Version History:
# 1.2 - 2022/07/29 - Initial version
# 1.2 - 2023/06/05 - Complete ORASUP steps updated
# 1.3 - 2023/06/05 - Modified Steps from DB DUPLICATE to RESTORE database as ORAPRD and rename to ORASUP later
# 1.4 - 2023/10/05 - Oct 2023 fixes (Rename DB correction, db_spin addition)
# 1.5 - 2024/01/12 - Jan 2024 fixes (lock file, notification mail)
# 1.6 - 2024/02/10 - Feb 2024 fixes (modification in genrman function, added check current and recover time, alert log monitoring for issue during PDB rename step )
#
# Description: This script runs database extraction, restore, and configuration steps for a specific Oracle instance.
#              It includes operations such as :
#              restoring and renaming CDB and PDB,
#              configuring CDB and PDB,
#              running FND_CONC.SETUP_CLEAN,
#              running UTL_FILE setup
#              running Autoconfig,
#              running GoldenGate SQL,
#              compiling invalid objects,
#              running scrambling SQL
#
# Usage: sh orasupdb.sh
#
#******************************************************************************************************

#******************************************************************************************************##
#
#  ********** D A T A B A S E - I N S T A N C E - R E S T O R E - W R A P P E R - S C R I P T **********
#
#******************************************************************************************************##
#******************************************************************************************************##
##	Capture and decode input variables.
#   time_flag = Database recovery time string.
#   source_flag = Source database name, if it is not default source which is set to Production.
#   restart_flag = If you want to restart the last session instead of executing a fresh session.
#   Update SOURCE database name to ORAPRD/GAHPRD etc
#******************************************************************************************************##
export dbupper="ORASUP"
export dblower=${dbupper,,}
export HOST_NAME=$(uname -n | cut -f1 -d".")
echo -e "\n\n\n\n"
#set -u
#set -o pipefail

cleanup()
{
  rm -f "/tmp/${dblower,,}db.lck" > /dev/null 2>&1
}

#trap 'cleanup ${LINENO}'  EXIT
trap cleanup  EXIT
#******************************************************************************************************##
#	Local variable declaration.
#******************************************************************************************************##
export scr_home=/u05/oracle/autoclone
# Setup oem node log dir for oem node local logs
#mkdir -p "${scr_home}"/instance/"${dbupper}"/lock > /dev/null 2>&1
#export lock_dir="${scr_home}"/instance/"${dbupper}"/lock
export notification_to="dikumar@expediagroup.com"
export notification_from="clonemailer@expedia.com"
sleep 2

sleep 1
if [[ -f "/tmp/${dblower,,}db.lck" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Lock file exists for database script, another session is still running.\n\n"
  exit 1
fi


another_instance()
{
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Another session is in progress. Exiting !!\n\n"
    echo -e "${dbupper}: Current session is terminated. There is an ongoing session still running. Please review " | mailx -r "${notification_from}" -s "${dbupper}: Another clone session is in progress. Exiting!!" "${notification_to}"
    exit 1
}


#scriptname=$(basename "$( readlink -f "${0}" )")
script_name=$(basename "$0")
# Checking if another instance of script is already running
if [[ $(pgrep -f  "${script_name}"  ) != $$ ]]; then
     another_instance
else
  echo $$ > "/tmp/${dblower}db.lck" 2>&1
fi

#******************************************************************************************************##
##	Source instance properties file
#******************************************************************************************************##

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [[ ! -f ${envfile} ]];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on database server.\n"
    echo -e "${dbupper}: Current session is terminated. Target Environment instance.prop file not found on database server " | mailx -r "${notification_from}" -s "${dbupper}: Clone session is terminated !" "${notification_to}"
    exit 1
else
    source "${scr_home}/instance/${dbupper}/etc/${dbupper}.prop"
    sleep 1
fi
unset envfile

envfile="${clonerspfile}"
if [[ ! -f "${envfile}" ]];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: clone.rsp file is not available on database node. Exiting!!\n"
    echo -e "${dbupper}: Current session is terminated. clone.rsp file not found on database server " | mailx -r "${notification_from}" -s "${dbupper}: Clone session is terminated, clone.rsp file is not available on database node. " "${notification_to}"
    exit 1
else
    source "${clonerspfile}"
    sleep 1
fi
unset envfile

mainlog="${log_dir}"/mainlogdb."${startdate}"
#******************************************************************************************************##
##	Clone rsp fun
#******************************************************************************************************##
update_clonersp()
{
  keyrsp="${1}"
  valuersp="${2}"
  sed -i "/${keyrsp}/d" "${clonerspfile}"
  echo -e  "export ${keyrsp}=${valuersp}"  >> "${clonerspfile}"
  source "${clonerspfile}" >/dev/null 2>&1
}

#******************************************************************************************************##
##	database operation functions
#******************************************************************************************************##


mail_exit()
{
  if [[ -n ${current_task_id} ]] && [[ -n ${current_dbtask} ]] && [[ -n ${current_log} ]] ; then
    echo " Database clone script is failed at phase: ${current_dbtask}, TASK ID: ${current_task_id}. Please review." > /tmp/tempmailerbody.tmp
    cat "${current_log}" >>  /tmp/tempmailerbody.tmp
    cat "/tmp/tempmailerbody.tmp" | mailx -r "${notification_from}" -s "ERROR:${dblower}:  The database restore script for ${dblower} is failed. Please review logs" "${notification_to}"
  elif [[ -n ${current_task_id} ]] && [[ -n ${current_dbtask} ]] && [[ -z ${current_log} ]] ; then
    echo " Database clone script is failed at phase: ${current_dbtask}, TASK ID: ${current_task_id}. Please review. " | mailx -r "${notification_from}" -s "ERROR:${dblower}:  The database restore script for ${dblower} is failed. Please review logs" "${notification_to}"
  elif [[ -n ${current_task_id} ]] && [[ -z ${current_dbtask} ]] && [[ -z ${current_log} ]] ; then
    echo " Database clone script is failed at TASK ID: ${current_task_id}. Please review. " | mailx -r "${notification_from}" -s "ERROR:${dblower}:  The database restore script for ${dblower} is failed. Please review logs" "${notification_to}"
  else
    echo " Database clone script is failed Please review. " | mailx -r "${notification_from}" -s "ERROR:${dblower}:  The database restore script for ${dblower} is failed. Please review logs" "${notification_to}"
  fi

  cleanup
  exit 1
}

db_spin()
{

envfile="${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
if [[ ! -f ${envfile} ]];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment instance.properties file not found on application server.\n"
    mail_exit
else
    source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop
    sleep 1
fi
unset envfile

envfile="${clonerspfile}"
if [[ ! -f "${envfile}" ]];  then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: clone.rsp file is not available on application node. Exiting!!\n"
    mail_exit
else
    source "${clonerspfile}"
    sleep 1
fi
unset envfile

if [[ -z "${control_owner}" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:SPIN: Control owner is not set, no script will be executed. Exiting !!"
  mail_exit
fi

#echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL:DB WAIT: Waiting for db steps to completed. "
# The script will spin and wait to change the control_owner and proceed after control_owner is as per current child.
while :
do
    source "${clonerspfile}" > /dev/null 2>&1
    if [[ ${control_owner} == "shared" ]] || [[ ${control_owner} == "db" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: "
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: Control is with database child script, application script will wait. "
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:CONTROL: "
      break
    fi
  sleep 43
done
}

# Check for both CDB status only
check_cdbstatus()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
rm -f /tmp/checkcdb"${trgcdbname^^}".tmp >/dev/null 2>&1

check_stat=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkcdb"${trgcdbname^^}".tmp
select status from v\$instance ;
spool off
exit
EOF
)

cstat="${check_stat//[[:blank:]]/}"

if [[ "${cstat}" == "STARTED" ]]; then
    export cdbstatus="NOMOUNT"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: CDB status is ${cdbstatus}. "
elif [[ "${cstat}" == "MOUNTED" ]]; then
    export cdbstatus="MOUNT"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: CDB status is ${cdbstatus}. "
elif [[ "${cstat}" == "OPEN" ]]; then
    export cdbstatus="OPEN"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: CDB status is ${cdbstatus}. "
elif [[ "${cstat}" == *"ORA-01034"* ]] ; then
    export cdbstatus="DOWN"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: CDB status is ${cdbstatus}. "
else
    export cdbstatus="UNKNOWN"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: CDB status is ${cdbstatus}. "
fi

rm -f /tmp/checkcdb"${dbupper}".tmp >/dev/null 2>&1
}

# Check for both CDB and PDB status
check_dbstatus()
{

rm -f /tmp/checkpdb"${trgcdbname}".tmp >/dev/null 2>&1
check_cdbstatus
if [[ "${cdbstatus}" == "OPEN" ]]; then
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1

check_stat=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkpdb"${trgcdbname^^}".tmp
select open_mode from v\$pdbs;
spool off
exit
EOF
)

pstat="${check_stat//[[:blank:]]/}"

  if [[ "${pstat}" == *"MOUNT"* ]]; then
    export pdbstatus="MOUNT"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS: PDB status is ${pdbstatus}. " | tee -a "${mainlog}"

  elif [[ "${pstat}" == *"WRITE"* ]]; then
    export pdbstatus="OPEN"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS: PDB status is ${pdbstatus}. " | tee -a "${mainlog}"
  elif [[ "${pstat}" == *"ONLY"* ]]; then
    export pdbstatus="READ_ONLY"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS: PDB status is ${pdbstatus}. " | tee -a "${mainlog}"
  else
    export pdbstatus="UNKNOWN"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK PDB STATUS: Could not determine pluggable database status. " | tee -a "${mainlog}"
  fi
fi

rm -f /tmp/checkpdb"${dbupper}".tmp >/dev/null 2>&1
}


srcpdb_exists()
{
check_cdbstatus
unset srcpdbexist > /dev/null 2>&1
unset spdbexist > /dev/null 2>&1
checkspdb="${srdbname}"
if [[ "${cdbstatus}" == "OPEN" ]]; then
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1

spdbexist=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
select count(*) from v\$pdbs where NAME='${checkspdb}';
exit
EOF
)

sleep 2
check_spdbexist="${spdbexist//[[:blank:]]/}"
export srcpdbexist="${check_spdbexist}"
#echo -e "Source pdb exists ${srcpdbexist} "
fi
}

trgpdb_exists()
{
check_cdbstatus
unset trgpdbexist > /dev/null 2>&1
unset tpdbexist > /dev/null 2>&1
checktpdb="${trgdbname}"
if [[ "${cdbstatus}" == "OPEN" ]]; then
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
tpdbexist=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
select count(*) from v\$pdbs where NAME='${checktpdb}';
exit
EOF
)

#echo -e "Checking target pdb: ${checktpdb} and variable tpdbexist 3 : ${tpdbexist}"
sleep 2
check_tpdbexist="${tpdbexist//[[:blank:]]/}"
export trgpdbexist="${check_tpdbexist}"
#echo -e "Target pdb exists ${trgpdbexist} "
fi
}

# Startup and check PDB/CDB status
startdb_sqlplus()
{
echo 'startup;' | "${ORACLE_HOME}"/bin/sqlplus -s  '/ as sysdba' >>  "${log_dir}"/startup${dbupper^^}."${startdate}" 2>&1
check_cdbstatus
}

abortdb_sqlplus()
{
echo 'shutdown abort;' | "${ORACLE_HOME}"/bin/sqlplus  '/ as sysdba' >>  "${log_dir}"/abortdb${dbupper^^}."${startdate}"  2>&1
check_cdbstatus
}


check_cdbwallet()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
rm -f /tmp/checkcdbwallet"${trgcdbname^^}".tmp >/dev/null 2>&1

check_wstat=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkcdbwallet"${trgcdbname^^}".tmp
select status from v\$encryption_wallet WHERE WRL_PARAMETER IS NOT NULL;
spool off
exit
EOF
)

cstatw="${check_wstat//[[:blank:]]/}"
# Wallet status can be CLOSED/NOT_AVAILABLE/OPEN/OPEN_NO_MASTER_KEY/OPEN_UNKNOWN_MASTER_KEY_STATUS/UNDEFINED
export walletstatus="${cstatw}"
update_clonersp "walletstatus" "${cstatw}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet status is ${walletstatus}. "
rm -f /tmp/checkcdbwallet"${dbupper}".tmp >/dev/null 2>&1
}

check_pdbwallet()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
rm -f /tmp/checkpdbwallet"${trgcdbname^^}".tmp >/dev/null 2>&1
v_pdbname=${1}

if [[ -z "${v_pdbname}" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: NO PDB name provided. Cannot proceed. Exiting !! "
  mail_exit
fi

check_pwstat=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
ALTER SESSION SET CONTAINER=${v_pdbname} ;
spool /tmp/checkpdbwallet"${trgcdbname^^}".tmp
select status from v\$encryption_wallet;
spool off
exit
EOF
)

cstatpw="${check_pwstat//[[:blank:]]/}"
# Wallet status can be CLOSED/NOT_AVAILABLE/OPEN/OPEN_NO_MASTER_KEY/OPEN_UNKNOWN_MASTER_KEY_STATUS/UNDEFINED
export pdbwalletstatus="${cstatpw}"
update_clonersp "pdbwalletstatus" "${cstatpw}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: PDB Wallet status is ${pdbwalletstatus}. "
rm -f /tmp/checkcpdbwallet"${dbupper}".tmp >/dev/null 2>&1
}



check_wallet_login()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
rm -f /tmp/checkwalletauto"${trgcdbname^^}".tmp >/dev/null 2>&1

check_autol=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkwalletauto"${trgcdbname^^}".tmp
select WALLET_TYPE from v\$encryption_wallet WHERE WRL_PARAMETER IS NOT NULL;
spool off
exit
EOF
)

autol="${check_autol//[[:blank:]]/}"
# Wallet status can be AUTOLOGIN/PASSWORD/UNKNOWN
export walletlogin="${autol}"
update_clonersp "walletlogin" "${walletlogin}"
update_clonersp "walletstatus" "${walletstatus}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET LOGIN: Wallet Login is ${walletlogin}. "
rm -f /tmp/checkwalletauto"${dbupper}".tmp >/dev/null 2>&1
}

open_wallet_autologin()
{
  source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1

  check_wallet_login
  if [[ "${walletlogin}" == "AUTOLOGIN" ]] ; then
      check_cdbwallet
      if [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is OPEN with AUTOLOGIN. "
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is AUTOLOGIN, but it is not working. EXITING !!"
        update_clonersp "walletlogin" "${walletlogin}"
        update_clonersp "walletstatus" "${walletstatus}"
        mail_exit
      fi

  elif [[ "${walletlogin}" == "PASSWORD" ]] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet status is ${walletlogin}, creating AUTOLOGIN wallet. "
        mv "${trgdbwalletpath}/cwallet.sso" "${trgdbwalletpath}/cwallet.sso${startdate}" >/dev/null 2>&1
        "${ORACLE_HOME}"/bin/orapki wallet create -wallet "${trgdbwalletpath}" -pwd "${trgdbwalletpwd}" -auto_login > "${log_dir}"/create_autologinwallet1."${startdate}" 2>&1
        if [[ -f "${trgdbwalletpath}/cwallet.sso" ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Autologin wallet is created successfully."
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: cwallet.sso file not found. Unable to create autologin wallet. Exiting !!"
        fi
        check_wallet_login
        check_cdbwallet
        if [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is OPEN with AUTOLOGIN. "
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is AUTOLOGIN, but it is not working. EXITING !!"
          update_clonersp "walletlogin" "${walletlogin}"
          update_clonersp "walletstatus" "${walletstatus}"
          mail_exit
        fi
  elif [[ "${walletlogin}" == "UNKNOWN" ]] ; then
        if [[ -f "${trgdbwalletpath}/cwallet.sso" ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: cwallet.sso file is found, autologin wallet is already present."
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: cwallet.sso file is not found, creating Autologin wallet."
          "${ORACLE_HOME}"/bin/orapki wallet create -wallet "${trgdbwalletpath}" -pwd "${trgdbwalletpwd}" -auto_login > "${log_dir}"/create_autologinwallet2."${startdate}" 2>&1
          check_wallet_login
           if [[ -f "${trgdbwalletpath}/cwallet.sso" ]] ; then
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Autologin wallet is created successfully."
           else
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: cwallet.sso file not found. Unable to create autologin wallet. Exiting !!"
             update_clonersp "walletlogin" "${walletlogin}"
             update_clonersp "walletstatus" "${walletstatus}"
             mail_exit
           fi
        fi

        check_cdbwallet
        if [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is OPEN with AUTOLOGIN. "
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:WALLET STATUS: Wallet is AUTOLOGIN, but it is not working. EXITING !!"
          update_clonersp "walletlogin" "${walletlogin}"
          update_clonersp "walletstatus" "${walletstatus}"
          mail_exit
        fi
  fi

  update_clonersp "walletlogin" "${walletlogin}"
  update_clonersp "walletstatus" "${walletstatus}"
}

# Password validate function ######
chk_password()
{
unpw="apps/${1}@${trgdbname}"
sqlplus -s -L  /nolog > /dev/null 2>&1 <<EOF
whenever sqlerror exit 1
whenever oserror exit 1
connect ${unpw}
exit
EOF

if [ $? -ne 0 ]; then
    #   echo -e "return 1"
    return 1
else
  return 0
fi
}

# Validate which APPS password is working - Source or Target
validate_apps_password()
{
export APPSUSER=$(/dba/bin/getpass "${dbupper^^}" apps)
export APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)

chk_password "${workappspass}"
_chkTpassRC1=$?
sleep 2
chk_password "${APPSPASS}"
_chkTpassRC2=$?
sleep 2
if [[ ${_chkTpassRC1} -eq 0 ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:VALIDATE APPS PASS:****  Source APPS Password is working. **** " | tee -a "${mainlog}"
  export workappspass
elif [[ ${_chkTpassRC2} -eq 0 ]] ; then
  export workappspass="${APPSPASS}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:VALIDATE APPS PASS:****  Target APPS Password is working. **** " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:VALIDATE APPS PASS:****  WARNING:Source and Target - Both APPS passwords are not working, Cannot proceed with autoconfig on database. Exiting !!" | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi
}

# Extract sql and files level backups
extract_db()
{

  #******************************************************************************************************##
  #  Create directories for extraction
  #******************************************************************************************************##

mkdir  -p  "${currentextractdir}"/tns  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/ctx  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/env  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/dbs  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/app_others > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/pairs  > /dev/null 2>&1
mkdir  -p  "${currentextractdir}"/app_others/wallet > /dev/null 2>&1
mkdir  -p  "${uploaddir}"/sql > /dev/null 2>&1

chmod -R 777   "${currentextractdir}"  "${uploaddir}"  > /dev/null 2>&1

  #***************************************************************************************************###
  # Cleaning up old scripts and creating new extract scripts from Database for Post clone Upload part.
#***************************************************************************************************###

dbextractlog="${extractlogdir}"/extractDB"${dbupper^^}"."${startdate}"

cd "${extractdir}"
if [ -d "${currentextractdir}" ] ;  then
	cp -pr  "${currentextractdir}"  "${bkpextractdir}"/"$(date +'%d-%m-%Y')" > /dev/null 2>&1
fi

mkdir -p "${currentextractdir}" > /dev/null 2>&1

  #***************************************************************************************************###
  # Run extraction for database sql and file system
  #***************************************************************************************************###
cd "${inst_sql}"

export APPSUSER=$(/dba/bin/getpass "${dbupper^^}" apps)
export APPSPASS=$(echo "${APPSUSER}" | cut -d/ -f 2)

if [[ "${pdbstatus}" == "OPEN" && -z "${dbsqlextract}"  ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: Logfile at ${dbextractlog}" | tee "${dbextractlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: Extracting Database pfile/spfile  " | tee -a "${dbextractlog}"
sqlplus -s / 'as sysdba' << EOF   >/dev/null
create pfile='${bkpinitdir}/init${trgcdbname}.ora.spfile'  from spfile ;
create pfile='${bkpinitdir}/init${trgcdbname}.ora.memory'  from spfile ;
exit
EOF

if [[ -f  "${ORACLE_HOME}"/dbs/spfile"${ORACLE_SID}".ora ]] ;  then
		cp "${ORACLE_HOME}"/dbs/spfile"${ORACLE_SID}".ora  "${bkpinitdir}"/.
fi

sqlplus -s / 'as sysdba' << EOF >/dev/null
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 100
spool ${bkpinitdir}/parameterinfo.txt
select value from v\$parameter where name='spfile';
select value from v\$parameter where name='control_files' ;
spool off
exit
EOF

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: Extracting Database sql  " | tee -a "${dbextractlog}" "${mainlog}"
sqlplus / 'as sysdba' << EOF >/dev/null
set head off
set feed off
set line 999
spool ${inst_sql}/cdb_create_db_directories.sql
col SQL FOR a150
set pages 2000
select 'set echo on ; ' from dual;
select 'CREATE OR REPLACE DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' as  '||''''||DIRECTORY_PATH ||''''||';'  SQL from DBA_DIRECTORIES ;
select 'GRANT READ, WRITE ON  DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' TO APPS;'  SQL from DBA_DIRECTORIES ;
spool off
EOF

sqlplus / 'as sysdba' << EOF >/dev/null
ALTER SESSION SET CONTAINER=${trgdbname} ;
set head off
set feed off
set line 999
spool ${inst_sql}/pdb_create_db_directories.sql
col SQL FOR a150
set pages 2000
select 'set echo on ; ' from dual;
select 'CREATE OR REPLACE DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' as  '||''''||DIRECTORY_PATH ||''''||';'  SQL from DBA_DIRECTORIES ;
select 'GRANT READ, WRITE ON  DIRECTORY '||'"'||DIRECTORY_NAME||'"'||' TO APPS;'  SQL from DBA_DIRECTORIES ;
spool off
spool ${uploaddir}/sql/pdb_backup_apps_profiles.sql
SELECT DISTINCT 'update fnd_profile_option_values set PROFILE_OPTION_VALUE='||''''||fpov.profile_option_value||''''||' where  PROFILE_OPTION_ID='||fpov.profile_option_id||' AND level_id ='||fpov.level_id||' ; '
    FROM apps.fnd_profile_options fpo,
         apps.fnd_profile_option_values fpov,
         apps.fnd_profile_options_tl fpot,
         apps.fnd_user fu,
         apps.fnd_application fap,
         apps.fnd_responsibility frsp,
         apps.fnd_nodes fnod,
         apps.hr_operating_units hou
   WHERE     fpo.profile_option_id = fpov.profile_option_id(+)
         AND fpo.profile_option_name = fpot.profile_option_name
         AND fu.user_id(+) = fpov.level_value
         AND frsp.application_id(+) = fpov.level_value_application_id
         AND frsp.responsibility_id(+) = fpov.level_value
         AND fap.application_id(+) = fpov.level_value
         AND fnod.node_id(+) = fpov.level_value
         AND hou.organization_id(+) = fpov.level_value ;
select 'commit ; ' from dual;
select 'exit ; ' from dual;
spool off
spool ${inst_sql}/pdb_add_tempfiles.sql
select 'set echo on ; ' from dual;
select 'ALTER TABLESPACE '||tablespace_name||' ADD TEMPFILE '||''''||'${trgasmdg}'||''''||' size 100M autoextend on maxsize 30g ;'  from dba_temp_files ;
select 'exit ; ' from dual;
spool off
set lines 200
set pages 2000
spool ${inst_sql}/pdb_all_dbuser_pass.sql
select ' ALTER USER "'||NAME||'" IDENTIFIED BY VALUES '||''''||PASSWORD||''''||'  ACCOUNT UNLOCK ;'
from user\$
where NAME in (select username from dba_users where profile in ('SERVICE_EXPD','USER_EXPD') ) ;
spool off
set lines 200
set pages 2000
@${inst_sql}/save_masterlist.sql
EOF

update_clonersp "dbsqlextract" "COMPLETED"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: Database sql extraction is skipped. " | tee -a "${mainlog}" "${dbextractlog}"
  update_clonersp "dbsqlextract" "PASS"
fi


if [[ -z "${dbfileextract}" ]] ; then
#******************************************************************************************************
#  Backup important files, to be restored as post clone process
#******************************************************************************************************

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: Extracting TNS, CONTEXT, ENV, Certs files from Database node.   " | tee -a "${dbextractlog}" "${mainlog}"
cp  "${CONTEXT_FILE}"  "${currentextractdir}"/ctx/.   > /dev/null 2>&1
cp  "${ORACLE_HOME}"/*.env   "${currentextractdir}"/env/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/dbs/*"${ORACLE_SID}"*   "${currentextractdir}"/dbs/.  > /dev/null 2>&1
cp -pr "${ORACLE_HOME}"/dbs/"${trgdbname^^}"_utlfiledir.txt   "${currentextractdir}"/dbs/.  > /dev/null 2>&1
cp  -pr "${TNS_ADMIN}"/*   "${currentextractdir}"/tns/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/appsutil  "${currentextractdir}"/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/wso2wallet  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/wso2wallet2  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1
cp -pr  "${ORACLE_HOME}"/awswallet  "${currentextractdir}"/db_others/wallet/.  > /dev/null 2>&1

{
ls -lrt "${currentextractdir}"/*
ls -rlt "${currentextractdir}"/db_others/wallet/*
ls -rlt "${currentextractdir}"/db_others/*
} >> "${dbextractlog}" 2>&1

## backup utrlp.sql from ORACLE_HOME
cp "${ORACLE_HOME}"/rdbms/admin/utlrp.sql  "${uploaddir}"/sql/.  > /dev/null 2>&1
echo 'exit ' >> "${uploaddir}"/sql/utlrp.sql
cp "${ORACLE_HOME}"/rdbms/admin/utlprp.sql "${uploaddir}"/sql/.  > /dev/null 2>&1
  update_clonersp "dbfileextract" "COMPLETED"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB EXTRACT: File copy/backup extraction is skipped.   " | tee -a "${dbextractlog}" "${mainlog}"
  update_clonersp "dbfileextract" "PASS"
fi

}

# delete archive logs
delarchivelog()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  > /dev/null 2>&1
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:PREPARE DB: Deleting Archive log files.   " | tee -a  "${mainlog}"
rm -f "${inst_etc}"/delarchive.cmd > /dev/null 2>&1
{
echo -e "connect target /;"
echo -e " run { "
echo -e "ALLOCATE CHANNEL Ch1 FOR MAINTENANCE DEVICE TYPE DISK; "
echo -e "delete noprompt archivelog all;"
echo -e " }"
echo -e " exit "
} >> "${inst_etc}"/delarchive.cmd

rman cmdfile="${inst_etc}"/delarchive.cmd  log="${log_dir}"/delarchive"${trgcdbname^^}"."${startdate}" >/dev/null 2>&1
}

stop_and_drop()
{
delarchivelog
if [[ "${cdbdrop}" == "COMPLETED" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:PREPARE DB: Clone.rsp says database is already dropped." | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:PREPARE DB: Executing DROP DATABASE." | tee -a "${mainlog}"

sqlplus  '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${log_dir}/spool_dropdb${trgcdbname^^}.${startdate}
ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;
shutdown abort;
startup mount exclusive;
alter system enable restricted session;
DROP DATABASE;
SPOOL OFF ;
exit
EOF

fi

check_cdbstatus
if [[ "${cdbstatus}" == "DOWN" ]]; then
update_clonersp "cdbdrop" "COMPLETED"
fi

}

startup_for_restore()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile >/dev/null 2>&1

check_cdbstatus
if [ "${cdbstatus}" == "DOWN" ] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
    if [ -f "${bkpinitdir}"/init"${trgcdbname}".ora.memory ] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Backup init file found, creating spfile from backup pfile. " | tee -a "${mainlog}"

sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${log_dir}/spool_createSpfile${trgcdbname^^}.${startdate}
STARTUP pfile='${bkpinitdir}/init${trgcdbname}.ora.memory' NOMOUNT;
create spfile='${trgdbspfile}' from pfile='${bkpinitdir}/init${trgcdbname}.ora.memory'  ;
SHUTDOWN ABORT;
startup nomount ;
alter system set db_name=${trgcdbname} scope=SPFILE ;
spool off ;
exit
EOF

echo -e "*.spfile='${trgdbspfile}'" > "${ORACLE_HOME}"/dbs/init"${ORACLE_SID}".ora
check_cdbstatus
    fi

elif [[ "${cdbstatus}" == "MOUNT" || "${cdbstatus}" == "OPEN"  ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
  stop_and_drop
      if [ -f "${bkpinitdir}"/init"${trgcdbname}".ora.memory ] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Backup init file found, creating spfile from backup pfile. " | tee -a "${mainlog}"
sqlplus '/ as sysdba'  << EOF > /dev/null
set echo on ;
spool ${log_dir}/spool_createSpfile${trgcdbname^^}.${startdate}
STARTUP pfile='${bkpinitdir}/init${trgcdbname}.ora.memory' NOMOUNT;
create spfile='${trgdbspfile}' from pfile='${bkpinitdir}/init${trgcdbname}.ora.memory'  ;
SHUTDOWN ABORT;
startup nomount ;
spool off ;
exit
EOF

  echo -e "*.spfile='${trgdbspfile}'" > "${ORACLE_HOME}"/dbs/init"${ORACLE_SID}".ora
  check_cdbstatus
    fi
elif [ "${cdbstatus}" == "NOMOUNT" ]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
  abortdb_sqlplus
  startdb_sqlplus
    if [ "${cdbstatus}" == "NOMOUNT" ]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Database is up in ${cdbstatus} status, not compatible for restore. " | tee -a  "${mainlog}"
    fi
fi


sqlplus '/ as sysdba'  << EOF  > /dev/null
set echo on ;
spool ${log_dir}/spool_startupRestore${trgcdbname^^}.${startdate}
STARTUP NOMOUNT;
ALTER SYSTEM SET DB_NAME=${srccdbname^^} scope=SPFILE ;
ALTER SYSTEM SET db_unique_name=${trgcdbname^^} scope=SPFILE ;
ALTER SYSTEM SET cluster_database=FALSE scope=SPFILE ;
SHUTDOWN ABORT;
STARTUP NOMOUNT;
spool off ;
exit
EOF

check_cdbstatus
if [[ ${cdbstatus} == "NOMOUNT" ]] ; then
  update_clonersp "cdbstatus" "${cdbstatus}"
  update_clonersp "pdbstatus" "${pdbstatus}"
  update_clonersp "prepare_db" "COMPLETED"
  source "${clonerspfile}" >/dev/null 2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Database is ready for RESTORE. " | tee -a "${mainlog}"
  open_wallet_autologin
elif [[ ${cdbstatus} == "DOWN" ]] ; then
  update_clonersp "cdbstatus" "${cdbstatus}"
  update_clonersp "pdbstatus" "${pdbstatus}"
  update_clonersp "prepare_db" "FAILED"
  update_clonersp "session_state" "FAILED"
  source "${clonerspfile}" >/dev/null 2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Database is down. Cannot proceed for RESTORE. Exiting !! \n\n " | tee -a "${mainlog}"
  mail_exit
else
  source "${clonerspfile}" >/dev/null 2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:STARTUP RESTORE: Init/spfile backup could not be found to start database restore. Exiting !! \n\n" | tee -a "${mainlog}"
  mail_exit
fi
}

check_delay()
{
  source /home/"$(whoami)"/."${trgcdbname,,}"_profile >/dev/null 2>&1
  source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop >/dev/null 2>&1
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Validating recover time: ${recover_time} with current time...script will wait for another backup to complete. " | tee -a "${mainlog}"
  if [[ -z "${recover_time}" ]] ; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Recovery time is not set. " | tee -a "${mainlog}"
  fi

  given_datetime="${recover_time}"
  given_seconds=$(date -d "${given_datetime}" +%s)
  current_seconds=$(date +%s)

  # If Recovery date/time is in future, any future date greater than 24hrs will not be accepted
if [[ ${given_seconds} -gt ${current_seconds} ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Recovery time is in future " | tee -a "${mainlog}"
    diff_seconds=$((given_seconds - current_seconds))
    if [[ $diff_seconds -gt 86400 ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Recovery time is more than 24 hours in future. " | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Please make sure recovery time is correcr and less than 24 hours in future. " | tee -a "${mainlog}"
      sleep 600
      mail_exit
    fi

    if [[ $diff_seconds -lt 86400 ]]; then
      while true; do
       # Get the current date-time in seconds from Unix Epoch Time
        current_seconds=$(date +%s)
        # Calculate the difference in hours
        if [[ ${given_seconds} -gt ${current_seconds} ]]; then
          # Wait for 10 minutes before checking again
          sleep 10
        else
          break
        fi
      done
    fi
fi

current_seconds=$(date +%s)
if [[ ${given_seconds} -eq ${current_seconds} ]]; then
  sleep 10
  current_seconds=$(date +%s)
fi

if [[ ${current_seconds} -gt ${given_seconds} ]]; then
diff_seconds=$((current_seconds - given_seconds))
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Clone script will check and delay for another archive backup to complete. " | tee -a "${mainlog}"
  # Check if the difference is less than 2 hours (7200 seconds)
  if [[ ${diff_seconds} -lt 7200 ]]; then
    # Wait for the remaining time
    remaining_seconds=$((7200 - diff_seconds))
    #echo "Waiting for $remaining_seconds seconds..."
    sleep ${remaining_seconds}
  fi
  # Print a message and exit
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK DELAY: Clone script waiting time is completed...Proceeding further. " | tee -a "${mainlog}"
fi
}

db_ready()
{
dbpscount=$(ps -ef | grep -v grep| grep -ic "${trgcdbname}" )
if [ "${dbpscount}" -gt 5 ]; then
  export dbprocess="running"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database processes are running." | tee -a "${mainlog}"
  check_cdbstatus
  if [[ "${cdbstatus}" == "OPEN" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
    stop_and_drop
    startup_for_restore
  elif [[ "${cdbstatus}" == "MOUNT" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database is in ${cdbstatus} state currently." | tee -a "${mainlog}"
    stop_and_drop
    startup_for_restore
  elif [[ "${cdbstatus}" == "NOMOUNT" ]]; then
     echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database processes are running but the database is in NOMOUNT state." | tee -a "${mainlog}"
     echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database will be validated for restart." | tee -a "${mainlog}"
    abortdb_sqlplus
    startdb_sqlplus
      if [[ "${cdbstatus}" == "STARTED" ]]; then
        startup_for_restore
      elif [[ "${cdbstatus}" == "OPEN" ]]; then
          stop_and_drop
          startup_for_restore
      elif [[ "${cdbstatus}" == "MOUNT" ]]; then
        stop_and_drop
        startup_for_restore
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database is not running. Cannot proceed Exiting!!." | tee -a "${mainlog}"
        mail_exit
      fi
  fi
elif [ "${dbpscount}" -le 5 ]; then
   export dbprocess="stopped"
   echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database processes are not running." | tee -a "${mainlog}"
   echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS: Container Database will be validated for restart." | tee -a "${mainlog}"
   startdb_sqlplus
    if [[ "${cdbstatus}" == "STARTED" ]]; then
        startup_for_restore
    elif [[ "${cdbstatus}" == "OPEN" ]]; then
            stop_and_drop
            startup_for_restore
    elif [[ "${cdbstatus}" == "MOUNT" ]]; then
           stop_and_drop
           startup_for_restore
    elif [[ "${cdbstatus}" == "DOWN" ]]; then
      startup_for_restore
      if [[ "${cdbstatus}" == "DOWN" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CHECK CDB STATUS : Container Database for target could not be started for restore. Exiting !! " | tee -a "${mainlog}"
      update_clonersp "prepare_db" "FAILED"
      update_clonersp "session_state" "FAILED"
      #Fail_exit
      mail_exit
      fi
    fi
fi

 }


genrman()
{

source /home/"$(whoami)"/."${trgcdbname,,}"_profile >/dev/null 2>&1
source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop >/dev/null 2>&1
source "${clonerspfile}" >/dev/null 2>&1

check_delay

vstdate="$(date --date=' 1 days ago' '+%m/%d/%Y')"
venddate="$(date '+%m/%d/%Y')"
#rec_datetime="${recover_time}"
#rec_seconds=$(date -d "${rec_datetime}" +%s)
#rec_date_informat=$(date -d "${rec_datetime}" '+%m/%d/%Y')
#Increment for 24hours
##nexday_seconds=$((rec_seconds + 86400))
#rec_enddate=$(date -d "@${nexday_seconds}" '+%m/%d/%Y')
#echo "Given date-time: ${rec_datetime}"
#echo "Given date: ${given_date_informat}"
#echo "Current date: $(date '+%m/%d/%Y')"
#echo "Next day: ${nextday_date}"
#export RMANUSER=$(/dba/bin/getpass "RMANDB" rmancat)
#export RMANCONNECT="${RMANUSER}"@RMANDB

export rmancmdfile="${inst_etc}"/${trgdbname}_rman.cmd
rm -f "${rmancmdfile}" >/dev/null 2>&1

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GEN RMAN CMD: Checking Netbackup for controlfile backup between ${vstdate} and ${venddate}. " | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GEN RMAN CMD: " | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GEN RMAN CMD: " | tee -a "${mainlog}"
#chkctl=$(/usr/openv/netbackup/bin/bplist -S "${srcnbkpserver}" -C "${srcnbkpclient}" -t 4 -s "${rec_datetime}" -e "${rec_enddate}" -l -R /c-${srcdbid}*  |sort | awk '{print $NF}' |tail -1 )
chkctl=$(/usr/openv/netbackup/bin/bplist -S "${srcnbkpserver}" -C "${srcnbkpclient}" -t 4 -s "${vstdate}" -e "${venddate}" -l -R /c-${srcdbid}*  |sort | awk '{print $NF}' |tail -1 )
ctrl_backup_file="${chkctl///}"

{
echo -e "connect target / "
#echo -e "connect CATALOG ${RMANCONNECT} "
echo -e " run "
echo -e "{ "
echo -e " allocate channel ch1 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch2 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch3 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch4 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch5 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch6 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch7 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch8 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch9 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch10 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch11 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch12 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch13 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch14 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " allocate channel ch15 device type SBT_TAPE  PARMS 'ENV=(NB_ORA_SERV=${srcnbkpserver},NB_ORA_CLIENT=${srcnbkpclient})'; "
echo -e " restore controlfile from '${ctrl_backup_file}' ; "
echo -e " ALTER DATABASE MOUNT; "
#echo -e " set dbid=${srcdbid}; "
echo -e " set until time \"to_date('${recover_time}', 'DD-MON-YYYY HH24:MI:SS')\"; "
echo -e " set newname for database to '${trgasmdg}'; "
#echo -e " DUPLICATE DATABASE ${srccdbname} DBID=${srcdbid} to ${trgcdbname} nofilenamecheck ; "
echo -e "restore database; "
echo -e "switch datafile all; "
echo -e "recover database; "
echo -e "ALTER DATABASE DISABLE BLOCK CHANGE TRACKING; "
echo -e "ALTER DATABASE OPEN RESETLOGS ; "
#echo -e "ALTER DATABASE CLOSE ; "
echo -e "} "
echo -e "exit "
} >> "${rmancmdfile}"


if [[ -f "${rmancmdfile}" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GEN RMAN CMD: RMAN CMD file is generated as ${rmancmdfile} " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GEN RMAN CMD: ERROR: RMAN CMD file is not generated. Cannot proceed. Exiting !! \n\n " | tee -a "${mainlog}"
  mail_exit
fi

update_clonersp "rmancmdgenerated" "COMPLETED"
update_clonersp "rmancmdfile" "${rmancmdfile}"
}


execrman()
{

source /home/"$(whoami)"/."${trgcdbname,,}"_profile >/dev/null 2>&1
source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop >/dev/null 2>&1

# check and generate RMAN restore command file
if [[ -z ${rmancmdgenerated} ]]; then
  genrman
fi

export rmanrestorelog="${log_dir}"/rmanrestore_"${trgdbname^^}"."${startdate}"
rm -f "${rmanrestorelog}"  > /dev/null 2>&1

if [[ -f "${rmancmdfile}" ]]; then
  nohup "${ORACLE_HOME}"/bin/rman cmdfile="${rmancmdfile}" log="${rmanrestorelog}" > /dev/null 2>&1 &
  update_clonersp "rman_restore" "RUNNING"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: RMAN restore logfile : ${rmanrestorelog} " | tee -a "${mainlog}"
  sleep 10
  loop_cnt=0
  while ps -eaf|grep -i "${trgdbname}"| grep rman |grep -v grep &>/dev/null;
  #while pgrep "${rmancmdfile}" |grep -v grep &>/dev/null;
  do
    if [[ -f "${rmanrestorelog}" ]]; then
      if grep -qE 'ORA-19507|ORA-27029|ORA-19511' "${rmanrestorelog}"
      then
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: ERROR: RMAN restore is failed due to TAPE error. " | tee -a "${mainlog}"
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: ERROR: Please validate if the TAPE is available or backup is available in TAPE " | tee -a "${mainlog}"
            update_clonersp "rman_restore" "FAILED"
            update_clonersp "session_state" "FAILED"
            mail_exit
      fi


      if grep -qE 'Alter clone database open resetlogs' "${rmanrestorelog}"
        then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Restore is completed. Opening database. " | tee -a "${mainlog}"
      elif grep -qE 'archived log file' "${rmanrestorelog}"
        then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Recovery in progress." | tee -a "${mainlog}"
      elif grep -qE 'starting media recovery' "${rmanrestorelog}"
        then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Restore is completed, running recovery." | tee -a "${mainlog}"
      elif grep -qE 'INCR' "${rmanrestorelog}"
        then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Restore is completed, applying incremental backup." | tee -a "${mainlog}"
      else
        filecnt=$(grep -ic 'restoring datafile' "${rmanrestorelog}" )
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Files restored : ${filecnt}" | tee -a "${mainlog}"
      fi

    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: Status : Logfile not found. Exiting !! " | tee -a "${mainlog}"
      #fail_exit
      update_clonersp "rman_restore" "FAILED"
      update_clonersp "session_state" "FAILED"
      mail_exit
    fi
    sleep 10m
    loop_cnt=$((loop_cnt+1))
  done

  if grep -qE 'RMAN-03002|RMAN-00571|RMAN-00569|RMAN-06054|RMAN-06053|RMAN-06025|RMAN-06013|ORA-01103|ORA-01547|ORA-01194|ORA-01110' "${rmanrestorelog}"
    then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: ERROR: RMAN restore script failed.  EXITING !! \n " | tee -a "${mainlog}"
    update_clonersp "rman_restore" "FAILED"
    update_clonersp "session_state" "FAILED"
    mail_exit
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: RMAN restore script completed. " | tee -a "${mainlog}"
    update_clonersp "rman_restore" "COMPLETED"
    sleep 2
  fi
 else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RMAN RESTORE: ERROR: RMAN restore script not found.  EXITING !! \n " | tee -a "${mainlog}"
  update_clonersp "rman_restore" "FAILED"
  update_clonersp "session_state" "FAILED"
  mail_exit
fi
}


rename_cdb()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
source "${scr_home}"/instance/"${dbupper}"/etc/"${dbupper}".prop >/dev/null 2>&1

rm -f /tmp/checkcdbexist"${trgcdbname^^}".tmp 2>&1

unset src_cdbexist
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: Checking CDB name " | tee -a "${mainlog}"
src_cdbexist=$(sqlplus -s '/ as sysdba'  << EOF
set heading off
set echo off
set timing off
set time off
set feedback 0
set pagesize 0
set verify OFF
SET TERMOUT OFF
SET LINES 10
spool /tmp/checkcdbexist"${trgcdbname^^}".tmp
select name from v\$database ;
spool off
exit
EOF
)

srccdbexist="${src_cdbexist//[[:blank:]]/}"

if [[ "${srccdbexist}" == "${trgcdbname^^}" ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: Current CDB name is ${trgcdbname} . No need to RENAME CDB. " | tee -a "${mainlog}"
elif [[ "${srccdbexist}" == "${srccdbname^^}" ]]; then
    check_cdbstatus
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: CDB - ${srccdbname} status is ${cdbstatus}. " | tee -a "${mainlog}"
    if [[ "${cdbstatus}" == "MOUNT" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: Renaming ${srccdbname} to  ${trgcdbname}." | tee -a "${mainlog}"
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spooldisableBlkchnagetracking2.${startdate}
ALTER DATABASE DISABLE BLOCK CHANGE TRACKING;
spool off
exit
EOF

      unset rcode
      { echo "Y" ; } | "${ORACLE_HOME}"/bin/nid TARGET=/ DBNAME="${trgcdbname^^}" SETNAME=y > "${log_dir}/cdb_rename${trgcdbname}.${startdate}" 2>&1
      rcode=$?
      if (( rcode > 0 )); then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: ERROR: RENAME CDB did not completed successfully. Exiting !! " | tee -a "${mainlog}"
        mail_exit
      fi

#Reset DB_NAME to target CDB name in SPFILE
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolreset_dbname_spfile1.${startdate}
STARTUP NOMOUNT ;
ALTER SYSTEM SET db_name=${trgcdbname} scope=spfile ;
SHUTDOWN ABORT ;
STARTUP ;
ALTER PLUGGABLE DATABASE ${srdbname^^} OPEN ;
spool off
exit
EOF

        unset rcode
        sleep 2
        check_dbstatus
        if [[ "${pdbstatus}" == "OPEN" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did completed successfully." | tee -a "${mainlog}"
        elif [[ "${pdbstatus}" == "MOUNT" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spool_openPDB.${startdate}
ALTER PLUGGABLE DATABASE ${srdbname^^} OPEN ;
spool off
exit
EOF

        check_dbstatus
           if [[ "${pdbstatus}" == "OPEN" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did completed successfully." | tee -a "${mainlog}"
            else
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did not completed successfully. Please review. Exiting !!" | tee -a "${mainlog}"
             mail_exit
           fi
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did not completed successfully. Please review, check. Exiting !!" | tee -a "${mainlog}"
          mail_exit
        fi

    elif [[ "${cdbstatus}" == "OPEN" ]]; then
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spooldisableBlkchnagetracking2.${startdate}
SHUTDOWN IMMEDIATE ;
STARTUP MOUNT ;
ALTER DATABASE DISABLE BLOCK CHANGE TRACKING;
spool off
exit
EOF
      check_dbstatus
      if [[ "${cdbstatus}" == "MOUNT" ]]; then
        unset rcode
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: Renaming ${srccdbname} to  ${trgcdbname}." | tee -a "${mainlog}"
        { echo "Y" ; } | "${ORACLE_HOME}"/bin/nid TARGET=/ DBNAME="${trgcdbname^^}" SETNAME=y > "${log_dir}/cdb_rename${trgcdbname}.${startdate}" 2>&1
        rcode=$?
        if (( rcode > 0 )); then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: ERROR: RENAME CDB did not completed successfully. Exiting !! " | tee -a "${mainlog}"
          mail_exit
        fi

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolreset_dbname_spfile1.${startdate}
STARTUP NOMOUNT ;
ALTER SYSTEM SET db_name=${trgcdbname} scope=spfile ;
SHUTDOWN ABORT ;
STARTUP ;
ALTER PLUGGABLE DATABASE ${srdbname^^} OPEN ;
spool off
exit
EOF

        unset rcode
        sleep 2
        check_dbstatus
        if [[ "${pdbstatus}" == "OPEN" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did completed successfully." | tee -a "${mainlog}"
        elif [[ "${pdbstatus}" == "MOUNT" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spool_openPDB.${startdate}
ALTER PLUGGABLE DATABASE ${srdbname^^} OPEN ;
spool off
exit
EOF

        check_dbstatus
           if [[ "${pdbstatus}" == "OPEN" ]] && [[ "${cdbstatus}" == "OPEN" ]]; then
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did completed successfully." | tee -a "${mainlog}"
            else
             echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did not completed successfully. Please review. Exiting !!" | tee -a "${mainlog}"
             mail_exit
           fi
        else
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: RENAME CDB did not completed successfully. Please review, check. Exiting !!" | tee -a "${mainlog}"
          mail_exit
        fi
          sleep 2
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME CDB: CDB status is not compatible for RENAME. Exiting !!" | tee -a "${mainlog}"
        mail_exit
      fi
  fi
fi

rm -f /tmp/checkcdbexist"${trgcdbname^^}".tmp 2>&1
}


rename_pdb()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
check_dbstatus

if [[ "${cdbstatus}" == "OPEN" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Container Database ${srdbname} is in ${cdbstatus} state currently." | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Container Database ${srdbname} state is ${cdbstatus}, unable to proceed. Exiting !!" | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Validating PDB ${srdbname}. " | tee -a "${mainlog}"
  trgpdb_exists
  srcpdb_exists

  nohup sh ${common_utils}/monitoralertlog.sh "${trgalertlog}" "${srdbname}" > ${log_dir}/monitoralertlog.${startdate} 2>&1 &
  sleep 2
  #Case no 1:  If source PDB exists
  if [[ "${srcpdbexist}" -gt 0 ]] && [[ "${trgpdbexist}" -eq 0  ]] ; then
    if [[ "${disable_autologin}" == "COMPLETED" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: AUTOLOGIN wallet is already DISABLED. Moving on .. " | tee -a "${mainlog}"
    elif [[ -z "${disable_autologin}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: DISABLING AUTOLOGIN wallet. " | tee -a "${mainlog}"
      mv "${trgdbwalletpath}"/cwallet.sso  "${trgdbwalletpath}"/cwallet.sso.2."${startdate}"  >/dev/null 2>&1

sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb1.${startdate}
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE CONTAINER = ALL ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE;
alter system set wallet close;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF

      check_cdbwallet
      check_wallet_login
      if [[ "${walletstatus}" == "CLOSED" ]] && [[ "${walletlogin}" == "UNKNOWN" ]]; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: AUTOLOGIN wallet is DISABLED successfully. " | tee -a "${mainlog}"
      elif [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb2.${startdate}
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE CONTAINER = ALL ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE;
alter system set wallet close;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF
    check_wallet_login
      fi
      update_clonersp "walletstatus" "${walletstatus}"
      update_clonersp "walletlogin" "${walletlogin}"
      update_clonersp "disable_autologin" "COMPLETED"
    fi

    check_cdbwallet
    check_wallet_login
    if [[ "${open_password_cdbwallet}" == "COMPLETED" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: PASSWORD wallet is already OPEN. Moving on .. " | tee -a "${mainlog}"
    elif [[ -z "${open_password_cdbwallet}" ]] ; then
      if [[ "${walletstatus}" == "OPEN" ]] && [[ "${walletlogin}" == "UNKNOWN" ]] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET status is OPEN, at this point, it should be CLOSED. Please check spoolrenamepdbX logs. EXITING !! " | tee -a "${mainlog}"
        mail_exit
      elif [[ "${walletstatus}" == "CLOSED" ]] && [[ "${walletlogin}" == "UNKNOWN" ]] ; then
sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb3.${startdate}
select * from v\$encryption_wallet;
show PDBS
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE CONTAINER = ALL ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE;
alter system set wallet close;
administer key management set keystore open identified by ${trgdbwalletpwd}  container=ALL ;
administer key management set keystore open identified by ${trgdbwalletpwd} ;
select * from v\$encryption_wallet;
show PDBS
spool off
exit
EOF

      check_cdbwallet
      check_wallet_login
        if [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
          if [[ "${walletlogin}" == "PASSWORD" ]] ; then
           echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET opened with PASSWORD successfully. " | tee -a "${mainlog}"
          else
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET cannot be opened with password. Please check spoolrenamepdbX logs. EXITING !! " | tee -a "${mainlog}"
            mail_exit
          fi
        else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET cannot be opened with password. Please check spoolrenamepdbX logs. EXITING !! " | tee -a "${mainlog}"
        mail_exit
        fi
      fi
      check_cdbwallet
      check_wallet_login
      update_clonersp "walletstatus" "${walletstatus}"
      update_clonersp "walletlogin" "${walletlogin}"
      update_clonersp "open_password_cdbwallet" "COMPLETED"
    fi

    if [[ "${export_cdbwallet}" == "COMPLETED" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: CDB WALLET Export is already completed. Moving on .. " | tee -a "${mainlog}"
    elif [[ -z "${export_cdbwallet}" ]] ; then
      if [[  "${walletstatus}" == "OPEN" ]] || [[  "${walletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${walletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
        if [[ "${walletlogin}" == "PASSWORD" ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: CDB WALLET Export is OPEN, taking WALLET export. " | tee -a "${mainlog}"
          export cdbwalletexportfile="${trgdbwalletpath}/tde_cdb.exp"
          if [[ -f "${cdbwalletexportfile}" ]]; then
            rm -f "${cdbwalletexportfile}" >/dev/null 2>&1
          fi

sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb4.${startdate}
select * from v\$encryption_wallet;
show PDBS ;
administer key management set keystore open identified by ${trgdbwalletpwd}  container=ALL ;
administer key management set keystore open identified by ${trgdbwalletpwd} ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY ${trgdbwalletpwd}  with backup;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS WITH SECRET ${trgdbwalletpwd}  to '${cdbwalletexportfile}' identified by ${trgdbwalletpwd}  ;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF

      check_cdbwallet
      check_wallet_login
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET login MUST be PASSWORD. Cannot proceed. Exiting !! " | tee -a "${mainlog}"
        mail_exit
      fi
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET status MUST be OPEN. Cannot proceed. Exiting !! " | tee -a "${mainlog}"
      mail_exit
    fi

    if [[ -f "${cdbwalletexportfile}" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: CDB WALLET Export is COMPLETED. " | tee -a "${mainlog}"
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: CDB WALLET Export could not be COMPLETED. Exiting !! " | tee -a "${mainlog}"
      check_cdbwallet
      check_wallet_login
      exit  1
    fi
  check_cdbwallet
  check_wallet_login
  fi

  update_clonersp "walletstatus" "${walletstatus}"
  update_clonersp "walletlogin" "${walletlogin}"
  update_clonersp "export_cdbwallet" "COMPLETED"
  update_clonersp "cdbwalletexportfile" "${cdbwalletexportfile}"

    if [[ "${export_pdbwallet}" == "COMPLETED" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: PDB WALLET Export is already completed. Moving on .. " | tee -a "${mainlog}"
    elif [[ -z "${export_pdbwallet}" ]] ; then
      check_pdbwallet "${srdbname}"

       if [[  "${pdbwalletstatus}" == "OPEN" ]] || [[  "${pdbwalletstatus}" == "OPEN_NO_MASTER_KEY" ]] || [[ "${pdbwalletstatus}" == "OPEN_UNKNOWN_MASTER_KEY_STATUS" ]] ; then
        if [[ "${walletlogin}" == "PASSWORD" ]]  ; then
          export pdbwalletexportfile="${trgdbwalletpath}/tde_pdb.exp"
          if [[ -f "${pdbwalletexportfile}" ]]; then
            rm -f "${pdbwalletexportfile}" >/dev/null 2>&1
          fi

sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb5.${startdate}
select * from v\$encryption_wallet;
show PDBS ;
ALTER SESSION SET CONTAINER = ${srdbname} ;
administer key management set keystore open identified by ${trgdbwalletpwd}  ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY ${trgdbwalletpwd}  with backup;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS WITH SECRET ${trgdbwalletpwd}  to '${pdbwalletexportfile}' identified by ${trgdbwalletpwd}  ;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF

      check_cdbwallet
      check_pdbwallet "${srdbname}"
      check_wallet_login
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET login MUST be PASSWORD. Cannot proceed. Exiting !! " | tee -a "${mainlog}"
        mail_exit
      fi
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WALLET status MUST be OPEN. Cannot proceed. Exiting !! " | tee -a "${mainlog}"
      mail_exit
    fi

    if [[ -f "${pdbwalletexportfile}" ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: PDB WALLET Export is COMPLETED. " | tee -a "${mainlog}"
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: PDB WALLET Export could not be COMPLETED. Exiting !! " | tee -a "${mainlog}"
      check_cdbwallet
      check_pdbwallet "${srdbname}"
      check_wallet_login
      exit  1
    fi
  check_cdbwallet
  check_pdbwallet "${srdbname}"
  check_wallet_login
  fi

  update_clonersp "walletstatus" "${walletstatus}"
  update_clonersp "pdbwalletstatus" "${pdbwalletstatus}"
  update_clonersp "walletlogin" "${walletlogin}"
  update_clonersp "export_pdbwallet" "COMPLETED"
  update_clonersp "pdbwalletexportfile" "${pdbwalletexportfile}"

  if [[ "${autologinwallet_postclone}" == "COMPLETED" ]] ; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: AUTOLOGIN WALLET is already created. Moving on .. " | tee -a "${mainlog}"
  elif [[  -z "${autologinwallet_postclone}" ]] ; then
    if [[ "${walletlogin}" != "AUTOLOGIN" ]] ; then

sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
spool ${log_dir}/spoolrenamepdb6.${startdate}
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE '${trgdbwalletpath}' identified by ${trgdbwalletpwd};
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF

      if [[  -f "${trgdbwalletpath}/cwallet.sso" ]] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: AUTOLOGIN wallet is created." | tee -a "${mainlog}"
      else
       echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: WARNING: cwallet.sso file is not created. Autologin wallet is not created." | tee -a "${mainlog}"
      fi

    else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: AUTOLOGIN wallet is already created." | tee -a "${mainlog}"
    fi

  check_cdbwallet
  check_pdbwallet "${srdbname}"
  check_wallet_login
  fi

  update_clonersp "walletstatus" "${walletstatus}"
  update_clonersp "pdbwalletstatus" "${pdbwalletstatus}"
  update_clonersp "walletlogin" "${walletlogin}"
  update_clonersp "autologinwallet_postclone" "COMPLETED"

  check_dbstatus

    if [[ "${pdbstatus}" == "OPEN" ]] ; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} exists and is in ${pdbstatus} state currently." | tee -a "${mainlog}"
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Closing Source Plugable Database ${srdbname} for export. " | tee -a "${mainlog}"
sqlplus / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb_close.${startdate}
alter pluggable database ${srdbname} close;
spool off
exit
EOF

    check_dbstatus
    fi

    if [[ "${pdbstatus}" == "MOUNT" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} exists and is in ${pdbstatus} state currently." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Unplug Source Plugable Database ${srdbname} for export. " | tee -a "${mainlog}"

      export srcpdbunplugfile="${dbtargethomepath}"/dbs/"${srdbname}"_unplug.xml
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb_unplug.${startdate}
alter pluggable database ${srdbname} unplug into '${srcpdbunplugfile}';
spool off
exit
EOF

    update_clonersp "srcpdbunplugfile" "${srcpdbunplugfile}"
    check_dbstatus
    else
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Unable to Unplug Source Plugable Database ${srdbname} for export. Exiting !!" | tee -a "${mainlog}"
      mail_exit
    fi

    # If Plugable database is in MOUNT state and unplug export file is available then just DROP source PDB.
    if [[ -f "${srcpdbunplugfile}" ]]  && [[ "${pdbstatus}" == "MOUNT" ]]  && [[ "${srcpdbexist}" -gt 0 ]]  ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} is in ${pdbstatus} state currently." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} export file is available at ${srcpdbunplugfile}." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname}         :  ${srcpdbunplugfile}." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: DROP Source Plugable Database ${srdbname}. " | tee -a "${mainlog}"
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb_droppdb.${startdate}
drop pluggable database ${srdbname} ;
spool off
exit
EOF

      sleep 2
      srcpdb_exists
        if [[ "${srcpdbexist}" -gt 0 ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} was not dropped. " | tee -a "${mainlog}"
          #fail_exit
          mail_exit
        fi

      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable Database ${srdbname} is dropped. " | tee -a "${mainlog}"
      export srcpdbstatus="DROPPED"
      update_clonersp "srcpdbstatus" "${srcpdbstatus}"

      if [[ -f "${srcpdbunplugfile}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Creating target Plugable Database ${trgdbname}." | tee -a "${mainlog}"
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb_Createpdb.${startdate}
create pluggable database ${trgdbname} using '${srcpdbunplugfile}' NOCOPY SERVICE_NAME_CONVERT=('ebs_${srdbname}','ebs_${trgdbname}');
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF
        sleep 2
        trgpdb_exists
        if [[ "${trgpdbexist}" -eq 0 ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} was not created. Exiting !! " | tee -a "${mainlog}"
          #fail_exit
          mail_exit
        fi
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} is created." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: OPEN Target Plugable Database ${trgdbname}." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF   >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb6.${startdate}
show pdbs
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd}  from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
select * from v\$encryption_wallet;
show PDBS ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ${trgdbwalletpwd} ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd} from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
EOF

sqlplus  / 'as sysdba' << EOF   >/dev/null
spool ${log_dir}/spoolrenamepdb7.${startdate}
ALTER PLUGGABLE DATABASE ${trgdbname} CLOSE ;
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE INSTANCES=ALL;
SHUTDOWN IMMEDIATE ;
STARTUP ;
spool off
exit
EOF

    check_dbstatus
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source PDB EXPORT XML file not found. Cannot proceed. Exiting !!" | tee -a "${mainlog}"
        mail_exit
      fi
    fi

    # Case no 2 : IF Target PDB already exists
    elif [[ "${trgpdbexist}" -gt 0 ]] && [[ "${srcpdbexist}" -eq 0 ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} is available. " | tee -a "${mainlog}"
      if [[ "${pdbstatus}" == *"OPEN"* ]] ; then
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} is in ${pdbstatus} state. " | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF   >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb6.${startdate}
show PDBS ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd}  from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
select * from v\$encryption_wallet;
show PDBS ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ${trgdbwalletpwd} ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd} from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
EOF

sqlplus  / 'as sysdba' << EOF   >/dev/null
spool ${log_dir}/spoolrenamepdb7.${startdate}
set lines 200
col sid format 99999
col username format a4
col osuser format a15
select p.spid,s.sid, s.serial#,s.username, s.COMMAND, s.PROCESS, s.PROGRAM
from gv\$session s, gv\$process p
where s.paddr= p.addr
order by p.spid;
ALTER PLUGGABLE DATABASE ${trgdbname} CLOSE ;
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE INSTANCES=ALL;
SHUTDOWN IMMEDIATE ;
STARTUP ;
spool off
exit
EOF

    check_dbstatus
      elif [[ "${pdbstatus}" == "MOUNT" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} is in ${pdbstatus} state." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: OPEN Target Plugable Database ${trgdbname}." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF   >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb8.${startdate}
show pdbs
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd}  from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
select * from v\$encryption_wallet;
show PDBS ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ${trgdbwalletpwd} ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd} from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
EOF

sqlplus  / 'as sysdba' << EOF   >/dev/null
spool ${log_dir}/spoolrenamepdb9.${startdate}
ALTER PLUGGABLE DATABASE ${trgdbname} CLOSE ;
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE INSTANCES=ALL;
SHUTDOWN IMMEDIATE ;
STARTUP ;
spool off
exit
EOF

    check_dbstatus
      fi

    # Case 3 : IF neither Source PDB exists nor Target PDB exists
    elif [[ "${trgpdbexist}" -eq 0 ]] && [[  "${srcpdbexist}" -eq 0 ]]; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source plugable Database ${srdbname} and Target plugable Database ${trgdbname} both are not available. " | tee -a "${mainlog}"

      if [[ -f "${srcpdbunplugfile}" ]] ; then
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Creating target Plugable Database ${trgdbname}." | tee -a "${mainlog}"
sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb_Createpdb.${startdate}
create pluggable database ${trgdbname} using '${srcpdbunplugfile}' NOCOPY SERVICE_NAME_CONVERT=('ebs_${srdbname}','ebs_${trgdbname}');
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
spool off
exit
EOF
        sleep 2
        trgpdb_exists
        if [[ "${trgpdbexist}" -eq 0 ]] ; then
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} was not created. Exiting !! " | tee -a "${mainlog}"
          #fail_exit
          mail_exit
        fi
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Target Plugable Database ${trgdbname} is created." | tee -a "${mainlog}"
      echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: OPEN Target Plugable Database ${trgdbname}." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF   >/dev/null
set echo on ;
spool ${log_dir}/spoolrenamepdb6.${startdate}
show pdbs
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE ;
col WRL_PARAMETER for a50  ;
set lines 200 ;
select * from v\$encryption_wallet;
show PDBS ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd}  from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
select * from v\$encryption_wallet;
show PDBS ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ${trgdbwalletpwd} ;
ADMINISTER KEY MANAGEMENT IMPORT KEYS WITH SECRET ${trgdbwalletpwd} from '${pdbwalletexportfile}' identified by ${trgdbwalletpwd} with backup using '${trgdbwalletpwd}' ;
EOF

sqlplus  / 'as sysdba' << EOF   >/dev/null
spool ${log_dir}/spoolrenamepdb7.${startdate}
ALTER PLUGGABLE DATABASE ${trgdbname} CLOSE ;
ALTER PLUGGABLE DATABASE ${trgdbname} OPEN READ WRITE;
ALTER PLUGGABLE DATABASE ALL SAVE STATE INSTANCES=ALL;
SHUTDOWN IMMEDIATE ;
STARTUP ;
spool off
exit
EOF

    check_dbstatus
      else
        echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source PDB EXPORT XML file not found. Cannot proceed. Exiting !!" | tee -a "${mainlog}"
        mail_exit
      fi
    fi

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RENAME PDB: Source Plugable database ${srdbname} is renamed to Target Plugable Database ${trgdbname}." | tee -a "${mainlog}"
export trgpdbstatus="CREATED"
update_clonersp "trgpdbstatus" "${trgpdbstatus}"

}

addtempfiles_cdb()
{
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Adding tempfile to Container Database" | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spooladdtempfile.${startdate}
alter tablespace temp add tempfile '${trgasmdg}' size 30g ;
spool off
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Tempfile could not be added to CDB exiting !!" | tee -a "${mainlog}"
  mail_exit
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Tempfile added to CDB." | tee -a "${mainlog}"
fi
unset rt_stat
}

addtempfiles_pdb()
{
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Adding tempfile to Plugable Database" | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spooladdtempfile.${startdate}
alter session set container={trgdbname^^} ;
@${inst_sql}/pdb_add_tempfiles.sql
spool off
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Tempfile could not be added to PDB exiting !!" | tee -a "${mainlog}"
  mail_exit
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Tempfile added to PDB." | tee -a "${mainlog}"
fi
unset rt_stat
}

config_cdb()
{

source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
check_cdbstatus
if [[ "${cdbstatus}" == "OPEN" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Container Database is OPEN, proceeding with CDB configuration." | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Container Database is NOT OPEN, cannot proceed with CDB configuration. Exiting !! " | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi

#addtempfiles_cdb
cd "${inst_sql}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Create CDB services." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolCDBService.${startdate}
@${inst_sql}/cdb_create_service.sql
spool off
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: CDB Service creation completed with errors. log: ${log_dir}/spoolCDBService.${startdate} " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: CDB Service creation completed. log: ${log_dir}/spool_CDBService.${startdate}." | tee -a "${mainlog}"
fi
unset rt_stat

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Create CDB directories." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolCDBdir.${startdate}
@${inst_sql}/cdb_create_db_directories.sql
spool off
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: CDB directories creation completed with errors. log: ${log_dir}/spoolCDBdir.${startdate} " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: CDB directories creation completed. log: ${log_dir}/spoolCDBdir.${startdate}." | tee -a "${mainlog}"
fi
unset rt_stat

export SYSTEMUSER=$(/dba/bin/getpass "${dbupper^^}" system)
export SYSTEMPASS=$(echo "${SYSTEMUSER}" | cut -d/ -f 2)
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Reset SYS and SYSTEM passwords." | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: purge dba_recyclebin." | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Change archivelog mode to NOARCHIVE." | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Restart database." | tee -a "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: " | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolCDBchangepass.${startdate}
ALTER USER SYS IDENTIFIED BY ${SYSTEMPASS} ;
ALTER USER SYSTEM IDENTIFIED BY ${SYSTEMPASS} ;
alter user dbsnmp identified by dbsnmp;
purge dba_recyclebin;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT ;
ALTER DATABASE NOARCHIVELOG ;
SHUTDOWN IMMEDIATE;
STARTUP ;
spool off
exit
EOF

"${ORACLE_HOME}"/bin/lsnrctl reload "${trgcdbname^^}"  > "${log_dir}"/bounce_listener1."${startdate}" 2>&1
"${ORACLE_HOME}"/bin/lsnrctl reload "${trgcdbname^^}"  >> "${log_dir}"/bounce_listener1."${startdate}"  2>&1
check_cdbstatus
if [[ "${cdbstatus}" == "OPEN" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Container Database is OPEN. CDB Configuration completed" | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Container Database is NOT OPEN. CDB Configuration is not completed. Exiting !!" | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG CDB: Running adupdlib.sql in CDB." | tee -a "${mainlog}"
cd "${ORACLE_HOME}/appsutil/install/${trgdbhostcontextname}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolCDBadupdlib.${startdate}
@adupdlib.sql 'so'
exit ;
spool off
exit
EOF

}


config_pdb()
{

source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1

check_dbstatus
if [[ "${cdbstatus}" == "OPEN" ]] && [[ "${pdbstatus}" == "OPEN" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Container Database and Plugable database is OPEN. Proceeding with PDB Configuration. " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: One or both of Container Database and Plugable database are not open. Cannot proceed with PDB Configuration. Exiting !! " | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi

#addtempfiles_pdb
cd "${inst_sql}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Create PDB services." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolPDBService.${startdate}
ALTER SESSION set container=${trgdbname^^} ;
@${inst_sql}/pdb_create_service.sql
spool off
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: PDB Service creation completed with errors. log: ${log_dir}/spoolPDBService.${startdate} " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: PDB Service creation completed. log: ${log_dir}/spoolPDBService.${startdate}." | tee -a "${mainlog}"
fi
unset rt_stat

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Create PDB directories." | tee -a "${mainlog}"
export SYSTEMUSER=$(/dba/bin/getpass "${dbupper^^}" system)
export SYSTEMPASS=$(echo "${SYSTEMUSER}" | cut -d/ -f 2)

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spoolPDBdir.${startdate}
ALTER SESSION set container=${trgdbname^^} ;
@${inst_sql}/pdb_create_db_directories.sql
ALTER USER EBS_SYSTEM IDENTIFIED BY ${SYSTEMPASS} ;
purge dba_recyclebin;
alter profile SERVICE_EXPD limit PASSWORD_REUSE_MAX UNLIMITED;
@${inst_sql}/pdb_enable_masterlist.sql
spool off ;
exit
EOF

rt_stat=$?
if [[ "${rt_stat}" -gt 0 ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: PDB directories creation completed with errors. log: ${log_dir}/spoolPDBdir.${startdate} " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: PDB directories creation completed. log: ${log_dir}/spoolPDBdir.${startdate}." | tee -a "${mainlog}"
fi
unset rt_stat


export SYSTEMUSER=$(/dba/bin/getpass "${dbupper^^}" system)
export SYSTEMPASS=$(echo "${SYSTEMUSER}" | cut -d/ -f 2)
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Purge dba_recyclebin, and restart database." | tee -a "${mainlog}"

sqlplus  / 'as sysdba' << EOF  >/dev/null
set echo on ;
spool ${log_dir}/bouncedb${HOST_NAME^^}.${startdate}
SHUTDOWN IMMEDIATE;
STARTUP
spool off
exit
EOF

"${ORACLE_HOME}"/bin/lsnrctl reload "${trgcdbname^^}"  > "${log_dir}"/bounce_listener2"${trgcdbname}"."${startdate}" 2>&1
"${ORACLE_HOME}"/bin/lsnrctl status "${trgcdbname^^}"  >> "${log_dir}"/bounce_listener2"${trgcdbname}"."${startdate}"  2>&1

check_dbstatus
if [[ "${cdbstatus}" == "OPEN" ]] && [[ "${pdbstatus}" == "OPEN" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: Container Database and Plugable database is OPEN. PDB Configuration completed !!. " | tee -a "${mainlog}"
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:CONFIG PDB: One or both of Container Database and Plugable database are not open. PDB Configuration not completed. Exiting !! " | tee -a "${mainlog}"
  #fail_exit
  mail_exit
fi

}

fnd_clean()
{
validate_apps_password
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:FND CLEANUP: Running FND_CONC.SETUP_CLEAN log: ${log_dir}/spool_fndclean${trgdbname^^}.${startdate} " | tee -a "${mainlog}"

sqlplus  apps/"${workappspass}"@"${trgdbname}" << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spool_fndclean${trgdbname^^}.${startdate}
truncate table APPLSYS.ADOP_VALID_NODES;
exec FND_CONC_CLONE.SETUP_CLEAN;
spool off
exit
EOF

}

apps_sql()
{
validate_apps_password
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:APPS SQL: Running APPS SQL log: ${log_dir}/spool_appssql.dbnode.${startdate} " | tee -a "${mainlog}"

sqlplus  apps/"${workappspass}"@"${trgdbname}" << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spool_appssql.dbnode.${trgdbname^^}.${startdate}
@${inst_sql}/pdb_apps_sql.sql
spool off
exit
EOF

}

setup_utl ()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
chmod 775 "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
source "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
export SYSTEMPASS=$(/dba/bin/getpass "${trgdbname^^}" system | cut -d/ -f 2 )

source /dba/etc/.egebs
export workappspass="${srcappspass}"

export SYSTEMPASS=$(/dba/bin/getpass "${trgdbname^^}" system | cut -d/ -f 2)



if [[ -z "${workappspass}" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Source Environment apps password is not loaded.\n"
  mail_exit
elif [[ -z "${SYSTEMPASS}" ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Target Environment SYSTEM password is not loaded.\n"
fi

if [[ -f "${dbtargethomepath}/appsutil/bin/txkCfgUtlfileDir.pl" ]] && [[ -f "${dbtargethomepath}/dbs/${trgdbname^^}_utlfiledir.txt" ]]; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: Running UTL Setup : SET utl stage. " | tee -a "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: Running UTL Setup :       log: ${log_dir}/utlsetupSET.${startdate} " | tee -a "${mainlog}"
  { echo "${workappspass}" ; echo "${SYSTEMPASS}" ;  } | perl "${dbtargethomepath}"/appsutil/bin/txkCfgUtlfileDir.pl  -contextfile="${CONTEXT_FILE}" -oraclehome="${dbtargethomepath}" -outdir=/tmp/txkCfgUtlfileDir -mode=setUtlFileDir -servicetype=onpremise > "${log_dir}"/utlsetupSET."${startdate}" 2>&1
  rt_stat=$?
  if [[ "${rt_stat}" -gt 0 ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: UTL Setup could not be completed at SET utl stage. Exiting !! " | tee -a "${mainlog}"
  fi
  unset rt_stat

  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: Running UTL Setup : SYNC utl stage. " | tee -a "${mainlog}"
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: Running UTL Setup :       log: ${log_dir}/utlsetupSYNC.${startdate} " | tee -a "${mainlog}"
  { echo "${workappspass}" ;  } | perl "${dbtargethomepath}"/appsutil/bin/txkCfgUtlfileDir.pl  -contextfile="${CONTEXT_FILE}" -oraclehome="${dbtargethomepath}" -outdir=/tmp/txkCfgUtlfileDir -mode=syncUtlFileDir -servicetype=onpremise   > "${log_dir}"/utlsetupSYNC."${startdate}" 2>&1
  rt_stat=$?
  if [[ "${rt_stat}" -gt 0 ]]; then
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: UTL Setup could not be completed at SYNC utl stage. Exiting !! log: ${log_dir}/utlsetupSYNC${startdate} " | tee -a "${mainlog}"
  else
    echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: UTL Setup is completed. log: ${log_dir}/utlsetupSYNC.${startdate} " | tee -a "${mainlog}"
  fi
  unset rt_stat
else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:SETUP UTL: Required files are missing, cannot setup utl dir. log: ${log_dir}/utlsetupSYNC.${startdate}." | tee -a "${mainlog}"
fi
}


db_autoconfig()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
chmod 775 "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
source "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
if [[ -f "${dbtargethomepath}/appsutil/scripts/${trgdbname^^}_${trgdbhost}/adautocfg.sh" ]] ; then
  validate_apps_password
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB AUTOCONFIG: Running Database adautocfg.sh log: ${log_dir}/dbautoconfig1${trgdbhost}.${startdate} " | tee -a "${mainlog}"
  sh "${dbtargethomepath}"/appsutil/scripts/"${trgdbname^^}"_"${trgdbhost}"/adautocfg.sh  appspass="${workappspass}"  >> "${log_dir}"/dbautoconfig1"${trgdbhost}"."${startdate}" 2>&1
  rcode=$?
  if (( rcode > 0 )); then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB AUTOCONFIG: WARNING: Database adautocfg.sh is completed with error. " | tee -a "${mainlog}"
  else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB AUTOCONFIG: Database adautocfg.sh is completed. " | tee -a "${mainlog}"
  unset rcode
  sleep 2
  fi

else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB AUTOCONFIG: adautocfg.sh file could not be located. Cannot proceed. Exiting !!  log: ${log_dir}/dbautoconfig1${trgdbhost}.${startdate} " | tee -a "${mainlog}"
fi
}

run_db_etcc()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
chmod 775 "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
source "${dbtargethomepath}"/"${trgdbname^^}"_"${trgdbhost}".env >/dev/null 2>&1
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB ETCC: ORACLE_SID is set to PDB -- ${ORACLE_SID}.  " | tee -a "${mainlog}"
cd "${common_home}/etcc/"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB ETCC: Running ETCC on Database node.  log: ${log_dir}/dbetcc${trgdbhost}.${startdate} " | tee -a "${mainlog}"
sh "${common_home}"/etcc/checkDBpatch.sh  > "${log_dir}"/dbnode_etcc_"${trgdbname^^}"."${startdate}"  2>&1
sleep 5
cd "${log_dir}"
}

compile_invalid()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:COMPILE INVALIDS: Compiling invalid objects.  log: ${log_dir}/spool_compileInvalids.${startdate} " | tee -a "${mainlog}"
sqlplus  '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
spool ${log_dir}/spool_compileInvalids.${startdate}
@${dbtargethomepath}/rdbms/admin/utlrp.sql
@${dbtargethomepath}/rdbms/admin/utlrp.sql
@${dbtargethomepath}/rdbms/admin/utlrp.sql
spool off
exit
EOF
}

run_scramble()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1
validate_apps_password
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RUN SCRAMBLE: Running Scrambling SQL log: ${log_dir}/spool_scramble.${startdate} " | tee -a "${mainlog}"

sqlplus  apps/"${workappspass}"@"${trgdbname}" << EOF  >/dev/null
set echo on ;
spool ${log_dir}/spool_scramble.${startdate}
@${inst_sql}/pdb_scramble_main.sql
spool off
exit
EOF

  rcode=$?
  if (( rcode > 0 )); then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RUN SCRAMBLE: WARNING: Database Scrambling sql is completed with error. " | tee -a "${mainlog}"
  update_clonersp "db_scramble_sql" "FAILED"
  else
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:RUN SCRAMBLE: Database Scrambling sql is completed. " | tee -a "${mainlog}"
  unset rcode
  sleep 2
  update_clonersp "db_scramble_sql" "COMPLETED"
  fi
}

run_ggsql()
{
source /home/"$(whoami)"/."${trgcdbname,,}"_profile  >/dev/null 2>&1

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GG SQL: Running GoldenGate SQL log: ${log_dir}/spool_ggsql.${startdate} " | tee -a "${mainlog}"
sqlplus  '/ as sysdba'  << EOF > /dev/null
SET ECHO ON ;
SET TIME ON ;
ALTER SESSION SET CONTAINER=${trgdbname} ;
spool ${log_dir}/spool_ggsql.${startdate}
@${inst_sql}/pdb_gg_sysupdate.sql
spool off
exit
EOF

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:GG SQL: GoldenGate SQL is completed. " | tee -a "${log_dir}/spool_ggsql.${startdate}"
update_clonersp "db_gg_sql" "COMPLETED"
}

#******************************************************************************************************##
##	Execute Database clone steps
#******************************************************************************************************##

#export workappspass="${1}"

source "${clonerspfile}" >/dev/null 2>&1

echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB CONTROL CHECK: Checking for Database script execution go ahead."
db_spin

if [[ "${current_task_id}" -lt  "1000"  ]] || [[ ${current_task_id} -ge "1800"  ]] ; then
  echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:DB TASK ID CHECK: TASK ID is out of range for Database script execution."
  mail_exit
fi

if [[ -z "${current_dbtask}" ]] ; then
  export current_dbtask="Database script initialization"
  update_clonersp "current_dbtask" "${current_dbtask}"
fi

for task in $(seq "${current_task_id}" 1 1800 )
do
  case $task in
    "1000")
          update_clonersp "current_task_id" 1050
          update_clonersp "current_module_task" "${current_task_id}"
          export current_dbtask="PREPARE Database phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\"" ;;
    "1050")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:PREPARE DB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          check_dbstatus
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1070 ;;
    "1070")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          extract_db
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1100  ;;
#          update_clonersp "current_task_id" 1090  ;;
#    "1090")
#          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
#          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
#          genrman
#          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
#          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
#          update_clonersp "current_task_id" 1100  ;;
    "1100")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:PREPARE DB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1200
          update_clonersp "current_module_task" "${current_task_id}" ;;
    "1200")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:RESTORE DB "
          update_clonersp "current_task_id" 1220
          export current_dbtask="RESTORE Database phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\"" ;;
    "1220")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          db_ready
          #exit 0
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1250  ;;
    "1250")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          execrman
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1400  ;;
    "1400")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:RESTORE DB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1410
          update_clonersp "current_module_task" "${current_task_id}"  ;;
    "1410")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:RENAME CDB "
          update_clonersp "current_task_id" 1411
          export current_dbtask="RENAME Container Database phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\"" ;;
    "1411")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          rename_cdb
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1415  ;;
    "1415")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:RENAME CDB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1500
          update_clonersp "current_module_task" "${current_task_id}"  ;;
    "1500")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:RENAME PDB "
          update_clonersp "current_task_id" 1550
          export current_dbtask="RENAME Pluggable Database phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\"" ;;

    "1550")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          rename_pdb
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1600  ;;
    "1600")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:RENAME PDB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1700
          update_clonersp "current_module_task" "${current_task_id}"  ;;
    "1700")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:CONFIG DB "
          update_clonersp "current_task_id" 1710
          export current_dbtask="Configure POST Database RESTORE phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\"" ;;
    "1710")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          config_cdb
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1715 ;;
    "1715")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          config_pdb
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:CONFIG DB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1720
          update_clonersp "current_module_task" "${current_task_id}" ;;
    "1720")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:UTL SETUP"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          export current_dbtask="Configure POST Database RESTORE - UTL SETUP phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\""

          source /dba/etc/.egebs
          export workappspass="${srcappspass}"

          if [[ -z "${workappspass}" ]] ; then
            echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: ERROR: Source Environment apps password is not loaded.\n"
            mail_exit
          fi
          fnd_clean
          db_autoconfig
          db_autoconfig
          setup_utl
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:UTL SETUP"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1730
          update_clonersp "current_module_task" "${current_task_id}" ;;
    "1730")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:START MODULE:DB AUTOCONFIG"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          export current_dbtask="POST Database RESTORE - FND Clean/autoconfig phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\""

          db_autoconfig
          apps_sql
          db_autoconfig
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:DB AUTOCONFIG"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1740
          update_clonersp "current_module_task" "${current_task_id}"  ;;
    "1740")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:START TASK "
          export current_dbtask="POST Database RESTORE - ETCC/ Invalid object compile phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\""

          run_db_etcc
          compile_invalid
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:END TASK "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          update_clonersp "current_task_id" 1800
          update_clonersp "current_module_task" "${current_task_id}" ;;
    "1800")
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_module_task}:END MODULE:CONFIG PDB "
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}:${current_task_id}:"
          export current_dbtask="POST Database RESTORE - Scrambling/GG Sql phase"
          update_clonersp "current_dbtask" "\"${current_dbtask}\""
          update_clonersp "current_task_id" 3000
          update_clonersp "current_module_task" "${current_task_id}"
          update_clonersp "control_owner" "app"
          run_scramble
          run_ggsql
          db_spin
          compile_invalid
          update_clonersp "control_owner" "app"
          export current_dbtask="POST Database RESTORE - Database part completed."
          update_clonersp "current_dbtask" "\"${current_dbtask}\""
          ;;
    *)
    :
    #echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: You are in blackhole. Kindly revisit the code to fix this"
    #echo "Task not found - step: $task not present in stage ${session_stage}"  | tee -a "${logf}"
    ;;
  esac
done


echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : >>>>>>> Database tier clone steps are completed. <<<<<<< " | tee -a  "${mainlog}"
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "
echo -e "$(date +"%d-%m-%Y %H:%M:%S"):${HOST_NAME}: DB RESTORE : "

#Removing lock file
#rm -f "${lock_dir}"/"${dblower}"db.lck 2>&1
rm -f "/tmp/${dblower}db.lck"
exit
#******************************************************************************************************##
#  **********   E N D - O F - D A T A B A S E - R E S T O R E - S C R I P T   **********
#******************************************************************************************************##
