#!/bin/bash
#***************************************************************************************************#
#       Purpose    :  Declare instance specific values to variables
#   Script name:  instance.properties
#   Usage      :  . instance.prop
#                 . ORASUP.prop
#
#  $Header 1.2 2022/03/17 dikumar $
#  $Header 1.3 2023/01/02 dikumar  Added 19c updates$
#  $Header 1.4 2023/03/17 dikumar Added merged properties for single script execution
#***************************************************************************************************#
HOST_NAME=$(uname -n | cut -f1 -d".")
uhome="/home/$(whoami)"
### EMAIL
TOADDR="dikumar@expediagroup.com"
CCADDR="dikumar@expediagroup.com"
RTNADDR="noreply@clonemanager.com"
DEAD=/dev/null
#
# Do not modify below variable
#
unset trgname

#**********************************************************************************************
# Add the SOURCE environments as needed
#**********************************************************************************************

if [[ -z "${source_flag}" ]] ; then
      source_database="GAHPRD"
      source_flag=${source_database}
fi

if [[ "${source_flag}" == "GAHPRD" ]] ; then
export srdbname="GAHPRD"
export srcdbid=944458476
export srccdbname="GAHCPRD"
export srcappname="GAHPRD"
export proddomain="sea.corp.expecn.com"
export srcasmdg="+DATHCX8"
export srcasmpath="+DATHCX8/GAHPRDCH"
export srcdbhost="chcxoraebsdb201"
export srcdbhost2="chcxoraebsdb202"
export srcapphost="chcxoraebsap201"
export srcadminapphost="chcxoraebsdb201"
export srcapphost2="chcxoraebsap202"
export srcapphost3="chcxoraebsap203"
export srcapphost4="chcxoraebsap204"
export srcdbosuser="oracle"
export srcappsosuser="applmgr"
export srcdbhomepath="/u01/app/oracle/${trgname}/db/tech_st/19.3/"
export srcappbasepath="/u01/oracle/GAHPRD"
export appbackupmgrbase="/u05/oracle/backupmgr"
export dbbackupmgrbase="/u01/app/oracle/backupmgr"
export appsourcebkupdir="/backuprman/ebs_backups/GAHPRD/app_tar"
export dbsourcebkupdir="/backuprman/ebs_backups/GAHPRD/db_home"
export dbstgbkp="/u05/oracle/backupmgr/stagebackup/db"
export appstgbkp="/u05/oracle/backupmgr/stagebackup/apps"
export srcnbkpclient="chcxoraebsdb201.backup.expecn.com"
export srcnbkpserver="chcxbkpnba001"
#echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "         Source instance is  ${srcdbname}. "
fi

#**********************************************************************************************
# Add the TARGET environment variables as needed
#**********************************************************************************************
export trgname=CLONEDB
export trgdbname=CLONEDB
export trgcdbname=CLONECDB
export labdomain="karmalab.net"
export trgappname=${trgname}
export trginstname=${trgcdbname}
export trgdbracenable="N"
export trgdbhost="chcloraebsdb501"
#export trgdbhost2="chcloraebsdb502"
export trgapphost="cheloraebsap402"
export trgadminapphost="cheloraebsap402"
export trgappssoenable="N"
export trgdbosuser="oracle"
export trgappsosuser="applmgr"
export trgdbhostcontextname="${trgdbname}_${trgdbhost}"
export trgapphostcontextname="${trgdbname}_${trgapphost}"
export trgasmdg="+DATHCX7"
export trgasmpath="${trgasmdg}"/"${trgcdbname^^}"
export dbnodecount=1
export appnodecount=1
export dbrac="N"
export dbtargethomepath="/u01/app/oracle/${trgname}/db/tech_st/19.3"
export apptargetbasepath="/u01/oracle/CLONEDB"
#export trgdbwalletpath="/u01/app/oracle/admin/CLONEDB/wallet/tde"
#export trgdbwalletpwd="Oraedt2014"
export dbsourcebkupdir="/toolbase/app/stagebucket"
export appbackupmgrbase="/u05/oracle/autoclone"
export dbbackupmgrbase="/u05/oracle/autoclone"
export trgdbrestart_dir="${dbbackupmgrbase}/log/${trgdbname^^}/restore/restart"
export trgapprestart_dir="${appbackupmgrbase}/log/${trgappname^^}/restore/restart"
#export appsclienthome="/u01/oracle/client/install"
export trgdbspfile="${trgasmpath}"/PARAMETERFILE/spfile"${trgcdbname}".ora
export appsrunfsportpool=79
export appspatchfsportpool=80
export appswebport=8079
export trgapplcsf="/u01/oracle/CLONEDB/fs_ne/inst/CLONEDB_cheloraebsap402/logs/appl/conc"
export trgapplptmp="/u04/oracle/R12/CLONEDB/applptmp"
#export trgurl_protocol="https"
export trglocal_url_protocol="${trgurl_protocol}"
export trgwebentryurlprotocol="${trgurl_protocol}"
 #export trgactive_webport="443"
 #export trgwebssl_port="4492"
 #export trgwebentryhost="oramaui"
 #export trghttps_listen_parameter="4492"
 #export trglogin_page="https://CLONEDB.karmalab.net:443/OA_HTML/AppsLogin"
 #export trgexternal_url="https://CLONEDB.karmalab.net:443"
 #export trgendUserMonitoringURL="https://cheloraebsap601.karmalab.net:443/oracle_smp_chronos/oracle_smp_chronos_sdk.gif"
export trgshared_file_system="true"
 #export trgapps_jdbc_connect_descriptor='jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(LOAD_BALANCE=YES)(FAILOVER=YES)(ADDRESS=(PROTOCOL=tcp)(HOST=chcloraebsdb501-vip.karmalab.net)(PORT=1570))(ADDRESS=(PROTOCOL=tcp)(HOST=chcloraebsdb502-vip.karmalab.net)(PORT=1570)))(CONNECT_DATA=(SERVICE_NAME=CLONEDB)))'
 #export trgapps_jdbc_patch_connect_descriptor='jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS_LIST=(LOAD_BALANCE=YES)(FAILOVER=YES)(ADDRESS=(PROTOCOL=tcp)(HOST=chcloraebsdb501-vip.karmalab.net)(PORT=1570))(ADDRESS=(PROTOCOL=tcp)(HOST=chcloraebsdb502-vip.karmalab.net)(PORT=1570)))(CONNECT_DATA=(SERVICE_NAME=CLONEDB_ebs_patch)))'
export trgapps_patch_alias='CLONEDB_patch'

# Directories used for clone
export scr_home=/u05/oracle/autoclone
export instance_dir="${scr_home}"/instance/"${dbupper}"
export inst_etc="${instance_dir}"/etc
export inst_bin="${instance_dir}"/bin
export inst_sql="${instance_dir}"/sql

export common_home="${scr_home}"/common
export common_utils="${common_home}"/utils
export common_lib="${common_home}"/lib
export common_sql="${common_home}"/sql
export extractdir="${instance_dir}"/"${HOST_NAME}"/extract
#echo -e "extractdir is ${extractdir}"
export currentextractdir="${extractdir}"/current
export bkpextractdir="${extractdir}"/backup
export uploaddir="${instance_dir}"/"${HOST_NAME}"/upload
export uploadsqldir="${uploaddir}"/sql
export bkpinitdir="${instance_dir}"/"${HOST_NAME}"/init
export extractlogdir="${instance_dir}"/log/extract



if [[ ! -d  "${instance_dir}" ]] ; then  mkdir -p "${instance_dir}" >/dev/null 2>&1
fi

if [[ ! -d  "${inst_etc}" ]] ; then  mkdir -p "${inst_etc}" >/dev/null 2>&1
fi

if [[ ! -d  "${inst_bin}" ]] ; then  mkdir -p "${inst_bin}" >/dev/null 2>&1
fi

if [[ ! -d  "${inst_sql}" ]] ; then  mkdir -p "${inst_sql}" >/dev/null  2>&1
fi

if [[ ! -d  "${extractdir}" ]] ; then  mkdir -p "${extractdir}" >/dev/null 2>&1
fi

if [[ ! -d  "${currentextractdir}" ]] ; then  mkdir -p "${currentextractdir}" >/dev/null 2>&1
fi

if [[ ! -d  "${bkpextractdir}" ]] ; then  mkdir -p "${bkpextractdir}" >/dev/null 2>&1
fi

if [[ ! -d  "${uploaddir}" ]] ; then  mkdir -p "${uploaddir}" >/dev/null  2>&1
fi

if [[ ! -d  "${uploadsqldir}" ]] ; then  mkdir -p "${uploadsqldir}" >/dev/null 2>&1
fi

if [[ ! -d  "${bkpinitdir}" ]] ; then  mkdir -p "${bkpinitdir}" >/dev/null 2>&1
fi

if [[ ! -d  "${extractlogdir}" ]] ; then  mkdir -p "${extractlogdir}" >/dev/null 2>&1
fi


chmod -R 777 "${instance_dir}" > /dev/null 2>&1

export clonerspfile="${inst_etc}"/clone.rsp
export propertyfile="${inst_etc}"/"${trgdbname^^}".prop


#***************************************************************************************************###
#
#  **********   E N D - O F - I N S T A N C E - P R O P E R T I E S - S C R I P T   **********
#
#***************************************************************************************************###
