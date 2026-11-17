apt-get update && apt-get install -y curl ca-certificates && curl -fSL --retry 3 --connect-timeout 15 "https://raw.githubusercontent.com/tjxboy/vps-init/main/vps-init.sh" -o /root/vps-init.sh && bash -n /root/vps-init.sh && bash /root/vps-init.sh

curl -fsSL https://raw.githubusercontent.com/tjxboy/vps-init/main/setup-tailscale-peer-relay.sh | sudo bash

安装 Tailscale。

启动 tailscaled。

加入现有 Tailnet。

设置 VPS 名称为 us-vps-relay。

配置 UDP 40000 作为 Peer Relay 端口。

输出 VPS 的 Tailscale IP 和运行状态。



2. 配置 Tailscale Peer Relay 授权
这是目前另一个非常重要的缺失项。

打开：
Tailscale Access Controls选择 JSON Editor。

找到现有的 "grants" 数组，在数组中增加下面这条规则：

{
  "src": [
    "公司电脑的tailscale IP/32"
  ],
  "dst": [
    "VPS电脑的tailscale IP"
  ],
  "app": {
    "tailscale.com/cap/relay": []
  }
}



这条规则的含义：
参数	作用
src	允许家庭和公司电脑使用中继
dst	指定美国 VPS
cap/relay	授予 Peer Relay 使用权限

我把两个客户端都放进 src，这样无论从家里主动连接公司，还是从公司主动连接家里，都可以使用这台 VPS。

重要：不要用这段 JSON 替换整个现有 ACL / Grants 文件。 只把这个对象合并进现有的 grants 数组，保留其他规则。

Tailscale 官方明确要求使用 tailscale.com/cap/relay 授权，而且不需要另外给 Peer Relay 增加普通网络访问授权。
Tailscale Docs+1

三、配置完成后重新测试
先在家里电脑执行：
tailscale ping --c=10 公司电脑的tailscale IP

再执行：
tailscale status

预期看到类似：
active; peer-relay VPS的实际IP:40000:vni:...

这才表示真正使用了自己的美国 VPS。










# Tailscale Peer Relay 检查工具包

适用：Debian/Linux VPS；Windows 家庭/公司客户端；默认 Peer Relay UDP 端口 `40000`。

**所有脚本均为只读诊断工具**：不安装软件、不开放端口、不修改 Tailscale、不修改防火墙、不修改 Tailnet ACL/Grants。

## 文件

- `tailscale-peer-relay-server-check.sh`：在 VPS 上检查 Tailscale、服务、UDP 监听、主机防火墙工具/规则、网络接口和状态。
- `tailscale-peer-relay-client-check.ps1`：在 Windows 公司/家庭电脑上测试到另一台客户端的路径。
- `tailscale-peer-relay-client-check.sh`：Linux/macOS 客户端的同等检查。

## 1. 新 VPS 上检查

```bash
chmod +x tailscale-peer-relay-server-check.sh
sudo ./tailscale-peer-relay-server-check.sh 40000
```

或：

```bash
bash tailscale-peer-relay-server-check.sh 40000
```

如使用其他端口，把 `40000` 换成实际端口。

### VPS 检查能证明什么

- `ss` 显示 `0.0.0.0:40000` 或 `[::]:40000`：本机有 UDP 监听。
- UFW/nftables/iptables/firewalld 输出：帮助检查主机防火墙。
- `tailscale status`：显示 VPS 是否加入 Tailnet。

### VPS 检查不能证明什么

- 本机监听不等于 VMISS 公网边界/安全组已放行。
- 缺少 `nft`、`ufw` 等命令不等于绝对没有防火墙。
- VPS 本机不能单独证明 Tailnet ACL/Grants 已授权。
- VPS 本机不能单独证明公司与家里客户端正在使用该 Peer Relay。

VMISS 面板仍需人工检查 Firewall/Security Group，确认入站 UDP 40000 未被阻断。不要开放 TCP 40000。

## 2. Windows 公司电脑测试到家里电脑


## 3. Windows 家里电脑测试到公司电脑


## 4. Linux/macOS 客户端


## 5. 如何判读

以 `tailscale ping` 和 `tailscale status` 的实际输出为准：

- `peer-relay`：使用 Tailnet 中配置的 Peer Relay。
- `DERP(...)` 或 `relay "xxx"`：使用 Tailscale 公共 DERP。
- `direct` 或 `via 公网IP:端口`：两台客户端直接连接，没有使用中继。

Tailscale 可能先使用 DERP，随后切换连接路径。请保留完整输出，不要只看第一行。

如果没有出现 `peer-relay`，检查：
1. VPS 已配置 `tailscale set --relay-server-port=40000`，且本机正在监听 UDP 40000。
2. VMISS 面板入站 UDP 40000 已允许。
3. Tailnet ACL/Grants 已按官方 Peer Relay 文档添加授权，并包含需要使用中继的设备。
4. 公司和家庭客户端能访问 VPS 公网 UDP 40000。
5. VPS 和客户端版本符合当前官方 Peer Relay 要求。

## 6. 当前环境参考（脚本不写死这些值）


## 7. 安全

