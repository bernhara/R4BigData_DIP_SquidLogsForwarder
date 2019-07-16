#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

if [ -r "${HERE}/${CMD}-config" ]
then
    . "${HERE}/${CMD}-config"
fi

getMyDnsName () {

    my_dns_name=""

    my_ip_address=`curl --max-time 10 --silent ipinfo.io/ip`
    if [ -n "${my_ip_address}" ]
    then
	resolv_request_result=`host "${my_ip_address}"`
	my_dns_name=`
           set -- ${resolv_request_result}
           echo "$5"
        `
    fi

    if [ -n "${my_dns_name}" ]
    then
	echo "${my_dns_name}"
	return 1
    else
	echo "${my_ip_address}"
	return 0
    
    fi
}

getMyMacAddress () {

    default_result="_UNDEFINED_MAC_ADDRESS_"

    my_mac_address=""

    mac_address_system_file="/sys/class/net/${interface_for_indentification}/address"
    if [ -r "${mac_address_system_file}" ]
    then
	my_mac_address=`cat "${mac_address_system_file}"`
    fi

    if [ -n "${my_mac_address}" ]
    then
	echo "${my_mac_address}"
	return 1
    else
	echo "${default_result}"
	return 0
    fi
}

getSquidLogFolder () {

    known_log_dir="/var/log/squid3 /var/log/squid"
    for log_dir in ${known_log_dir}
    do
	if [ -d "${log_dir}" ]
	then
	    echo "${log_dir}"
	    return 0
	fi
    done

    # if reache no log dir found

    echo "ERROR: could not find any log dir out of ${known_log_dir}" 1>&2
    exit 1
}


date

: ${interface_for_indentification:="eth0"}

if [ -z "${my_name}" ]
then
    # no name has been forced => use eth if MAC address
    my_name=$( getMyMacAddress )
fi

: ${connect_to_collector_using_wan_address:=false}

if ${connect_to_collector_using_wan_address}
then
    ssh_remote_host_spec="log-collector-wan"
else
    ssh_remote_host_spec="log-collector-lan"
fi
    


tmp_ssh_key_file=$( mktemp )
cp "${HERE}/ssh-key-to-s-proxetnet" "${tmp_ssh_key_file}"
chmod u+r,u-wx,go-rwx "${tmp_ssh_key_file}"

: ${ssh_verbose_flag:=""}
: ${ssh_command:=ssh ${ssh_verbose_flag} -i "${tmp_ssh_key_file}" -F ${HOME}/R4BigData_DIP_SquidLogsForwarder/ssh-config}

: ${src_folder_to_copy:=$( getSquidLogFolder )}

remote_destination_dir="~/CollectorIn/${my_name}"

src_file_list=`echo ${src_folder_to_copy}/* 2>/dev/null`

if [ -z "${src_file_list}" ]
then
   exit 1
fi

${ssh_command} ${ssh_remote_host_spec} "mkdir -p ${remote_destination_dir}"

set -x
rsync -vv -a --delete -e "${ssh_command}" ${src_folder_to_copy} ${ssh_remote_host_spec}:${remote_destination_dir}
set +x
