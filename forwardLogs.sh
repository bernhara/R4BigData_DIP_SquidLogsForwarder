#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

: ${stdout_log_file:="${HERE}/${CMD}.stdout.log"}
: ${stderr_log_file:="${HERE}/${CMD}.stderr.log"}


: ${redirect_output:=true}

if ${redirect_output}
then
    exec 1>"${stdout_log_file}" 2>"${stderr_log_file}"
fi

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

: ${my_name:=`getMyDnsName`}
: ${use_collector_wan_address:=false}

if ${use_collector_wan_address}
then
    ssh_remote_host_spec="log-collector-wan"
else
    ssh_remote_host_spec="log-collector-lan"
fi
    


: ${ssh_verbose_flag:=""}
: ${ssh_command:=ssh ${ssh_verbose_flag} -F ${HOME}/R4BigData_DIP_SquidLogsForwarder/ssh-config}

: ${src_folder_to_copy:=`getSquidLogFolder`}

chmod go-rwx ~/R4BigData_DIP_SquidLogsForwarder/ssh-key-*

remote_destination_dir="~/CollectorIn/${my_name}"

src_file_list=`echo ${src_folder_to_copy}/* 2>/dev/null`

if [ -z "${src_file_list}" ]
then
   exit 1
fi

${ssh_command} ${ssh_remote_host_spec} "mkdir -p ${remote_destination_dir}"

set -x
rsync -I --delete -a -v -e "${ssh_command}" ${src_folder_to_copy} ${ssh_remote_host_spec}:${remote_destination_dir}
set +x
