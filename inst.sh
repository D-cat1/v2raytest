sleep 1


_red() { echo -e ${red}$*${none}; }
_green() { echo -e ${green}$*${none}; }
_yellow() { echo -e ${yellow}$*${none}; }
_magenta() { echo -e ${magenta}$*${none}; }
_cyan() { echo -e ${cyan}$*${none}; }

error() {
    echo -e "\n$red salah input! $none\n"
}

pause() {
    read -rsp "$(echo -e "Tekan $green Enter $none untuk melanjutkan....atau $red Ctrl + C $none untuk membatalkan.")" -d $'\n'
    echo
}

#wxplain
echo
echo -e "$yellow script hanya kompatibel dengan Debian 10+ jika bukan itu keluar$none"
echo "Skrip ini mendukung eksekusi dengan parameter. Masukkan nama domain, tumpukan jaringan, UUID, jalur di parameter. Lihat GitHub untuk detailnya."
echo "----------------------------------------------------------------"

# Jalankan skrip dengan parameter
if [ $# -ge 1 ]; then

    # domain
    domain=${1}

    # Apakah parameter kedua disetel pada ipv4 atau ipv6
    case ${2} in
    4)
        netstack=4
        ;;
    6)
        netstack=6
        ;;    
    *) # initial
        netstack="i"
        ;;    
    esac

    #Parameter ketiga adalah UUID
    v2ray_id=${3}
    if [[ -z $v2ray_id ]]; then
        v2ray_id=$(cat /proc/sys/kernel/random/uuid)
    fi
        
    v2ray_port=$(shuf -i20001-65535 -n1)

    #Parameter keempat adalah jalur
    path=${4}
    if [[ -z $path ]]; then 
        path=$(echo $v2ray_id | sed 's/.*\([a-z0-9]\{12\}\)$/\1/g')
    fi

    proxy_site="https://dcat.my.id"

    echo -e "domain: ${domain}"
    echo -e "netstack: ${netstack}"
    echo -e "v2ray_id: ${v2ray_id}"
    echo -e "v2ray_port: ${v2ray_port}"
    echo -e "path: ${path}"
    echo -e "proxy_site: ${proxy_site}"
fi

pause

# Persiapan
apt update
apt install -y curl sudo jq qrencode

# Tentukan untuk menginstal versi V2ray v4.45.2
echo
echo -e "$yellow menginstall V2ray v4.45.2$none"
echo "----------------------------------------------------------------"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --version 4.45.2

systemctl enable v2ray

# Instal Caddy versi terbaru
echo
echo -e "$yellow Instal Caddy versi terbaru$none"
echo "----------------------------------------------------------------"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

systemctl enable caddy

echo
echo -e "$yellow Buka BBR$none"
echo "----------------------------------------------------------------"
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1
echo

# Untuk mengonfigurasi mode VLESS_WebSocket_TLS, Anda memerlukan: nama domain, jalur pengalihan, situs web anti-generasi, port internal V2ray, UUID
echo
echo -e "$yellow Konfigurasikan mode VLESS_WebSocket_TLS$none"
echo "----------------------------------------------------------------"

# UUID
if [[ -z $v2ray_id ]]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
    while :; do
        echo -e "masukkan "$yellow"V2RayID"$none" "
        read -p "$(echo -e "(ID default: ${cyan}${uuid}$none):")" v2ray_id
        [ -z "$v2ray_id" ] && v2ray_id=$uuid
        case $(echo $v2ray_id | sed 's/[a-z0-9]\{8\}-[a-z0-9]\{4\}-[a-z0-9]\{4\}-[a-z0-9]\{4\}-[a-z0-9]\{12\}//g') in
        "")
            echo
            echo
            echo -e "$yellow V2Ray ID = $cyan$v2ray_id$none"
            echo "----------------------------------------------------------------"
            echo
            break
            ;;
        *)
            error
            ;;
        esac
    done
fi

# port internal V2ray
if [[ -z $v2ray_port ]]; then
    random=$(shuf -i20001-65535 -n1)
    while :; do
        echo -e "masukkan "$yellow"V2Ray"$none" port ["$magenta"1-65535"$none"], tidak bisa memilih "$magenta"80"$none" atau "$magenta"443"$none" port"
        read -p "$(echo -e "(default port: ${cyan}${random}$none):")" v2ray_port
        [ -z "$v2ray_port" ] && v2ray_port=$random
        case $v2ray_port in
        80)
            echo
            echo " ...port 80 tidak dapat dipilih....."
            error
            ;;
        443)
            echo
            echo " ..port 443 tidak dapat dipilih....."
            error
            ;;
        [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-5][0-9][0-9][0-9][0-9] | 6[0-4][0-9][0-9][0-9] | 65[0-4][0-9][0-9] | 655[0-3][0-5])
            echo
            echo
            echo -e "$yellow Port V2Ray internal Port internal = $cyan$v2ray_port$none"
            echo "----------------------------------------------------------------"
            echo
            break
            ;;
        *)
            error
            ;;
        esac
    done
fi

# domain
if [[ -z $domain ]]; then
    while :; do
        echo
        echo -e "masukkan ${magenta}domain${none}"
        read -p "(contoh: mydomain.com): " domain
        [ -z "$domain" ] && error && continue
        echo
        echo
        echo -e "$yellow Nama domain Anda = $cyan$domain$none"
        echo "----------------------------------------------------------------"
        break
    done
fi

# jaringan yang dipakai
if [[ -z $netstack ]]; then
    echo -e "jika vps anda${magenta}dual stack punya ipv4 & ipv6${none}，silahkan pilih salah satu"
    echo "jika tidak mengerti langsung enter saja"
    read -p "$(echo -e "Input ${cyan}4${none} for IPv4, ${cyan}6${none} for IPv6:") " netstack
    if [[ $netstack == "4" ]]; then
        domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=A" | jq -r '.Answer[0].data')
    elif [[ $netstack == "6" ]]; then 
        domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=AAAA" | jq -r '.Answer[0].data')
    else
        domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=A" | jq -r '.Answer[0].data')
        if [[ "$domain_resolve" != "null" ]]; then
            netstack="4"
        else
            domain_resolve=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=AAAA" | jq -r '.Answer[0].data')            
            if [[ "$domain_resolve" != "null" ]]; then
                netstack="6"
            fi
        fi
    fi

    # local IP
    if [[ $netstack == "4" ]]; then
        ip=$(curl -4 -s https://api.myip.la)
    elif [[ $netstack == "6" ]]; then 
        ip=$(curl -6 -s https://api.myip.la)
    else
        ip=$(curl -s https://api.myip.la)
    fi

    if [[ $domain_resolve != $ip ]]; then
        echo
        echo -e "$red Domain resolution error....$none"
        echo
        echo -e " domain: $yellow$domain$none tidak sama dengan ip: $cyan$ip$none"
        echo
        if [[ $domain_resolve != "null" ]]; then
            echo -e " Your domain name currently resolves to: $cyan$domain_resolve$none"
        else
            echo -e " $redDomain not resolved $none "
        fi
        echo
        echo "Notice...If you use Cloudflare to resolve your domain, on 'DNS' setting page, 'Proxy status' should be 'DNS only' but not 'Proxied'."
        echo
        exit 1
    else
        echo
        echo
        echo -e "$yellow DNS = ${cyan}sudah teratasi$none"
        echo "----------------------------------------------------------------"
        echo
    fi
fi

# path
if [[ -z $path ]]; then
    default_path=$(echo $v2ray_id | sed 's/.*\([a-z0-9]\{12\}\)$/\1/g')
    while :; do
        echo -e "tentukan ${magenta} path $none , misal /v2raypath ,tuliskan nama path nya saja 'v2raypath'"
        echo "Input the WebSocket path for V2ray"
        read -p "$(echo -e "(default path: [${cyan}${default_path}$none]):")" path
        [[ -z $path ]] && path=$default_path

        case $path in
        *[/$]*)
            echo
            echo -e "tidak dapat diisi simbol $ dan /"
            echo
            error
            ;;
        *)
            echo
            echo
            echo -e "$yellow Path = ${cyan}/${path}$none"
            echo "----------------------------------------------------------------"
            echo
            break
            ;;
        esac
    done
fi

# Situs Web Kamuflase Anti-Generasi
if [[ -z $proxy_site ]]; then
    while :; do
        echo "Input a camouflage site. When GFW visit your domain, the camouflage site will display."
        read -p "$(echo -e "(default site: [${cyan}https://dcat.my.id/${none}]):")" proxy_site
        [[ -z $proxy_site ]] && proxy_site="https://dcat.my.id/"

        case $proxy_site in
        *[#$]*)
            echo
            echo -e " url tidak boleh mengandung simbol # atau $ "
            echo
            error
            ;;
        *)
            echo
            echo
            echo -e "$yellow situs redirect = ${cyan}${proxy_site}$none"
            echo "----------------------------------------------------------------"
            echo
            break
            ;;
        esac
    done
fi

# konfigurasi /usr/local/etc/v2ray/config.json
echo
echo -e "$yellow konfigurasi /usr/local/etc/v2ray/config.json$none"
echo "----------------------------------------------------------------"
cat >/usr/local/etc/v2ray/config.json <<-EOF
{ // vless + WebSocket + TLS
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": $v2ray_port,             // ***
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$v2ray_id",             // ***
                        "level": 1,
                        "alterId": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws"
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        },
        // [inbound] Jika Anda mengomentari paragraf berikut, komentari juga koma bahasa Inggris di akhir baris di atas
        {
            "listen":"127.0.0.1",
            "port":1080,
            "protocol":"socks",
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls"
                ]
            },
            "settings":{
                "auth":"noauth",
                "udp":false
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIP"
            },
            "tag": "direct"
        },
        // [outbound]
{
    "protocol": "freedom",
    "settings": {
        "domainStrategy": "UseIPv4"
    },
    "tag": "force-ipv4"
},
{
    "protocol": "freedom",
    "settings": {
        "domainStrategy": "UseIPv6"
    },
    "tag": "force-ipv6"
},
{
    "protocol": "socks",
    "settings": {
        "servers": [{
            "address": "127.0.0.1",
            "port": 40000 //warp socks5 port
        }]
     },
    "tag": "socks5-warp"
},
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ],
    "dns": {
        "servers": [
            "8.8.8.8",
            "1.1.1.1",
            "2001:4860:4860::8888",
            "2606:4700:4700::1111",
            "localhost"
        ]
    },
    "routing": {
        "domainStrategy": "IPOnDemand",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "100.64.0.0/10",
                    "127.0.0.0/8",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.0.0.0/24",
                    "192.0.2.0/24",
                    "192.168.0.0/16",
                    "198.18.0.0/15",
                    "198.51.100.0/24",
                    "203.0.113.0/24",
                    "::1/128",
                    "fc00::/7",
                    "fe80::/10"
                ],
                "outboundTag": "blocked"
            },
            // [routing-rule]
//{
//     "type": "field",
//     "domain": ["geosite:google"],  // ***
//     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp
//},
{
     "type": "field",
     "domain": ["geosite:id"],  // ***
     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
},
{
     "type": "field",
     "ip": ["geoip:cn"],  // ***
     "outboundTag": "force-ipv6"  // force-ipv6 // force-ipv4 // socks5-warp // blocked
},
            {
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "blocked"
            }
        ]
    }
}
EOF

# konfigurasi /etc/caddy/Caddyfile
echo
echo -e "$yellow config /etc/caddy/Caddyfile$none"
echo "----------------------------------------------------------------"
cat >/etc/caddy/Caddyfile <<-EOF
$domain
{
    tls divagiania@gmail.com
    encode gzip

#    multiuser path
    import Caddyfile.multiuser

    handle_path /$path {
        reverse_proxy localhost:$v2ray_port
    }
    handle {
        reverse_proxy $proxy_site {
            trusted_proxies 0.0.0.0/0
            header_up Host {upstream_hostport}
        }
    }
}
EOF

# path
multiuser_path=""
user_number=10
while [ $user_number -gt 0 ]; do
    random_path=$(cat /proc/sys/kernel/random/uuid | sed 's/.*\([a-z0-9]\{4\}-[a-z0-9]\{12\}\)$/\1/g')

    multiuser_path=${multiuser_path}"path /"${random_path}$'\n'

    user_number=$(($user_number - 1))
done

cat >/etc/caddy/Caddyfile.multiuser <<-EOF
@ws_path {
$multiuser_path
}

handle @ws_path {
    uri path_regexp /.* /
    reverse_proxy localhost:$v2ray_port
}
EOF

# reboot V2Ray
echo
echo -e "$yellow reboot V2Ray$none"
echo "----------------------------------------------------------------"
service v2ray restart

# reboot CaddyV2
echo
echo -e "$yellow reboot CaddyV2$none"
echo "----------------------------------------------------------------"
service caddy restart

echo
echo
echo "---------- V2Ray INFO -------------"
echo -e "$green ---Hint.. this is the VLESS server configuration--- $none"
echo -e "$yellow (Address) = $cyan${domain}$none"
echo -e "$yellow (Port) = ${cyan}443${none}"
echo -e "$yellow (User ID / UUID) = $cyan${v2ray_id}$none"
echo -e "$yellow (Encryption) = ${cyan}none${none}"
echo -e "$yellow (Network) = ${cyan}ws$none"
echo -e "$yellow (header type) = ${cyan}none$none"
echo -e "$yellow (host) = ${cyan}${domain}$none"
echo -e "$yellow (path) = ${cyan}/${path}$none"
echo -e "$yellow (TLS) = ${cyan}tls$none"
echo
echo "---------- V2Ray VLESS URL ----------"
v2ray_vless_url="vless://${v2ray_id}@${domain}:443?encryption=none&security=tls&type=ws&host=${domain}&path=${path}#VLESS_WSS_${domain}"
echo -e "${cyan}${v2ray_vless_url}${none}"
echo
sleep 3
echo "The following two QR codes have exactly the same content"
qrencode -t UTF8 $v2ray_vless_url
qrencode -t ANSI $v2ray_vless_url
echo
echo "---------- END -------------"
echo "The above node information is saved in ~/_v2ray_vless_url_"

# save
echo $v2ray_vless_url > ~/_v2ray_vless_url_
echo "The following two QR codes have exactly the same content" >> ~/_v2ray_vless_url_
qrencode -t UTF8 $v2ray_vless_url >> ~/_v2ray_vless_url_
qrencode -t ANSI $v2ray_vless_url >> ~/_v2ray_vless_url_

# Apakah akan beralih ke protokol vmess
echo 
echo -e "Switch to ${magenta}Vmess${none} protocol?"
echo "tenak ENTER jika tidak"
read -p "$(echo -e "(${cyan}y/N${none} Default No):") " switchVmess
if [[ -z "$switchVmess" ]]; then
    switchVmess='N'
fi
if [[ "$switchVmess" == [yY] ]]; then
    # config.json Di dalam file, ganti vless dengan vmess
    sed -i "s/vless/vmess/g" /usr/local/etc/v2ray/config.json
    service v2ray restart
    
    #Hasilkan tautan vmess dan kode QR
    echo "---------- V2Ray Vmess URL ----------"
    v2ray_vmess_url="vmess://$(echo -n "\
{\
\"v\": \"2\",\
\"ps\": \"Vmess_WSS_${domain}\",\
\"add\": \"${domain}\",\
\"port\": \"443\",\
\"id\": \"${v2ray_id}\",\
\"aid\": \"0\",\
\"net\": \"ws\",\
\"type\": \"none\",\
\"host\": \"${domain}\",\
\"path\": \"${path}\",\
\"tls\": \"tls\"\
}"\
    | base64 -w 0)"

    echo -e "${cyan}${v2ray_vmess_url}${none}"
    echo "qr code"
    qrencode -t UTF8 $v2ray_vmess_url
    qrencode -t ANSI $v2ray_vmess_url

    echo
    echo "---------- END -------------"
    echo "Informasi simpul di atas disimpan di ~/_v2ray_vmess_url_"

    echo $v2ray_vmess_url > ~/_v2ray_vmess_url_
    echo "VMESS QR" >> ~/_v2ray_vmess_url_
    qrencode -t UTF8 $v2ray_vmess_url >> ~/_v2ray_vmess_url_
    qrencode -t ANSI $v2ray_vmess_url >> ~/_v2ray_vmess_url_
    
elif [[ "$switchVmess" == [nN] ]]; then
    echo
else
    error
fi

# hanya untuk ipv6
if [[ $netstack == "6" ]]; then
    echo
    echo -e "$yellowcreate ipv4 with warp$none"
    echo "app seperti telegram membutuhkan ipv4"
    echo "----------------------------------------------------------------"
    pause

    # install WARP IPv4
    bash <(curl -L git.io/warp.sh) 4

    #  V2Ray
    echo
    echo -e "$yellow restart V2Ray$none"
    echo "----------------------------------------------------------------"
    service v2ray restart

    #  CaddyV2
    echo
    echo -e "$yellow restart CaddyV2$none"
    echo "----------------------------------------------------------------"
    service caddy restart
fi
