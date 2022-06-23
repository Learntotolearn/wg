#!/bin/bash
export LANG="en_US.UTF-8"
wg_dir="/etc/wireguard/"
ID=$(cat /etc/os-release | grep  'ID=' | head -n 1 | awk -F "=" '{print $2}')
VERSION_ID=$(cat /etc/os-release | grep  'VERSION_ID=' | awk -F "=" '{print $2}')

#fonts color
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"



#检测命令是否错误
judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 Finish ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 Fail ${Font}"
        exit 1
    fi
}

#生成公私钥
pskey (){
    read  -e -p "输入服务端名: " wg_pub_name
    read  -e -p "输入客户端名: " wg_pri_name
    wg genkey | tee $wg_dir$wg_pub_name"_privatekey" | wg pubkey > $wg_dir$wg_pub_name"_publickey"
    wg genkey | tee $wg_dir$wg_pri_name"_privatekey" | wg pubkey > $wg_dir$wg_pri_name"_publickey"
    echo -e "${GreenBG} wireguard公私钥已生成在$wg_dir目录下 ${Font} \n"
    echo -e "${GreenBG} 开始生成服务端配置文件 ${Font} \n"
}


#生成服务端配置文件
wg_server_conf (){
    #
    while true; do
    read -e -p "请输入服务端AllowedIPs的范围: " wg_s_allowIP
     check_ip $wg_s_allowIP
     [ $? -eq 0 ] && break
    done
    read -e -p "请输入服务端监听端口（使用未被占用的端口）: " wg_s_listenPort
    wg_s_prikey=$(cat $wg_dir$wg_pub_name"_privatekey")
    wg_c_pubkey=$(cat $wg_dir$wg_pri_name"_publickey")
    echo "
    [Interface]
    PrivateKey = $wg_s_prikey
    ListenPort = $wg_s_listenPort

    [Peer]
    PublicKey = $wg_c_pubkey
    AllowedIPs = $wg_s_allowIP " > $wg_dir$wg_pub_name.conf
    echo -e "${GreenBG} wireguard服务端文件已生成在$wg_dir目录下 ${Font}\n"
    echo -e "${GreenBG} 开始生成客户端配置文件 ${Font}\n"

    ##### 生成客户端配置文件 ########
    read -e -p "输入客户端监听端口（使用未被占用的端口）: " wg_c_listenPort
    #
    while true; do
    read -e -p "输入客户端IP地址（要与服务端同网段）: " wg_c_IP
    check_ip $wg_c_IP
     [ $? -eq 0 ] && break
    done
    #
    while true; do
    read -e -p "输入服务端公网IP: " wg_s_serverIP
    check_ip $wg_s_serverIP
     [ $? -eq 0 ] && break
    done

    #read -e -p "输入服务端wireguard监听端口: " wg_to_s_listenPort
    wg_s_pubkey=$(cat $wg_dir$wg_pub_name"_publickey") 
    wg_c_prikey=$(cat $wg_dir$wg_pri_name"_privatekey")
    echo "
    [Interface]
    PrivateKey = $wg_c_prikey
    ListenPort = $wg_c_listenPort
    Address = $wg_c_IP
    DNS = 8.8.8.8
    MTU = 1360

    [Peer]
    PublicKey = $wg_s_pubkey
    Endpoint = $wg_s_serverIP:$wg_s_listenPort
    AllowedIPs = 0.0.0.0/0
    PersistentKeepalive = 25 " > $wg_dir$wg_pri_name.conf
    echo -e "${GreenBG} wireguard客户端文件已生成在$wg_dir目录下\n  ${Font}"
    echo -e "${GreenBG} 开始启动服务端wg ${Font} \n"
}



#启动wireguard服务端
wg_start_server (){
    while true; do
    read -e -p "输入服务器端wg的IP地址： " wg_server_ip
    check_ip $wg_server_ip
     [ $? -eq 0 ] && break
    done
    ip link add dev $wg_pub_name type wireguard 
    ip address add dev $wg_pub_name $wg_server_ip 
    wg setconf $wg_pub_name $wg_dir$wg_pub_name.conf
    ip link set up $wg_pub_name 
    ip link set mtu 1360 dev $wg_pub_name
    eth=`ip route | grep default | grep dev | awk '{print $5}'`
    iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
    if [ $? -eq 0 ] ; then
        echo -e "${GreenBG} 启动成功 ${Font} \n"
        else
        echo -e "${RedBG} 启动失败 ${Font} \n"
    fi
    start_menu
}

wg_client_show(){
    show_client=`cat $wg_dir$wg_pri_name.conf`
    echo -e "客户端文件内容：\n $show_client"
    start_menu

}

add_wg_client(){
    read  -e -p "输入需要增加客户端的wg文件名(不需要文件后缀): " wg_pubb_name
    read  -e -p "输入客户端文件名(不需要文件后缀): " wg_prii_name
    #
    while true; do
    read -p "输入AllowedIPs范围: " wg_ss_allowIP
    check_ip $wg_ss_allowIP
     [ $? -eq 0 ] && break
    done
    read -e -p "输入AllowedIPs范围: " wg_ss_allowIP
    wg genkey | tee $wg_dir$wg_prii_name"_privatekey" | wg pubkey > $wg_dir$wg_prii_name"_publickey"
    wg_cc_pubkey=`cat $wg_dir$wg_prii_name"_publickey"`
    echo "

    [Peer]
    PublicKey = $wg_cc_pubkey
    AllowedIPs = $wg_ss_allowIP " >> $wg_dir$wg_pubb_name".conf"
    echo -e "服务端配置文件添加新客户端成功\n"
    read  -e -p "apply？【y/n】:" yn
    if [  $yn = "y" ];then
        wg setconf $wg_pubb_name $wg_dir$wg_pubb_name".conf"
    else
        exit 1
    fi
    #iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    read -e -p "输入客户端监听端口（使用未被占用的端口）: " wg_cc_listenPort
    #
    while true; do
    read -e -p "输入客户端IP地址（要与服务端同网段,格式:xx.xx.xx.xx/xx）: " wg_cc_IP
    check_ip $wg_cc_IP
     [ $? -eq 0 ] && break
    done
    #
    while true; do
    read -e -p "输入服务端公网IP: " wg_ss_serverIP
    check_ip $wg_ss_serverIP
     [ $? -eq 0 ] && break
    done

    read -e -p "输入服务端wireguard监听端口: " wg_to_ss_listenPort
    wg_ss_pubkey=$(cat $wg_dir$wg_pubb_name"_publickey") 
    wg_cc_prikey=$(cat $wg_dir$wg_prii_name"_privatekey")
    echo "
    [Interface]
    PrivateKey = $wg_cc_prikey
    ListenPort = $wg_cc_listenPort
    Address = $wg_cc_IP
    DNS = 8.8.8.8
    MTU = 1360

    [Peer]
    PublicKey = $wg_ss_pubkey
    Endpoint = $wg_ss_serverIP:$wg_to_ss_listenPort
    AllowedIPs = 0.0.0.0/0
    PersistentKeepalive = 25 " > $wg_dir$wg_prii_name".conf"
    echo -e "\n"
    echo -e "wireguard客户端文件已生成在$wg_dir目录下\n 文件内容: \n `cat $wg_dir$wg_prii_name".conf"`"

}

#ip检测
check_ip() {
echo $1|grep -E  "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[1-9]{1,2}$" > /dev/null;
    if [ $? -ne 0 ];then
        echo $1|grep -E  "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" > /dev/null;
        if [ $? -ne 0 ];then
            echo "IP地址必须全部为数字" 
            return 1
        fi
        
    fi
#  echo $1|grep -E  "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[1-9]{1,2}$" > /dev/null;
#     if [ $? -ne 0 ]
#     then
#         echo "IP地址必须全部为数字" 
#         return 1
#     fi
    ipaddr=$1
    a=`echo $ipaddr|awk -F . '{print $1}'`  #以"."分隔，取出每个列的值 
    b=`echo $ipaddr|awk -F . '{print $2}'`
    c=`echo $ipaddr|awk -F . '{print $3}'`
    d=`echo $ipaddr|awk -F . '{print $4}'|awk -F / '{print $1}'`
    e=`echo $ipaddr|awk -F / '{print $2}'`
    for num in $a $b $c $d
    do
        if [ $num -gt 255 ] || [ $num -lt 0 ]    #每个数值必须在0-255之间 
        then
            echo $ipaddr "中，字段"$num"错误" 
            return 1
        fi
   done
       
    for mask in $e
    do
        if [ $mask -gt 32 ] || [ $mask -lt 1 ]    #每个数值必须在0-255之间 
        then
            echo $ipaddr "中，字段"$mask"错误" 
            return 1
        fi
   done
   return 0

}

#二维码
qr(){

    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
            echo -e "${OK} ${GreenBG} The current system is Centos ${VERSION_ID} ${VERSION} ${Font}"
            INS="yum"
            qrencode -V &>/dev/null 
            if [[ ! 0 -eq $? ]]; then
                $INS update
                $INS install qrencode
                judge install
            fi
            cd $wg_dir
            read -e -p "请输入客户端文件名:" file_conf
            qrencode -t ansiutf8 < $file_conf
        elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
            echo -e "${OK} ${GreenBG} The current system is Debian ${VERSION_ID} ${VERSION} ${Font}"
            INS="apt"
            qrencode -V
            if [[ ! 0 -eq $? ]]; then
                $INS update
                $INS install qrencode
                judge install
            fi
            cd $wg_dir
            read -e -p "请输入客户端文件名:" file_conf
            qrencode -t ansiutf8 < $file_conf
        elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
            echo -e "${OK} ${GreenBG} The current system is Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
            INS="apt"
            qrencode -V
            if [[ ! 0 -eq $? ]]; then
                $INS update
                $INS install qrencode
                judge install
            fi
            cd $wg_dir
            read -e -p "请输入客户端文件名:" file_conf
            qrencode -t ansiutf8 < $file_conf
        elif [[ "${ID}" == "alpine" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 3 ]]; then 
            echo -e "${OK} ${GreenBG} The current system is alpine ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
            INS="apk"
            qrencode -V
            if [[ ! 0 -eq $? ]]; then
                $INS update
                $INS add libqrencode
                judge install
            fi
            cd $wg_dir
            read -e -p "请输入客户端文件名:" file_conf
            qrencode -t ansiutf8 < $file_conf
        else
            echo -e "${Error} ${RedBG} The current system is ${ID} ${VERSION_ID} is not in the list of supported systems, the installation is interrupted ${Font}"
            exit 1
    fi
}

#分流

filter_add(){
    echo -e "${GreenBG} 开始设置..... ${Font} \n"
    wget https://raw.githubusercontent.com/Learntotolearn/wg/main/cn.sh &>/dev/null && bash cn.sh  && rm -f cn.sh
    default_route=`ip route | grep default | awk '{print $3}'`
    ip route add default via $default_route table 5300
    if [[ 0 -eq $? ]]; then
        echo -e "${GreenBG} 设置成功..... ${Font} \n"
        else
        echo -e "${RedBG} 设置失败..... ${Font} \n"
    fi
    
}

filter_del(){
    echo -e "${GreenBG} 开始删除..... ${Font} \n"
    wget https://raw.githubusercontent.com/Learntotolearn/wg/main/cn_del.sh &>/dev/null && bash cn_del.sh  && rm -f cn_del.sh
    ip route del default table 5300
     if [[ 0 -eq $? ]]; then
        echo -e "${GreenBG} 删除成功..... ${Font} \n"
        else
        echo -e "${RedBG} 删除失败..... ${Font} \n"
    fi
}


#


start_menu(){

    echo "=============================================================================="
    echo " Welcome to AKA-World "
    echo " Info   :testing "
    echo " Author : BigW"
    echo " Vsersion : 1.0.3"
    echo "=============================================================================="
    echo " 1. 生成一对wireguard配置 "
    echo " 2. 输出客户端配置文件 "
    echo " 3. 输出客户端配置二维码 "
    echo " 4. 为指定wireguard添加用户"
    echo " 5. 添加分流规则"
    echo " 6. 删除分流规则"
    echo " 0. Exit"
    echo "=============================================================================="
    echo
    read -p "Please enter a number:" num
    case "$num" in
        1)
            pskey
            wg_server_conf
            wg_start_server
            ;;
        2)
            wg_client_show
            ;;
        3)
            qr
            ;;
        4)
            add_wg_client
            ;;
        5)  
            filter_add
            ;;
        6)
            filter_del
            ;;    
        0)
            exit 1
            ;;
        "exit")
            exit 1
            ;;  
        *)
            clear
            red "请输入正确的数字!(Please enter the correct number)"
            sleep 2s
            start_menu
            ;;
            esac
}

start_menu    
