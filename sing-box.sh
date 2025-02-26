#!/bin/bash

# 预设所有交互选项
AUTO_ENTER=""
AUTO_A="a"
AUTO_N="n"
AUTO_Y="y"
AUTO_PORT="12345"
AUTO_ENTER2=""
AUTO_NETWORK="1"  # 1表示TCP
AUTO_SNI="21221"
AUTO_ENTER3=""
AUTO_ENTER4=""
AUTO_ENTER5=""
AUTO_ENTER6=""

SING_BOX_PATH="/etc/sing-box/"
SHARE_LINK=""
SERVICE_FILE_PATH='/etc/systemd/system/sing-box.service'
IP=`curl ip.sb`
[ -z `echo ${IP}|grep ":"`  ] || IP="["${IP}"]"

#System check
os_check() {
    echo -e "\n检测当前系统中...\n"
    if [[ -f /etc/redhat-release ]]; then
        OS_RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "Alpine"; then
        OS_RELEASE="alpine"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    else
        echo -e "\n系统检测错误,请联系脚本作者!" && exit 1
    fi
    echo -e "\n系统检测完毕,当前系统为:${OS_RELEASE}\n"
}

#arch check
arch_check() {
    echo -e "\n检测当前系统架构中...\n"
    OS_ARCH=$(arch)
    echo -e "\n当前系统架构为 ${OS_ARCH}\n"

    if [[ ${OS_ARCH} == "x86_64" || ${OS_ARCH} == "x64" || ${OS_ARCH} == "amd64" ]]; then
        OS_ARCH="amd64"
    elif [[ ${OS_ARCH} == "aarch64" || ${OS_ARCH} == "arm64" ]]; then
        OS_ARCH="arm64"
    else
        OS_ARCH="amd64"
        echo -e "\n检测系统架构失败，使用默认架构: ${OS_ARCH}\n"
    fi
    echo -e "\n系统架构检测完毕,当前系统架构为:${OS_ARCH}\n"
}

#install some common utils
install_base() {
    if [[ ${OS_RELEASE} == "ubuntu" || ${OS_RELEASE} == "debian" ]]; then
        apt install wget tar jq -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar jq -y
    elif [[ ${OS_RELEASE} == "alpine" ]]; then
        apk update && apk add wget tar jq openssl
    fi
}

#download sing-box binary
download_sing_box() {
    echo -e "\n开始下载sing-box...\n"
    os_check && arch_check && install_base
    local SING_BOX_VERSION_TEMP=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | sed 'y/,/\n/' | grep 'tag_name' | awk -F '"' '{print $4}')
    [ -z "${SING_BOX_VERSION_TEMP}" ] && SING_BOX_VERSION_TEMP="v1.8.0"
    
    # 使用自动输入替代交互
    echo "自定义版本号:${AUTO_ENTER}"
    local custom_version="${AUTO_ENTER}"
    
    [ -z ${custom_version} ] || SING_BOX_VERSION_TEMP="v"$custom_version
    SING_BOX_VERSION=${SING_BOX_VERSION_TEMP:1}
    echo -e "\n将选择使用版本:${SING_BOX_VERSION}\n"
    local DOWANLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${SING_BOX_VERSION_TEMP}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz"

    #here we need create directory for sing-box
    [[ -f ${SING_BOX_PATH}/config.json ]] && mv ${SING_BOX_PATH}/config.json /etc/sb.bak.config.json
    [[ -d ${SING_BOX_PATH} ]] && rm ${SING_BOX_PATH}/sing-box -f || mkdir ${SING_BOX_PATH}
    cd ${SING_BOX_PATH}
    wget -N --no-check-certificate -O sb.tar.gz ${DOWANLOAD_URL}
    tar -xvf sb.tar.gz
    rm sb.tar.gz && mv sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}/* .
    rm -rf sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH} LICENSE
    if [[ $? -ne 0 ]]; then
        echo -e "\nDownload sing-box failed,plz be sure that your network work properly and can access github"
        exit 1
    else
        echo -e "\n下载sing-box成功"
    fi
    [[ -f /etc/sb.bak.config.json ]] && cp /etc/sb.bak.config.json ${SING_BOX_PATH}/config.json
}

download_sing_box

if [[ -f /etc/sb.bak.config.json ]];then
    rm /etc/sb.bak.config.json
    echo -e "升级完成,如需重新配置请自行备份并移除 ${SING_BOX_PATH}/config.json"
    service sing-box restart
    exit
fi

reality_inbound() {
    # 使用预设的网络模式选择
    network_mode=""
    echo -e "\n❗gRPC/H2 建议在有大陆优化的VPS上使用。并且VPS所在的地区距离你的位置越近越好。即使你的VPS满足以上条件，仍然不能避免断流现象。\n"
    echo "1.TCP 2.H2 3.GRPC 请键入相应数字选择传输协议:${AUTO_NETWORK}"
    networkmode="${AUTO_NETWORK}"
    
    case ${networkmode} in
        1)
          network_mode="tcp"
          echo "TCP";;
        2)
          network_mode="http"
          echo "H2";;
        3)
          network_mode="grpc"
          echo "GRPC";;
        *)
          network_mode="tcp"
          echo "默认选择TCP";;
    esac
    
    cat >>config.json<<EOF
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": PORT,
	    "multiplex": {
		"enabled": true,
		"padding": true,
                "brutal": {
		    "enabled": true,
                    "up_mbps": 1000,
                    "down_mbps": 1000
                }
	    },
     	    "tcp_multi_path": true,
            "users": [
                {
                    "uuid": "UUID",
                    "flow": "USERFLOW"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "CUSDEST",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "CUSDEST",
                        "server_port": 443
                    },
                    "private_key": "PRIKEY",
                    "short_id": [
                        "SID",
                        ""
                    ]
                }
            }
EOF

    # 使用预设的端口
    echo "输入监听端口(0~65535):${AUTO_PORT}"
    Port="${AUTO_PORT}"
    [ -z ${Port} ] && Port=443

    # 自动生成UUID
    echo "自定义UUID(不需要就直接回车):${AUTO_ENTER2}"
    UUID="${AUTO_ENTER2}"
    [ -z ${UUID} ] && UUID=`./sing-box generate uuid`

    # 自动生成ShortID
    echo "自定义ShortID(不需要就直接回车):${AUTO_ENTER3}"
    SID="${AUTO_ENTER3}"
    [ -z ${SID} ] && SID=`openssl rand -hex 8`

    # 使用预设的SNI
    echo "自定义SNI(不需要就直接回车):${AUTO_SNI}"
    SNI="${AUTO_SNI}"
    [ -z ${SNI} ] && SNI="jetpack.com"

    # 自动生成私钥
    echo "自定义私钥(不需要就直接回车):${AUTO_ENTER4}"
    PIK="${AUTO_ENTER4}"
    if [[ -z ${PIK} ]];then
        KEYS=`./sing-box generate reality-keypair`
        PIK=$(echo -e $KEYS | awk -F ' ' '{print $2}')
        PBK=$(echo -e $KEYS | awk -F ' ' '{print $4}')
        echo "私钥:"${PIK} > ${SING_BOX_PATH}keys.txt
        echo "公钥:"${PBK} >> ${SING_BOX_PATH}keys.txt 
    fi

    sed -i 's/PORT/'${Port}'/g' ./config.json
    sed -i 's/UUID/'${UUID}'/g' ./config.json
    sed -i 's/SID/'${SID}'/g' ./config.json
    sed -i 's/CUSDEST/'${SNI}'/g' ./config.json
    sed -i 's/PRIKEY/'${PIK}'/g' ./config.json
    local USERFLOW=""
    [ "${network_mode}" == "tcp" ] && USERFLOW="xtls-rprx-vision"
    sed -i 's/USERFLOW/'${USERFLOW}'/g' ./config.json
    if [[ "${network_mode}" != "tcp" ]];then
            cat >>config.json<<EOF
,
            "transport": {
                "type": "${network_mode}"
EOF
            if [[ "${network_mode}" == "grpc" ]];then
              cat >>config.json<<EOF
,
                "service_name": "grpc"
EOF
            fi
    fi
    cat >>config.json<<EOF

            }
EOF
    if [[ "${network_mode}" != "tcp" ]];then
    cat >>config.json<<EOF
        }
EOF
    fi
    SHARE_LINK=${SHARE_LINK}"\nReality: vless://"${UUID}"@"${IP}":"${Port}"?security=reality&encryption=none&pbk="${PBK}"&headerType=none&fp=chrome&spx=%2F&serviceName=grpc&type="${network_mode}"&sni="${SNI}"&sid="${SID}"&flow="${USERFLOW}"#Reality"
}

vless_tcp_inbound() {
    # 使用预设的端口
    echo "输入监听端口(0~65535):${AUTO_ENTER5}"
    Port="${AUTO_ENTER5}"
    [ -z ${Port} ] && Port=1443
    
    # 自动生成UUID
    echo "输入UUID(直接回车则随机生成):${AUTO_ENTER6}"
    UUID="${AUTO_ENTER6}"
    [ -z ${UUID} ] && UUID=`./sing-box generate uuid`
    
    cat >>config.json<<EOF
        {
            "type": "vless",
            "tag": "vless-tcp-in",
            "listen": "::",
            "listen_port": ${Port},
            "multiplex": {
                "enabled": true,
                "padding": true,
                "brutal": {
                    "enabled": true,
                    "up_mbps": 1000,
                    "down_mbps": 1000
                }
            },
            "tcp_multi_path": true,
            "users": [
                {
                    "name": "nh",
                    "uuid": "${UUID}",
                    "flow": ""
                }
            ]
        }
EOF
    SHARE_LINK=${SHARE_LINK}"\nVless+TCP: vless://${UUID}@${IP}:${Port}?security=none&&encryption=none&headerType=none&type=tcp#VlessTCP"
}

ss_inbound() {
    # 使用预设的端口
    echo "输入监听端口(0~65535):${AUTO_ENTER5}"
    Port="${AUTO_ENTER5}"
    [ -z ${Port} ] && Port=2443
    
    # 自动生成密码
    echo "输入密码(直接回车随机生成):${AUTO_ENTER6}"
    Passwd="${AUTO_ENTER6}"
    [ -z ${Passwd} ] && Passwd=`openssl rand -base64 32`
    
    local method=$([[ ! -z `cat /proc/cpuinfo|grep aes` ]]&& echo "2022-blake3-aes-256-gcm" || echo "2022-blake3-chacha20-poly1305")
    cat >>config.json<<EOF
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": ${Port},
	        "multiplex": {
		        "enabled": true,
		        "padding": true,
                        "brutal": {
                            "enabled": true,
                            "up_mbps": 1000,
                            "down_mbps": 1000
                        }
	        },
     	    "tcp_multi_path": true,
            "method": "${method}",
            "password": "${Passwd}"
        }
EOF
    local ss_encode=`echo -n $method:$Passwd|base64 | tr -d '\n'`
    SHARE_LINK=${SHARE_LINK}"\nShadowsocks密码: ${Passwd}\nShadowsocks: ss://${ss_encode}@${IP}:${Port}#SS"
}

ss_vless_inbound() {
    # 使用预设选项
    echo "使用Shadowsocks? (y/N) ${AUTO_Y}"
    useSS="${AUTO_Y}"
    [[ ${useSS} =~ ^[yY]$ ]] && ss_inbound
    
    echo "使用Vless+TCP？(y/N) ${AUTO_N}"
    useVlessTCP="${AUTO_N}"
    if [[ ${useSS} =~ ^[yY]$ && ${useVlessTCP} =~ ^[yY]$ ]];then
        echo "," >> config.json
    fi
    [[ ${useVlessTCP} =~ ^[yY]$ ]] && vless_tcp_inbound
    [[ -z ${SHARE_LINK} ]] && (echo "至少需要选择一种协议!" && exit 1)
}

make_config() {
    cd ${SING_BOX_PATH}
    echo "" > config.json
    echo "">sing-box.log
    cat >> config.json <<EOF
{
    "log": {
        "disabled": true
    },
    "inbounds": [
EOF
      # 使用预设选项
      echo "搭建Vless-Reality?[y/N/a](默认采用Shadowsocks或vless+tcp,键入a追加搭建vless+reality) ${AUTO_A}"
      is_reality="${AUTO_A}"
      
      case ${is_reality} in
          a|A)
              echo -e "配置Shadowsocks/Vless+TCP:\n"
              ss_vless_inbound;
	          echo "," >> config.json
              echo -e "配置Vless+Reality:\n"
              reality_inbound
	          ;;
          y|Y)
              reality_inbound
              ;;
          *)
              ss_vless_inbound
              ;;
      esac
      cat >> config.json <<EOF
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct",
	    "domain_strategy": "prefer_ipv4"
        }
    ],
    "route": { 
        "auto_detect_interface": true
    }
}
EOF
}

make_config

#install systemd service
install_systemd_service() {
    echo -e "开始安装sing-box systemd服务..."
    [ ${OS_RELEASE} == "alpine" ] && SERVICE_FILE_PATH="/etc/init.d/sing-box"
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        rm -rf ${SERVICE_FILE_PATH}
    fi
    #create service file
    touch ${SERVICE_FILE_PATH}
    if [ $? -ne 0 ]; then
        echo -e "create service file failed,exit"
        exit 1
    else
        echo -e "create service file success..."
    fi
    if [[ ${OS_RELEASE} == "alpine" ]];then
            cat >${SERVICE_FILE_PATH} <<EOF
#!/sbin/openrc-run

name="sing-box"
description="Sing-Box Service"
supervisor="supervise-daemon"
command="${SING_BOX_PATH}sing-box run"
command_args="-c ${SING_BOX_PATH}config.json"
command_user="root:root"

depend() {
	after net dns
	use net
}
EOF
      chmod +x ${SERVICE_FILE_PATH}
      rc-update add sing-box
      service sing-box start
    else
      cat >${SERVICE_FILE_PATH} <<EOF
[Unit]
Description=sing-box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target
Wants=network.target
[Service]
Type=simple
ExecStart=${SING_BOX_PATH}sing-box run -c ${SING_BOX_PATH}config.json
Restart=on-failure
RestartSec=30s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    chmod +x ${SERVICE_FILE_PATH}
    [[ ! -d /etc/systemd/system/sing-box.service.d ]] && mkdir /etc/systemd/system/sing-box.service.d
    echo '[Service]
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99' > /etc/systemd/system/sing-box.service.d/priority.conf
    systemctl daemon-reload
    systemctl enable sing-box 
    fi
    service sing-box start
    echo -e "安装sing-box systemd服务成功"
}

install_systemd_service

echo -e "${SHARE_LINK}" > ${SING_BOX_PATH}/share.txt

sysctl -w net.ipv4.tcp_fastopen=3

echo -e "
sing-box可执行文件与目录均位于:${SING_BOX_PATH}
如需卸载只需要执行删除sing-box服务和 ${SING_BOX_PATH} 文件夹
默认优先使用ipv6，可修改config中directc outbound的domain_strategy配置项进行调整
分享链接:${SHARE_LINK}

如需使用mux多路复用：如使用vision流控请先删除流控,推荐使用h2mux"
