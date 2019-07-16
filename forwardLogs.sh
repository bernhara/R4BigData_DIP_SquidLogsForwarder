#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

if [ -r "${HERE}/${CMD}-config" ]
then
    . "${HERE}/${CMD}-config"
fi

: ${collector_lan_hostname:="s-proxetnet.home"}
: ${collector_lan_sshd_port:="22"}
: ${collector_reverse_gateway_hostname:="s-m2m-gw.ow.integ.dns-orange.fr"}
: ${collector_reverse_gateway_sshd_port:="443"}

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

: ${interface_for_indentification:=$(/sbin/ip route | awk '/default/ { print $5 }' )}

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

if [ -z "${my_name}" ]
then
    # no name has been forced => use eth if MAC address
    my_name=$( getMyMacAddress )
fi

#
# ssh configuration
#

: ${connect_to_collector_using_wan_address:=false}

: ${ssh_verbose_flag:=""}


ssh_common_options="${ssh_verbose_flag}"
ssh_common_options="${ssh_common_options} -o User=dip"
ssh_common_options="${ssh_common_options} -o StrictHostKeyChecking=no"
ssh_common_options="${ssh_common_options} -o UserKnownHostsFile=/dev/null"
ssh_common_options="${ssh_common_options} -o ConnectTimeout=5"


# Add ID key 
tmp_ssh_key_file=$( mktemp )
trap "rm -f ${tmp_ssh_key_file}" 0
cp "${HERE}/ssh-key-to-s-proxetnet" "${tmp_ssh_key_file}"
chmod u+r,u-wx,go-rwx "${tmp_ssh_key_file}"

ssh_common_options="${ssh_common_options} -i ${tmp_ssh_key_file}"



ssh_options=${ssh_common_options}

if ${connect_to_collector_using_wan_address}
then
    proxy_command="ssh ${ssh_common_options} -p ${collector_reverse_gateway_sshd_port} ${collector_reverse_gateway_hostname} nc ${collector_lan_hostname} ${collector_lan_sshd_port}"
    ssh_options="${ssh_options} -o ProxyCommand=\"${proxy_command}\""

fi
ssh_command="ssh ${ssh_options} ${collector_lan_hostname}"


: ${src_folder_to_copy:=$( getSquidLogFolder )}

remote_destination_dir="CollectorIn/${my_name}"

src_file_list=$( echo ${src_folder_to_copy}/* 2>/dev/null )

if [ -z "${src_file_list}" ]
then
   exit 1
fi

eval ${ssh_command} \"mkdir -p ${remote_destination_dir}\"

set -x
rsync -vv -a --delete -e "${ssh_command}" ${src_folder_to_copy} :${remote_destination_dir}
set +x
