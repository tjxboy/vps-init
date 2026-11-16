apt-get update && apt-get install -y curl ca-certificates && curl -fSL --retry 3 --connect-timeout 15 "https://raw.githubusercontent.com/tjxboy/vps-init/main/vps-init.sh" -o /root/vps-init.sh && bash -n /root/vps-init.sh && bash /root/vps-init.sh

curl -fsSL https://raw.githubusercontent.com/tjxboy/tailscale-tools/main/setup-tailscale-peer-relay.sh | sudo bash
安装 Tailscale。
启动 tailscaled。
加入现有 Tailnet。
设置 VPS 名称为 us-vps-relay。
配置 UDP 40000 作为 Peer Relay 端口。
输出 VPS 的 Tailscale IP 和运行状态。
