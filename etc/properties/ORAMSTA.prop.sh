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
      source_database="ORAPRD"
      source_flag=${source_database}
fi

if [[ "${source_flag}" == "ORAPRD" ]] ; then
export srdbname="ORAPRD"
export srcdbid=639711047
export srccdbname="ORACPRD"
export srcappname="ORAPRD"
export proddomain="sea.corp.expecn.com"
export srcasmdg="+DATA"
export srcasmpath="+DATA/ORACPRDPH"
export srcdbhost="phcdoraebsdb201"
export srcdbhost2="phcdoraebsdb202"
export srcapphost="phcdoraebsap001"
export srcadminapphost="phcdoraebsap001"
export srcapphost2="phcdoraebsap002"
export srcapphost3="phcdoraebsap003"
export srcapphost4="phcdoraebsap004"
export srcdbosuser="oracle"
export srcappsosuser="applmgr"
export srcdbhomepath="/u01/app/oracle/${srdbname^^}/db/tech_st/19.3/"
export srcappbasepath="/appltop/app/oracle/${srcappname^^}"
export appbackupmgrbase="/u05/oracle/backupmgr"
export dbbackupmgrbase="/u01/app/oracle/backupmgr"
export appsourcebkupdir="/backuprman/ebs_backups/${srcappname^^}/app_tar"
export dbsourcebkupdir="/backuprman/ebs_backups/${srdbname^^}/db_home"
export dbstgbkp="/u05/oracle/backupmgr/stagebackup/db"
export appstgbkp="/u05/oracle/backupmgr/stagebackup/apps"
export srcnbkpclient="phcdoraebsdb101.backup.expecn.com"
export srcnbkpserver="chcxbkpnba001"
#echo -e "$(date +"%d-%m-%Y %H:%M:%S")":"${HOST_NAME}": "         Source instance is  ${srcdbname}. "
fi

#**********************************************************************************************
# Add the TARGET environment variables as needed
#**********************************************************************************************
export trgname="ORAMSTA"
export trgdbname="ORAMSTA"
export trgcdbname="ORACMSTA"
export labdomain="karmalab.net"
export trgappname="${trgname}"
export trginstname="${trgcdbname}"
export trgdbracenable="N"
export trgdbhost="chcloraebsdb502"
#export trgdbhost2="chcloraebsdb502"
export trgapphost="chelorappg001"
export trgadminapphost="chelorappg001"
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
export dbtargethomepath="/u01/app/oracle/${trgdbname^^}/db/tech_st/19.3"
export apptargetbasepath="/appltop/app/oracle/${trgappname^^}"
export appbackupmgrbase="/u05/oracle/autoclone"
export dbbackupmgrbase="/u05/oracle/autoclone"
#export trgdbrestart_dir="${dbbackupmgrbase}/log/${trgdbname^^}/restore/restart"
#export trgapprestart_dir="${appbackupmgrbase}/log/${trgappname^^}/restore/restart"
#export appsclienthome="/u01/oracle/client/install"
export trgdbspfile="${trgasmpath}"/PARAMETERFILE/spfile"${trgcdbname}".ora
export appsrunfsportpool=70
export appspatchfsportpool=71
export appswebport=8070
export trgapplcsf="/u04/oracle/R12/${trgappname^^}/conc"
export trgapplptmp="/u04/oracle/R12/${trgappname^^}/applptmp"
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
export trgapps_patch_alias='ORAMSTA_patch'

# Directories used for clone
export scr_home=/u05/oracle/autoclone
export instance_dir="${scr_home}"/instance/"${trgname^^}"
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
