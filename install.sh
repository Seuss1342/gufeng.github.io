#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}����${plain} ����ʹ��root�û����д˽ű���\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
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
else
    echo -e "${red}δ��⵽ϵͳ�汾������ϵ�ű����ߣ�${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}���ܹ�ʧ�ܣ�ʹ��Ĭ�ϼܹ�: ${arch}${plain}"
fi

echo "�ܹ�: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "�������֧�� 32 λϵͳ(x86)����ʹ�� 64 λϵͳ(x86_64)����������������ϵ����"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}��ʹ�� CentOS 7 ����߰汾��ϵͳ��${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}��ʹ�� Ubuntu 16 ����߰汾��ϵͳ��${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}��ʹ�� Debian 8 ����߰汾��ϵͳ��${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Ĭ��$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar unzip -y
    else
        apt install wget curl tar unzip -y
    fi
}

uninstall_old_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray ]]; then
        confirm "��⵽�ɰ� v2ray���Ƿ�ж�أ���ɾ�� /usr/bin/v2ray/ �� /etc/systemd/system/v2ray.service" "Y"
        if [[ $? != 0 ]]; then
            echo "��ж�����޷���װ v2-ui"
            exit 1
        fi
        echo -e "${green}ж�ؾɰ� v2ray${plain}"
        systemctl stop v2ray
        rm /usr/bin/v2ray/ -rf
        rm /etc/systemd/system/v2ray.service -f
        systemctl daemon-reload
    fi
    if [[ -f /usr/local/bin/v2ray ]]; then
        confirm "��⵽������ʽ��װ�� v2ray���Ƿ�ж�أ�v2-ui �Դ��ٷ� xray �ںˣ�Ϊ��ֹ����˿ڳ�ͻ������ж��" "Y"
        if [[ $? != 0 ]]; then
            echo -e "${red}��ѡ���˲�ж�أ�������ȷ�������ű���װ�� v2ray �� v2-ui ${green}�Դ��Ĺٷ� xray �ں�${red}����˿ڳ�ͻ${plain}"
        else
            echo -e "${green}��ʼж��������ʽ��װ�� v2ray${plain}"
            systemctl stop v2ray
            bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            systemctl daemon-reload
        fi
    fi
}

#close_firewall() {
#    if [[ x"${release}" == x"centos" ]]; then
#        systemctl stop firewalld
#        systemctl disable firewalld
#    elif [[ x"${release}" == x"ubuntu" ]]; then
#        ufw disable
#    elif [[ x"${release}" == x"debian" ]]; then
#        iptables -P INPUT ACCEPT
#        iptables -P OUTPUT ACCEPT
#        iptables -P FORWARD ACCEPT
#        iptables -F
#    fi
#}

install_v2-ui() {
    systemctl stop v2-ui
    cd /usr/local/
    if [[ -e /usr/local/v2-ui/ ]]; then
        rm /usr/local/v2-ui/ -rf
    fi

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/tszho-t/v2-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}��� v2-ui �汾ʧ�ܣ������ǳ��� Github API ���ƣ����Ժ����ԣ����ֶ�ָ�� v2-ui �汾��װ${plain}"
            exit 1
        fi
        echo -e "��⵽ v2-ui ���°汾��${last_version}����ʼ��װ"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux-${arch}.tar.gz https://github.com/tszho-t/v2-ui/releases/download/${last_version}/v2-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}���� v2-ui ʧ�ܣ���ȷ����ķ������ܹ����� Github ���ļ�${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/tszho-t/v2-ui/releases/download/${last_version}/v2-ui-linux-${arch}.tar.gz"
        echo -e "��ʼ��װ v2-ui v$1"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}���� v2-ui v$1 ʧ�ܣ���ȷ���˰汾����${plain}"
            exit 1
        fi
    fi

    tar zxvf v2-ui-linux-${arch}.tar.gz
    rm v2-ui-linux-${arch}.tar.gz -f
    cd v2-ui
    chmod +x v2-ui bin/xray-v2-ui-linux-${arch}
    cp -f v2-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable v2-ui
    systemctl start v2-ui
    echo -e "${green}v2-ui v${last_version}${plain} ��װ��ɣ������������"
    echo -e ""
    echo -e "�����ȫ�°�װ��Ĭ����ҳ�˿�Ϊ ${green}65432${plain}���û���������Ĭ�϶��� ${green}admin${plain}"
    echo -e "������ȷ���˶˿�û�б���������ռ�ã�${yellow}����ȷ�� 65432 �˿��ѷ���${plain}"
    echo -e "���뽫 65432 �޸�Ϊ�����˿ڣ����� v2-ui ��������޸ģ�ͬ��ҲҪȷ�����޸ĵĶ˿�Ҳ�Ƿ��е�"
    echo -e ""
    echo -e "����Ǹ�����壬����֮ǰ�ķ�ʽ�������"
    echo -e ""
    curl -o /usr/bin/v2-ui -Ls https://raw.githubusercontent.com/tszho-t/v2-ui/master/v2-ui.sh
    chmod +x /usr/bin/v2-ui
    echo -e "v2-ui ����ű�ʹ�÷���: "
    echo -e "----------------------------------------------"
    echo -e "v2-ui              - ��ʾ����˵� (���ܸ���)"
    echo -e "v2-ui start        - ���� v2-ui ���"
    echo -e "v2-ui stop         - ֹͣ v2-ui ���"
    echo -e "v2-ui restart      - ���� v2-ui ���"
    echo -e "v2-ui status       - �鿴 v2-ui ״̬"
    echo -e "v2-ui enable       - ���� v2-ui ��������"
    echo -e "v2-ui disable      - ȡ�� v2-ui ��������"
    echo -e "v2-ui log          - �鿴 v2-ui ��־"
    echo -e "v2-ui update       - ���� v2-ui ���"
    echo -e "v2-ui install      - ��װ v2-ui ���"
    echo -e "v2-ui uninstall    - ж�� v2-ui ���"
    echo -e "----------------------------------------------"
}

echo -e "${green}��ʼ��װ${plain}"
install_base
uninstall_old_v2ray
#close_firewall
install_v2-ui $1