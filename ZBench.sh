# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

# Check if wget installed
if  [ ! -e '/usr/bin/wget' ]; then
    echo "Error: wget command not found. You must be install wget command at first."
    exit 1
fi
read -p "Please Enter Your Host Provider: " Provider


# Get IP
OwnerIP=$(who am i | awk '{print $NF}' | sed -e 's/[()]//g')
while :; do echo
  read -p "Please Confirm Your Client IP:${OwnerIP} [y/n]: " ifOwnerIP
  if [[ ! ${ifOwnerIP} =~ ^[y,n]$ ]]; then
    echo "Input error! Please only input 'y' or 'n'"
  else
    break
  fi
done
if [[ ${ifOwnerIP} == "n" ]]; then
  while :; do echo
    read -p "Please Enter Your Client IP: " OwnerIP
    if [[ ! ${OwnerIP} ]]; then
      echo "Input error! Cannot be void!"
    else
      break
    fi
  done
fi


# Check release
if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

rm -rf /tmp/report && mkdir /tmp/report

echo "Installing required packages, please wait..."

# Install Virt-what
if  [ ! -e '/usr/sbin/virt-what' ]; then
    echo "Installing Virt-What......"
    if [ "${release}" == "centos" ]; then
        yum -y install virt-what > /dev/null 2>&1
    else
        apt-get update > /dev/null 2>&1
        apt-get -y install virt-what > /dev/null 2>&1
    fi
fi



# Install uuid
echo "Installing uuid......"
if [ "${release}" == "centos" ]; then
    yum -y install uuid > /dev/null 2>&1
else
    apt-get -y install uuid > /dev/null 2>&1
fi


# Install curl
echo "Installing curl......"
if [ "${release}" == "centos" ]; then
    yum -y install curl > /dev/null 2>&1
else
    apt-get -y install curl > /dev/null 2>&1
fi


# Install Besttrace
if  [ ! -e '/tmp/besttrace' ]; then
    echo "Installing Besttrace......"
    dir=$(pwd)
    cd /tmp/
    wget  -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/besttrace > /dev/null 2>&1
    cd $dir
fi
chmod a+rx /tmp/besttrace

# Check Python
if  [ ! -e '/usr/bin/python' ]; then
    echo "Installing Python......"
    if [ "${release}" == "centos" ]; then
            yum update > /dev/null 2>&1
            yum -y install python
        else
            apt-get update > /dev/null 2>&1
            apt-get -y install python
    fi
fi

# Install Speedtest
if  [ ! -e '/tmp/speedtest.py' ]; then
    echo "Installing SpeedTest......"
    dir=$(pwd)
    cd /tmp/
    wget  -N --no-check-certificate https://raw.github.com/sivel/speedtest-cli/master/speedtest.py > /dev/null 2>&1
    cd $dir
fi
chmod a+rx /tmp/speedtest.py


# Install Zping
if  [ ! -e '/tmp/ZPing.py' ]; then
    echo "Installing ZPing.py......"
    dir=$(pwd)
    cd /tmp/
    wget  -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZPing.py > /dev/null 2>&1
    cd $dir
fi
chmod a+rx /tmp/ZPing.py

#"TraceRoute to Shanghai Telecom"
/tmp/besttrace 61.129.42.6 > /tmp/sht.txt 2>&1 &
#"TraceRoute to Shanghai Mobile"
/tmp/besttrace speedtest2.sh.chinamobile.com > /tmp/shm.txt 2>&1 &
#"TraceRoute to Shanghai Unicom"
/tmp/besttrace 210.22.80.1 > /tmp/shu.txt 2>&1 &
#"TraceRoute to Guangdong Telecom"
/tmp/besttrace 121.14.220.240 > /tmp/gdt.txt 2>&1 &
#"TraceRoute to Guangdong Mobile"
/tmp/besttrace 211.136.192.6 > /tmp/gdm.txt 2>&1 &
#"TraceRoute to Guangdong Unicom"
/tmp/besttrace 221.5.88.88 > /tmp/gdu.txt 2>&1 &
#"TraceRoute to Owner's Network"
/tmp/besttrace ${OwnerIP} > /tmp/own.txt 2>&1 &




get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-74s\n" "-" | sed 's/\s/-/g'
}

speed_test() {
    local speedtest=$(wget -4O /dev/null -T300 $1 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}')
    local ipaddress=$(ping -c1 -n `awk -F'/' '{print $3}' <<< $1` | awk -F'[()]' '{print $2;exit}')
    local nodeName=$2
    local latency=$(ping $ipaddress -c 3 | grep avg | awk -F / '{print $5}')" ms"
    printf "${YELLOW}%-26s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}\n" "${nodeName}" "${ipaddress}" "${speedtest}" "${latency}"

    #Record Speed Data
    echo ${ipaddress} >> /tmp/speed.txt
    echo ${speedtest} >> /tmp/speed.txt
    echo ${latency} >> /tmp/speed.txt
}

speed() {
    rm -rf /tmp/speed.txt && touch /tmp/speed.txt
    speed_test 'http://cachefly.cachefly.net/100mb.test' 'CacheFly'
    speed_test 'http://speedtest.tokyo.linode.com/100MB-tokyo.bin' 'Linode, Tokyo, JP'
    speed_test 'http://speedtest.singapore.linode.com/100MB-singapore.bin' 'Linode, Singapore, SG'
    speed_test 'http://speedtest.london.linode.com/100MB-london.bin' 'Linode, London, UK'
    speed_test 'http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin' 'Linode, Frankfurt, DE'
    speed_test 'http://speedtest.fremont.linode.com/100MB-fremont.bin' 'Linode, Fremont, CA'
    speed_test 'http://speedtest.dal05.softlayer.com/downloads/test100.zip' 'Softlayer, Dallas, TX'
    speed_test 'http://speedtest.sea01.softlayer.com/downloads/test100.zip' 'Softlayer, Seattle, WA'
    speed_test 'http://speedtest.fra02.softlayer.com/downloads/test100.zip' 'Softlayer, Frankfurt, DE'
    speed_test 'http://speedtest.sng01.softlayer.com/downloads/test100.zip' 'Softlayer, Singapore, SG'
    speed_test 'http://speedtest.hkg02.softlayer.com/downloads/test100.zip' 'Softlayer, HongKong, CN'
}

speed_test_cn(){
    if [[ $1 == '' ]]; then
        temp=$(python /tmp/speedtest.py --share 2>&1)
        is_down=$(echo "$temp" | grep 'Download')
        if [[ ${is_down} ]]; then
            local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
            local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
            local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')
            local nodeName=$2

            printf "${YELLOW}%-25s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}\n" "${nodeName}" "${reupload}" "${REDownload}" "${relatency}"
        else
            local cerror="ERROR"
        fi
    else
        temp=$(python /tmp/speedtest.py --server $1 --share 2>&1)
        is_down=$(echo "$temp" | grep 'Download')
        if [[ ${is_down} ]]; then
            local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
            local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
            local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')
            temp=$(echo "$relatency" | awk -F '.' '{print $1}')
            if [[ ${temp} -gt 1000 ]]; then
                relatency=" 000.000 ms"
            fi
            local nodeName=$2

            printf "${YELLOW}%-25s${GREEN}%-18s${RED}%-20s${SKYBLUE}%-12s${PLAIN}\n" "${nodeName}" "${reupload}" "${REDownload}" "${relatency}"
        else
            local cerror="ERROR"
        fi
    fi

    #Record Speed_cn Data
    echo ${reupload} >> /tmp/speed_cn.txt
    echo ${REDownload} >> /tmp/speed_cn.txt
    echo ${relatency} >> /tmp/speed_cn.txt


}

speed_cn() {
    rm -rf /tmp/speed_cn.txt && touch /tmp/speed_cn.txt

    speed_test_cn '12637' 'Xiangyang CT'
    speed_test_cn '3633' 'Shanghai  CT'
    speed_test_cn '4624' 'Chengdu   CT'
    speed_test_cn '4863' "Xi'an     CU"
    speed_test_cn '5083' 'Shanghai  CU'
    speed_test_cn '5726' 'Chongqing CU'
    speed_test_cn '5192' "Beijing   CT"
    speed_test_cn '4665' 'Beijing   CT'
    speed_test_cn '4575' 'Hunan     CT'

    rm -rf /tmp/speedtest.py
}


io_test() {
    (LANG=C dd if=/dev/zero of=test_$$ bs=64k count=16k conv=fdatasync && rm -f test_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
tram=$( free -m | awk '/Mem/ {print $2}' )
uram=$( free -m | awk '/Mem/ {print $3}' )
swap=$( free -m | awk '/Swap/ {print $2}' )
uswap=$( free -m | awk '/Swap/ {print $3}' )
up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime )
load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
opsy=$( get_opsy )
arch=$( uname -m )
lbit=$( getconf LONG_BIT )
kern=$( uname -r )
ipv6=$( wget -qO- -t1 -T2 ipv6.icanhazip.com )
disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
disk_total_size=$( calc_disk ${disk_size1[@]} )
disk_used_size=$( calc_disk ${disk_size2[@]} )


clear
next
echo -e "CPU model            : ${SKYBLUE}$cname${PLAIN}"
echo -e "Number of cores      : ${SKYBLUE}$cores${PLAIN}"
echo -e "CPU frequency        : ${SKYBLUE}$freq MHz${PLAIN}"
echo -e "Total size of Disk   : ${SKYBLUE}$disk_total_size GB ($disk_used_size GB Used)${PLAIN}"
echo -e "Total amount of Mem  : ${SKYBLUE}$tram MB ($uram MB Used)${PLAIN}"
echo -e "Total amount of Swap : ${SKYBLUE}$swap MB ($uswap MB Used)${PLAIN}"
echo -e "System uptime        : ${SKYBLUE}$up${PLAIN}"
echo -e "Load average         : ${SKYBLUE}$load${PLAIN}"
echo -e "OS                   : ${SKYBLUE}$opsy${PLAIN}"
echo -e "Arch                 : ${SKYBLUE}$arch ($lbit Bit)${PLAIN}"
echo -e "Kernel               : ${SKYBLUE}$kern${PLAIN}"
echo -ne "Virt                 : "
virtua=$(virt-what) 2>/dev/null

if [[ ${virtua} ]]; then
    echo -e "${SKYBLUE}$virtua${PLAIN}"
else
    virtua="No Virt"
    echo -e "${SKYBLUE}No Virt${PLAIN}"
fi

next
io1=$( io_test )
echo -e "I/O speed(1st run)   :${YELLOW}$io1${PLAIN}"
io2=$( io_test )
echo -e "I/O speed(2nd run)   :${YELLOW}$io2${PLAIN}"
io3=$( io_test )
echo -e "I/O speed(3rd run)   :${YELLOW}$io3${PLAIN}"
next


##Record All Test data
rm -rf /tmp/info.txt
touch /tmp/info.txt
echo $cname >> /tmp/info.txt
echo $cores >> /tmp/info.txt
echo $freq MHz >> /tmp/info.txt
echo "$disk_total_size GB ($disk_used_size GB ?????????) ">> /tmp/info.txt
echo "$tram MB ($uram MB ?????????) ">> /tmp/info.txt
echo "$swap MB ($uswap MB ?????????)" >> /tmp/info.txt
echo $up >> /tmp/info.txt
echo $load >> /tmp/info.txt
echo $opsy >> /tmp/info.txt
echo "$arch ($lbit ???) ">> /tmp/info.txt
echo $kern >> /tmp/info.txt
echo $virtua >> /tmp/info.txt
echo $io1 >> /tmp/info.txt
echo $io2 >> /tmp/info.txt
echo $io3 >> /tmp/info.txt
AKEY=$( uuid )

printf "%-26s%-18s%-20s%-12s\n" "Node Name" "IP Address" "Download Speed" "Latency"
speed && next
printf "%-26s%-18s%-20s%-12s\n" "Node Name" "Upload Speed" "Download Speed" "Latency"
speed_cn && next
python /tmp/ZPing.py
next



NetCFspeec=$( sed -n "2p" /tmp/speed.txt )
NetCFping=$( sed -n "3p" /tmp/speed.txt )
NetLJPspeed=$( sed -n "5p" /tmp/speed.txt )
NetLJPping=$( sed -n "6p" /tmp/speed.txt )
NetLSGspeed=$( sed -n "8p" /tmp/speed.txt )
NetLSGping=$( sed -n "9p" /tmp/speed.txt )
NetLUKspeed=$( sed -n "11p" /tmp/speed.txt )
NetLUKping=$( sed -n "12p" /tmp/speed.txt )
NetLDEspeed=$( sed -n "14p" /tmp/speed.txt )
NetLDEping=$( sed -n "15p" /tmp/speed.txt )
NetLCAspeed=$( sed -n "17p" /tmp/speed.txt )
NetLCAping=$( sed -n "18p" /tmp/speed.txt )
NetSTXspeed=$( sed -n "20p" /tmp/speed.txt )
NetSTXping=$( sed -n "21p" /tmp/speed.txt )
NetSWAspeed=$( sed -n "23p" /tmp/speed.txt )
NetSWAping=$( sed -n "24p" /tmp/speed.txt )
NetSDEspeed=$( sed -n "26p" /tmp/speed.txt )
NetSDEping=$( sed -n "27p" /tmp/speed.txt )
NetSSGspeed=$( sed -n "29p" /tmp/speed.txt )
NetSSGping=$( sed -n "30p" /tmp/speed.txt )
NetSCNspeed=$( sed -n "32p" /tmp/speed.txt )
NetSCNping=$( sed -n "33p" /tmp/speed.txt )


NetUPST=$( sed -n "4p" /tmp/speed_cn.txt )
NetDWST=$( sed -n "5p" /tmp/speed_cn.txt )
NetPiST=$( sed -n "6p" /tmp/speed_cn.txt )
NetUPCT=$( sed -n "7p" /tmp/speed_cn.txt )
NetDWCT=$( sed -n "8p" /tmp/speed_cn.txt )
NetPiCT=$( sed -n "9p" /tmp/speed_cn.txt )
NetUPXT=$( sed -n "10p" /tmp/speed_cn.txt )
NetDWXT=$( sed -n "11p" /tmp/speed_cn.txt )
NetPiXT=$( sed -n "12p" /tmp/speed_cn.txt )
NetUPSU=$( sed -n "13p" /tmp/speed_cn.txt )
NetDWSU=$( sed -n "14p" /tmp/speed_cn.txt )
NetPiSU=$( sed -n "15p" /tmp/speed_cn.txt )
NetUPCU=$( sed -n "16p" /tmp/speed_cn.txt )
NetDWCU=$( sed -n "17p" /tmp/speed_cn.txt )
NetPiCU=$( sed -n "18p" /tmp/speed_cn.txt )
NetUPXM=$( sed -n "19p" /tmp/speed_cn.txt )
NetDWXM=$( sed -n "20p" /tmp/speed_cn.txt )
NetPiXM=$( sed -n "21p" /tmp/speed_cn.txt )
NetUPSM=$( sed -n "22p" /tmp/speed_cn.txt )
NetDWSM=$( sed -n "23p" /tmp/speed_cn.txt )
NetPiSM=$( sed -n "24p" /tmp/speed_cn.txt )
NetUPCM=$( sed -n "25p" /tmp/speed_cn.txt )
NetDWCM=$( sed -n "26p" /tmp/speed_cn.txt )
NetPiCM=$( sed -n "27p" /tmp/speed_cn.txt )


wget  -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/Generate.py >> /dev/null 2>&1
python Generate.py && rm -rf Generate.py && cp /root/report.html /tmp/report/index.html
TSM=$( cat /tmp/shm.txt_table )
TST=$( cat /tmp/sht.txt_table )
TSU=$( cat /tmp/shu.txt_table )
TGM=$( cat /tmp/gdm.txt_table )
TGT=$( cat /tmp/gdt.txt_table )
TGU=$( cat /tmp/gdu.txt_table )
curl 'http://api.zbench.kirito.moe/action.php' --data "CPUmodel=$cname &CPUspeed=$freq MHz &CPUcore=$cores &HDDsize=$disk_total_size GB ($disk_used_size GB ?????????) &RAMsize=$tram MB ($uram MB ?????????)&SWAPsize=$swap MB ($uswap MB ?????????)&UPtime= $up&Arch=1&systemload=$load&OS= $opsy &Arch=$arch ($lbit ???)&Kernel=$kern &Virmethod=$virtua &IOa=$io1&IOb=$io2&IOc=$io3&NetCFspeec=$NetCFspeec&NetCFping=$NetCFping&NetLJPspeed=$NetLJPspeed&NetLJPping=$NetLJPping&NetLSGspeed=$NetLSGspeed&NetLSGping=$NetLSGping&NetLUKspeed=$NetLUKspeed&NetLUKping=$NetLUKping&NetLDEspeed=$NetLDEspeed&NetLDEping=$NetLDEping&NetLCAspeed=$NetLCAspeed&NetLCAping=$NetLCAping&NetSTXspeed=$NetSTXspeed&NetSTXping=$NetSTXping&NetSWAspeed=$NetSWAspeed&NetSWAping=$NetSWAping&NetSDEspeed=$NetSDEspeed&NetSDEping=$NetSDEping&NetSSGspeed=$NetSSGspeed&NetSSGping=$NetSSGping&NetSCNspeed=$NetSCNspeed&NetSCNping=$NetSCNping&NetUPST=$NetUPST&NetDWST=$NetDWST&NetPiST=$NetPiST&NetUPCT=$NetUPCT&NetDWCT=$NetDWCT&NetPiCT=$NetPiCT&NetUPXT=$NetUPXT&NetDWXT=$NetDWXT&NetPiXT=$NetPiXT&NetUPSU=$NetUPSU&NetDWSU=$NetDWSU&NetPiSU=$NetPiSU&NetUPCU=$NetUPCU&NetDWCU=$NetDWCU&NetPiCU=$NetPiCU&NetUPXM=$NetUPXM&NetDWXM=$NetDWXM&NetPiXM=$NetPiXM&NetUPSM=$NetUPSM&NetDWSM=$NetDWSM&NetPiSM=$NetPiSM&NetUPCM=$NetUPCM&NetDWCM=$NetDWCM&NetPiCM=$NetPiCM&TSM=$TSM&TST=$TST&TSU=$TSU&TGM=$TGM&TGT=$TGT&TGU=$TGU&AKEY=$AKEY&Provider=$Provider"

IKEY=$(curl "http://api.zbench.kirito.moe/getkey.php?AKEY=$AKEY" 2>/dev/null)
echo "Result Address???https://zbench.kirito.moe/record.php?IKEY=$IKEY"
echo "Your bench data is saved to /root/report.html"

# If use simple http server
while :; do echo
  read -p "Do you want to check your Test Report? [y/n]: " ifreport
  if [[ ! $ifreport =~ ^[y,n]$ ]]; then
    echo "Input error! Please only input 'y' or 'n'"
  else
    break
  fi
done

if [[ $ifreport == 'y' ]];then
    echo ""
    myip=`curl -m 10 -s http://members.3322.org/dyndns/getip`
    echo "Visit http://${myip}:8001/index.html to see your report???Press Ctrl + C to exit."
	cd /tmp/report
    python -m SimpleHTTPServer 8001
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8001 -j ACCEPT
fi
