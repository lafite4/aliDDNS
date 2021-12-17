#!/bin/bash
set -e

#================================================================================================================#
# 功能：用于更新阿里云域名IP，实现DDNS功能
#
# 在 http://www.gebi1.com/forum.php?mod=viewthread&tid=287344&page=1&_dsign=8f94f74c 提供的脚本文件基础上修改的。
# ghui, modified 12/2/2019
# 在 N1 debian Buster with Armbian Linux 5.3.0-aml-g12 手动执行/定时任务(crontab)执行测试通过
# 2021-11-05 修改 支持@ 和*域名的处理，增加对群晖6.22的bug的修改并测试通过。by lafite
# 2021-11-05 增加日志功能
#================================================================================================================#
#
# 使用方法：
#
# 方法1. 外部参数
# aliddns.sh <aliddns_ak> <aliddns_sk> <aliddns_subdomain> <aliddns_domain> <aliddns_iptype> <aliddns_ttl>
# 示例（A 代表 IPv4，AAAA 代表 IPv6）: 
# 执行：aliddns.sh "xxxx" "xxx" "test" "mydomain.site" "A" 600
# 执行：aliddns.sh "xxxx" "xxx" "test" "mydomain.site" "AAAA" 600
#
# 方法2. 内部参数
# 修改源码，将$1,$2,$3,$4,$5,$6 替换为对应参数
# 
# 示例: 
# aliddns_ak="xxxx"
# aliddns_sk="xxx"
# aliddns_subdomain="test"
# aliddns_domain="mydomain.site"
# aliddns_iptype="A"
# aliddns_ttl=600 
# 执行：aliddns.sh
#
#================================================================================================================#

#--------------------------------------------------------------
# 参数
#
# (*)阿里云 AccessKeyId 
aliddns_ak=$1 
# (*)阿里云 AccessKeySecret 
aliddns_sk=$2 

# (*)域名：test.mydomain.com 
aliddns_subdomain=$3 #'test'
aliddns_domain=$4 #'mydomain.com'

# (*)ip地址类型：'A' 或 'AAAA'，代表ipv4 和 ipv6
aliddns_iptype=$5 # 'A' 或 'AAAA'，代表ipv4 和 ipv6

# TTL 默认10分钟 = 600秒 
aliddns_ttl=$6 #"600"

#--------------------------------------------------------------
mdate=$(date "+%Y-%m-%d")
logPath="/volume2/docker/DNSCheck/log/DNSCheck$mdate.log"
debug_flag="0"
#--------------------------------------------------------------
machine_ip=""
ddns_ip=""
aliddns_record_id=""
#--------------------------------------------------------------

aliddns_name=$aliddns_subdomain.$aliddns_domain

if [ "$aliddns_subdomain" = "@" ]; then
	aliddns_subdomain="%40"
	aliddns_name=$aliddns_domain
fi

if [ "$aliddns_subdomain" = '*' ]; then
	aliddns_subdomain="%2A"	
fi

echo "*********************$(date -d today +"%Y-%m-%d %H:%M:%S") START*****************************"  | tee -a "$logPath"
echo "$aliddns_name" | tee -a "$logPath"

function getMachine_IPv4() {
    local ipv4
    ipv4=$(/usr/bin/wget -qO- -t1 -T2 http://ip.3322.net)
    echo "$ipv4"
}

function getMachine_IPv6() {
    local ipv6
    ipv6=$(ip addr | grep "inet6.*global" | grep -v "deprecated" | grep "dynamic" | awk '{print $2}' | awk -F"/" '{print $1}')
    echo "$ipv6"
}

function getDDNS_IPV4() {
    current_ip=$(nslookup -query=$aliddns_iptype $aliddns_name | grep "Address" | grep -v "#53" | awk '{print $2}')
    echo "$current_ip"
}

function getDDNS_IPV6() {
    current_ip=$(nslookup -query=$aliddns_iptype ${aliddns_name/\*/whoami2021} | grep "address" | awk '{print $5}')
    echo "$current_ip"
}

function enc() {
    echo -n "$1" | urlencode
}

function send_request() {
    local args="AccessKeyId=$aliddns_ak&Action=$1&Format=json&$2&Version=2015-01-09"
    local  hash
    hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$aliddns_sk&" -binary | openssl base64) 
    if [ "$debug_flag" = '1' ]; then echo "debug info [send_request]:(args) $args" | tee -a "$logPath" >&2  ; fi
    curl -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
}

function get_recordid() {
  grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'
}

function query_recordid() {	
	local result
    result=$(send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$aliddns_subdomain.$aliddns_domain&Timestamp=$timestamp&Type=$aliddns_iptype")
	if [ "$debug_flag" = '1' ]; then echo "debug info [query_recordid]: $result" | tee -a "$logPath" >&2  ; fi
	echo "$result"
}

function update_record() {
    send_request "UpdateDomainRecord" "RR=$aliddns_subdomain&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=$aliddns_iptype&Value=$(enc $machine_ip)"
}

function add_record() {
    send_request "AddDomainRecord&DomainName=$aliddns_domain" "RR=$aliddns_subdomain&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns_ttl&Timestamp=$timestamp&Type=$aliddns_iptype&Value=$(enc $machine_ip)"
    }

function urlencode() {
    # urlencode <string>
    out=""
    while read -r -n1 c
    do
        case $c in
            [a-zA-Z0-9.~_-]) out="$out$c" ;;
            *) out="$out$(printf '%%%02X' "'$c")" 
            ;;
        esac
    done
    if [ "$debug_flag" = '1' ]; then echo "debug info [enc]:(urlencode) $out " | tee -a "$logPath" >&2 ; fi
    
    echo -n "$out"
    }
    

if [ "$aliddns_iptype" = 'A' ]
then
    echo "ddns is IPv4." | tee -a "$logPath"

    machine_ip="$(getMachine_IPv4)" 

    echo "machine_ip = $machine_ip" | tee -a "$logPath"

    aliddns_record_id=$aliddnsipv4_record_id
    
    ddns_ip="$(getDDNS_IPV4)"
else
    echo "ddns is IPv6." | tee -a "$logPath"

    machine_ip="$(getMachine_IPv6)"

    echo "machine_ip = $machine_ip" | tee -a "$logPath"

	
    aliddns_record_id=$aliddnsipv6_record_id
    ddns_ip="$(getDDNS_IPV6)"
fi

echo "ddns_ip = $ddns_ip" | tee -a "$logPath"

if [ "$machine_ip" = "" ]
then
    echo "machine_ip is empty!" | tee -a "$logPath"
    exit 0
fi

if [ "$machine_ip" = "$ddns_ip" ]
then
    echo "Skipping..............." | tee -a "$logPath"
    echo "*********************$(date -d today +"%Y-%m-%d %H:%M:%S") END  *****************************"  | tee -a "$logPath"
    if [ "$debug_flag" = '0' ]; then exit 1 ; fi
fi

echo "start update..." | tee -a "$logPath"

timestamp=$(date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ")


echo "--------DNS Record ID--------"  | tee -a "$logPath"
        
aliddns_record_id=$(query_recordid | get_recordid) 

echo "ID:$aliddns_record_id"  | tee -a "$logPath"
echo "--------DNS Record ID--------"  | tee -a "$logPath"


#add support */%2A and @/%40 record
if [ "$aliddns_record_id" = "" ] && [  "$ddns_ip" = "" ] 
then
    echo "add record starting"  | tee -a "$logPath"

    aliddns_record_id=$(add_record | get_recordid)

    if [ "$aliddns_record_id" = "" ]
    then
        echo "aliddns_record_id is empty. "  | tee -a "$logPath"
    else
        echo "added record $aliddns_record_id "  | tee -a "$logPath"
    fi
elif [ ! "$aliddns_record_id" = "" ]
then
    echo "update record starting"  | tee -a "$logPath"
    
    update_record "$aliddns_record_id"
    
    echo "updated record $aliddns_record_id "  | tee -a "$logPath"
else
	echo "updated record error ! rocoid id: $aliddns_record_id "  | tee -a "$logPath"
fi

echo "*********************$(date -d today +"%Y-%m-%d %H:%M:%S") END  *****************************"  | tee -a "$logPath"
