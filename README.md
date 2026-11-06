[README.md](https://github.com/user-attachments/files/34500174/README.md)
# cloudflared-asus-rt-ac68u
在 ASUS RT-AC68U 上安装 Cloudflared(Cloudflare Tunnel)
# Cloudflare Tunnel 内网穿透 —— 完整资料集

> 目标:没有公网 IP,也能从外网安全访问家里的路由器、NAS 等任何联网设备。
> 方案:Cloudflare Tunnel(cloudflared)内网穿透。
> 提示:文中示例域名、IP、账号均为占位,请替换为你自己的实际值。

---

## 目录

| 文档 | 内容 |
|------|------|
| 01-在ASUS-RT-AC68U上安装Cloudflared.md | 华硕路由器安装 cloudflared 完整步骤(例程)|
| 02-Cloudflare-Access登录保护.md | 给发布网址加登录保护(仅自己可访问)|
| 03-各设备接入思路.md | NAS/路由器/树莓派/Windows 等通用接入方法论 |
| 04-Cloudflare-API自动配置Access.md | 用 API/脚本(非 GUI)自动加 Access 保护 |
| 代码/ | 可直接使用的脚本(安装、自启、重启、Access 配置)|

---

## 关键信息速查(示例)

### 设备
| 项 | 值(示例)|
|----|---------|
| 路由器 | ASUS RT-AC68U |
| 固件 | 3.0.0.4_386.14_2(梅林-KoolShare)|
| 架构 | armv7l(32位)|
| 内网 IP | 192.168.1.1 |
| Web 后台 | http://192.168.1.1:80 / https 8443 |
| 内存 | 256MB |

### 隧道
| 项 | 值(示例)|
|----|---------|
| 访问域名 | router.你的域名.com |
| 目标服务 | 192.168.1.1:80(HTTP)|
| cloudflared 路径 | /jffs/cloudflared |
| token 文件 | /jffs/cloudflared-token |
| 日志 | /jffs/cloudflared.log |

### SSH 登录
| 项 | 值 |
|----|----|
| 账号 | 路由器登录账号 |
| 密码 | 路由器登录密码 |
| 命令 | ssh 账号@192.168.1.1 |

---

## 常用命令速查

```sh
# SSH 登录设备
ssh 你的账号@192.168.1.1

# 看 cloudflared 状态
pidof cloudflared

# 看连接日志
tail -20 /jffs/cloudflared.log

# 重启 cloudflared(用整理的脚本)
sh /jffs/cloudflared-restart.sh
```

---

## 文件清单(lia/代码)

| 文件 | 用途 |
|------|------|
| install-cloudflared.sh | 一键下载安装 cloudflared + 写 token + 测试 |
| services-start.sh | 开机自启启动块(追加到 /jffs/scripts/services-start)|
| cloudflared-restart.sh | 启停/重启/状态 运维脚本 |
| setup-access.sh | 用 Cloudflare API 自动创建 Access 应用和策略 |

---

## 使用流程(零成本实现远程访问)

> 整套方案用**免费域名 + 免费服务,0 成本**。免费域名可找一个**能托管到 Cloudflare** 的:① 免费顶级域名注册商(DNS解析 改到 CF);② 免费二级域名服务。详见 01 篇"前置条件"。

1. 确认设备架构 → 下载对应 cloudflared(第 1 篇)
2. Cloudflare 后台建 Tunnel → 拿 token → 写入设备
3. 开机自启(第 1 篇 / 代码)
4. Cloudflare 后台加公共主机名 → 指向设备内网地址
5. 加 Cloudflare Access 保护(第 2 篇)
6. 从外网访问 https://你的域名 完成

---

## 遇到问题的思路

1. 先看日志:`tail -20 /jffs/cloudflared.log`
2. 对照第 3 篇"故障排查速查"
3. 确认 Cloudflare 后台隧道状态 Healthy
4. 确认 Access Policy 已生效

---
# 在 ASUS RT-AC68U 上安装 Cloudflared(Cloudflare Tunnel)

> 目的:让没有公网 IP 的家庭路由器/内网设备,通过 Cloudflare 隧道从外网安全访问。
> 本文以 **ASUS RT-AC68U(华硕路由器)** 为例,思路可推广到 NAS、软路由、树莓派等任何能装 Linux 二进制的联网设备。
> 提示:文中示例域名、IP、账号均为占位,请替换为你自己的实际值。

---

## 一、方案思路(先理解再动手)

### 1. 为什么用 Cloudflare Tunnel?
- 家里宽带**没有公网 IP** → 无法直接做端口映射从外网访问
- Cloudflare Tunnel 的客户端 **cloudflared** 主动向外连到 Cloudflare 边缘节点,**不需要开任何入站端口**
- 别人从外网通过你的域名访问 → Cloudflare 边缘 → 隧道 → 你的内网设备

```
外网设备 ──> 你的域名(router.你的域名.com)
                    │
              Cloudflare 边缘节点
                    │  (出站隧道, 由 cloudflared 主动建立)
              你的路由器/NAS(内网 192.168.1.1)
```

### 2. 前置条件
| 条件 | 说明 |
|------|------|
| Cloudflare 账户 | https://dash.cloudflare.com 免费注册 |
| 一个托管在 Cloudflare 的域名 | 可自行寻找能托管到 Cloudflare 的**免费域名**(见下) |
| 目标设备可联网 | 路由器/NAS 能正常上网 |
| 能进入设备的 shell | 路由器开 SSH / NAS 有终端 |

> **免费域名怎么来(0 成本方案):**
> 整套方案用**免费域名 + 免费服务**,无需花钱。可到以下渠道找一个**能托管到 Cloudflare** 的免费域名:
>
> - **渠道一**:提供免费顶级域名/免费域名的注册商(注册后可把域名的 DNS(NS)改到 Cloudflare 托管)。
> - **渠道二**:提供免费二级域名/子域名的服务(这类域名通常本身就支持改到 Cloudflare 或可直接在 Cloudflare 用)。
>
> 选域名的要点:**确认它能把权威 DNS 交给 Cloudflare 托管**(即能把域名 NS 记录指到 Cloudflare),这样才能用 Cloudflare Tunnel 发布你的设备。

---

## 二、本设备信息确认

在动手前,先确认目标设备的型号、固件、架构,这决定下载哪个 cloudflared 二进制。

**RT-AC68U 示例信息:**
- 型号:`RT-AC68U`
- 固件:`3.0.0.4_386.14_2`(ASUSWRT-Merlin-KoolShare)
- 内核:`2.6.36.4brcmarm`(32 位 ARM)
- 架构:`armv7l`(32 位)
- 内存:256MB
- 登录:Web 和 SSH 都用**路由器登录账号 + 密码**

> 判断架构:登录设备后执行 `uname -m`。`armv7l` 用 `cloudflared-linux-arm`;`aarch64` 用 `cloudflared-linux-arm64`;`x86_64` 用 `cloudflared-linux-amd64`。

---

## 三、完整安装步骤(带代码)

### 第 1 步:开启 SSH 并登录设备

RT-AC68U 需先开启 SSH:
- 后台 → **Administration → System → Service** → Enable SSH 选 **LAN only**
- 用**路由器登录账号 + 密码** SSH 登录即可(默认就是后台那个账号密码)

SSH 登录(用系统自带 OpenSSH 客户端):
```bash
ssh 你的账号@192.168.1.1
# 回车后输入路由器登录密码
```

### 第 2 步:确认 JFFS / 存储分区可写

cloudflared 需要持久化存放(否则重启丢失)。RT-AC68U 用 JFFS 分区:
```sh
df -h /jffs            # 查看剩余空间
# 示例:/jffs 总容量约 62.8M,cloudflared 约 37M,安装前请确保剩余空间足够
```

> 若空间不够,可插 USB 盘挂载到 `/tmp/mnt/xxx` 再存放。

### 第 3 步:下载 cloudflared 二进制

到设备上,用 wget/curl 下载对应架构的二进制并放到持久目录:
```sh
cd /jffs
wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm
chmod +x cloudflared
./cloudflared --version
# 输出示例: cloudflared version 2026.10.7 (built 2026-10-30)
```

### 第 4 步:在 Cloudflare 创建 Tunnel 并获取 Token

1. 登录 **https://one.dash.cloudflare.com**
2. **Networks → Tunnels → Create a tunnel** → 选 **Cloudflared** → 命名(如 `router-access`)→ **Save tunnel**
3. 在显示安装命令的页面,**复制那个 `eyJhIjoi...` 开头的完整 token**(很长的字符串)

### 第 5 步:把 Token 写入设备

用 base64 传输避免转义问题(电脑上执行):
```bash
# 电脑上:把 token 编码
echo -n 'eyJhIjoi...你的token...' | base64
# 把输出的 base64 串,到路由器上解码写文件
echo '这里粘贴base64串' | base64 -d > /jffs/cloudflared-token
```

验证写入成功:
```sh
wc -c /jffs/cloudflared-token     # 应有内容,不是 0
cat /jffs/cloudflared-token       # 应看到 eyJhIjoi... 开头
```

### 第 6 步:手动启动 cloudflared 并测试连接

```sh
killall cloudflared 2>/dev/null
/jffs/cloudflared tunnel run --token "$(cat /jffs/cloudflared-token)" > /jffs/cloudflared.log 2>&1 &
sleep 15
cat /jffs/cloudflared.log
```

**成功标志**——日志出现(关键):
```
INF Starting tunnel tunnelID=xxxx-xxxx
INF Registered tunnel connection connIndex=0 ... location=lax01 protocol=quic
INF Registered tunnel connection connIndex=1 ... location=lax11 protocol=quic
```
看到 `Registered tunnel connection` 即隧道已连上。

**失败排查**:
| 日志报错 | 含义 | 解决 |
|---------|------|------|
| `Failed to get tunnel` | Cloudflare 找不到该隧道 | token 有误,或隧道没在后台保存成功,重新创建 |
| `ERR Register tunnel error` | 注册失败 | 检查 token、网络 |
| `Error reading SSH protocol banner` | SSH 被限流 | 等一会再试,别频繁尝试 |

### 第 7 步:配置开机自启

把启动逻辑加入启动脚本。RT-AC68U 梅林固件在 `/jffs/scripts/services-start`:
```sh
# /jffs/scripts/services-start (末尾追加)
# Start cloudflared (Cloudflare Tunnel)
if [ -f /jffs/cloudflared-token ] && [ -s /jffs/cloudflared-token ]; then
    if ! pidof cloudflared > /dev/null 2>&1; then
        TOKEN=$(cat /jffs/cloudflared-token)
        /jffs/cloudflared tunnel run --token "$TOKEN" >> /jffs/cloudflared.log 2>&1 &
        echo "started cloudflared pid=$!" >> /jffs/cloudflared.log
    fi
fi
```
设为可执行:
```sh
chmod +x /jffs/scripts/services-start
```

### 第 8 步:在 Cloudflare 后台添加公共主机名(把设备发布出去)

1. **Networks → Tunnels** → 点你的隧道 → **Public Hostname** 标签
2. **Add a public hostname**:
   - **Subdomain**:`router`
   - **Domain**:`你的域名`(如 example.com)
   - **Type**:`HTTP`
   - **URL**:`192.168.1.1:80`(设备的内网地址和端口)
3. **Save**

完成后,从外网访问 `https://router.你的域名.com` 即可进入设备后台。

---

## 四、安全加固(必做)

**问题**:上面发布的网址,任何人知道地址都能访问。必须加保护。

### 1. 启用 Cloudflare Access 登录保护
参考第 2 篇(`02-Cloudflare-Access登录保护.md`)。

### 2. 设备自身密码改强
不要用默认弱密码(如 admin/admin、admin/123456)。

### 3. 只用 HTTPS
Cloudflare 隧道默认给 `http://...` 加一层 Cloudflare 的 HTTPS,访问时可用 `https://router.你的域名.com`。

---

## 五、常用运维命令

```sh
# 查看 cloudflared 是否运行
pidof cloudflared

# 查看连接日志
tail -20 /jffs/cloudflared.log

# 停止
killall cloudflared

# 重启
killall cloudflared; sleep 1; /jffs/cloudflared tunnel run --token "$(cat /jffs/cloudflared-token)" > /jffs/cloudflared.log 2>&1 &
```

---

## 六、本方案可推广到的设备

| 设备 | 目标 | 说明 |
|------|------|------|
| **NAS**(群晖/威联通) | 远程访问 NAS 管理后台/文件 | 架构多为 x86 或 arm64,下载对应二进制,放共享盘并加开机自启 |
| **软路由/OpenWrt** | 远程管理 | OpenWrt 可用 `opkg install cloudflared` |
| **树莓派** | 远程访问跑的服务 | armv7/arm64,放系统盘,加 systemd 服务 |
| **普通 Linux 服务器** | 暴露内网服务 | 直接 systemd 托管 cloudflared |

> 核心思路一致:**下载对应架构的 cloudflared → 配 token → 开机自启 → Cloudflare 后台加公共主机名 → 加 Access 保护**。
> # 给 router.你的域名.com 加 Cloudflare Access 登录保护

> 提示:文中域名、IP 均为占位,请替换为你自己的实际值。

> 目的:隧道发布出去的网址,任何人都能打开。加 Access 后,只有通过你验证的人才能访问。
> 适用:路由器后台、NAS 管理页、任何通过 cloudflared 发布的 HTTP 服务。

---

## 一、为什么必须加 Access

默认发布后,`https://router.你的域名.com` 全网可访问,若设备密码弱(如 admin/123456),极易被暴力破解。Access 在设备前再加一层"登录墙"。

## 二、配置步骤(Web 界面)

### 第 1 步:进入 Access 页面
1. 登录 https://one.dash.cloudflare.com
2. 左侧 **Access → Applications**(若没有 Access,确认进入的是 Zero Trust 工作区)

### 第 2 步:添加自托管应用
1. 点 **Add an application**
2. 选 **Self-hosted**(自托管)类型 → **Next**
3. 配置:
   - **Application name**: `router-access`
   - **Application domain**: `router.你的域名.com`
   - **Session duration**: 24 hours(多久免登录)
   - 其他默认 → **Next**

### 第 3 步:配置 Access Policy(谁能访问)
在 Policy 配置区:
1. **Policy name**: `only-me`
2. **Action**: **Allow**
3. **Configure rules / Include** 添加:
   - 选择 **Emails** 项
   - 填入**你自己的邮箱**
4. **Next → Save**

### 第 4 步:生效并测试
保存后等 30~60 秒。重新访问 `https://router.你的域名.com`:
- 先弹 Cloudflare 验证页 → 输入邮箱 → 收一次性验证码 → 通过后才进设备
- 其他邮箱会被拦截

---

## 三、四种"发布类型"怎么选(常见困惑)

创建应用时看到的类型:
| 选项 | 用途 | 需要吗 |
|------|------|--------|
| **已发布的应用程序 (Public Hostname)** | 发布成公网网址,浏览器直接访问 | 是(路由/NAS 网页后台)|
| **私有主机名 (Private Hostname)** | 仅装 WARP 客户端的设备可访问 | 可选(更私密但麻烦)|
| **私有 CIDR** | 远程访问整个内网 IP 段 | 不需要 |
| **Workers VPC** | Workers 连内网 | 不需要 |

## 四、登录方式说明(邮箱验证码)

Access 的邮箱一次性验证码叫 **One-time PIN (OTP)**:
- 在 **Access → Settings → Authentication** 确认 OTP 已启用
- Policy 规则里选 **Emails** 或 **One-time PIN**,填你的邮箱
- 首次登录会发验证码到该邮箱,之后会话期内免登录

---

## 五、完整效果

```
外网设备
   │ 访问 https://router.你的域名.com
   ▼
Cloudflare 边缘节点
   │  Cloudflare Access 验证(邮箱 OTP)
   ▼ 验证通过
路由器后台(192.168.1.1:80)
```
未通过验证的人:停在验证页,无法进入。

## 六、可推广到 NAS/其他设备

给每个发布的设备(路由器、NAS、各种 Web 服务)分别建一个 Access 应用,域名各自指向不同子域名,共用同一套邮箱验证即可。
# 用 Cloudflare Tunnel 远程访问 NAS、路由器及任何联网设备(通用思路)

> 核心思想:不用公网 IP、不用端口映射,任何能联网且能运行 cloudflared 的设备,都能通过 Cloudflare 隧道从外网访问。
> 本文是通用方法论,第 1 篇(安装 Cloudflared)是具体示例。

---

## 一、本质原理

Cloudflare Tunnel = 设备上的 cloudflared **主动出站**连到 Cloudflare 边缘,建立一条加密隧道。外网访问时流量走这条隧道进到内网设备。**无需开放任何入站端口,天然穿透 NAT。**

```
外网 ──> 你的域名 ──> Cloudflare 边缘 ──隧道──> 内网设备(NAS/路由器/PC/摄像头...)
```

## 二、通用接入五步法(任何设备都适用)

无论什么设备,都遵循这 5 步:

| 步骤 | 动作 | 关键点 |
|------|------|--------|
| 1. 确认架构 | 登录设备执行 `uname -m` | 决定下哪个 cloudflared 二进制 |
| 2. 下载二进制 | 下载对应架构的 cloudflared | 放到持久存储(重启不丢)|
| 3. 配 Token | 写入 Cloudflare 创建的隧道 token | 存成文件,一行 |
| 4. 开机自启 | 加入设备启动机制 | 系统 service / 启动脚本 / 定时任务 |
| 5. 发布+保护 | Cloudflare 后台加公共主机名,再套 Access | 域名指向设备内网地址:端口 |

---

## 三、分设备详解

### 1) 华硕路由器(RT-AC68U 等梅林固件)
- 架构:`uname -m` → `armv7l` → 用 `cloudflared-linux-arm`
- 存放:`/jffs/cloudflared`(JFFS 持久化)
- 自启:`/jffs/scripts/services-start` 追加启动块
- 详见第 1 篇

### 2) NAS(群晖 Synology)
- 架构:多数 x86_64,部分 arm64
- 下载:`cloudflared-linux-amd64`(或 arm64)
- 存放:任意共享盘目录
- 自启:群晖用 **任务计划程序** 或 **Container Manager(Docker)** 跑 cloudflared
- 发布:群晖 Web 后台默认 5000(HTTP)/5001(HTTPS),Service URL 填 `192.168.x.x:5000`
- 也可把群晖的 Docker 直接部署 cloudflared 容器

### 3) 威联通 QNAP
- 同群晖思路,web 端口多为 8080
- 自启:App Center 或 crontab

### 4) OpenWrt / 软路由
- 有 opkg 包: `opkg install cloudflared`
- 自启: `/etc/init.d/cloudflared`(系统自带服务机制)
- 发布:LuCI 后台 80/443

### 5) 树莓派 / 普通 Linux
- 下载对应架构二进制
- 自启:写一个 systemd 服务,开机自动跑
- 发布:任意 Web 服务端口

### 6) Windows PC / 服务器
- 下载 `cloudflared-windows-amd64.exe`
- 注册为服务: `cloudflared service install <token>`
- 或用 NSSM 包装

### 7) 摄像头 / 监控 NVR
- 若提供 Web 管理页或 RTSP,可发布 HTTP 页面或走私有主机名给 WARP 用户
- 注意:视频流带宽较大,免费隧道流量有限,需评估

---

## 四、开机自启的几种机制(按设备类型选)

| 机制 | 适用设备 | 示例 |
|------|---------|------|
| `/jffs/scripts/services-start` | 梅林/华硕固件 | 见第 1 篇 |
| systemd unit | Linux/树莓派 | `/etc/systemd/system/cloudflared.service` |
| init.d / rc.local | 传统 Linux/OpenWrt | `/etc/init.d/cloudflared` |
| Docker 容器 restart=always | 群晖/QNAP/NAS | docker run --restart always |
| Windows 服务 | Windows | `cloudflared service install <token>` |
| 计划任务/启动文件夹 | Windows | 或 `shell:startup` 放启动脚本 |

### systemd 示例(树莓派/Linux)
```ini
[Unit]
Description=cloudflared tunnel
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel run --token "$(cat /etc/cloudflared-token)"
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
```
```sh
sudo systemctl enable --now cloudflared
```

### Docker 示例(NAS)
```sh
docker run -d --name cloudflared --restart always \
  cloudflare/cloudflared:latest tunnel run --token $(cat /path/token)
```

---

## 五、安全最佳实践(每台设备都套用)

1. **必套 Cloudflare Access**:发布任何设备前,先建 Access 应用保护(见第 2 篇)。
2. **设备本地密码改强**:不要默认 admin/admin 或 admin/123456。
3. **最小暴露**:只发布需要的服务端口,不发布无关端口。
4. **HTTPS**:访问统一用 `https://你的域名`。
5. **限 IP(可选)**:Access Policy 里可加规则"仅允许我的家庭/办公 IP 段"。
6. **最小权限**:SSH 用路由器登录账号 + 强密码,且仅内网可访问。

---

## 六、故障排查速查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| 隧道连不上,日志 `Failed to get tunnel` | token 错 / 隧道未保存 | 重建隧道,确认后台存在 |
| 进程没起来 | 自启脚本权限/路径错 | 检查 chmod +x、路径 |
| 能连但访问 502 | Service URL 端口写错 / 服务没监听 | 核对内网地址:端口 |
| Access 弹不出验证 | 没配 Policy 或还没生效 | 等 60 秒,确认 Policy 存在 |
| 手机打不开 | 手机连接的是与隧道同一内网的 WiFi | 改用 4G/5G 流量访问测试 |

---

## 七、一个账号管多台设备

一个 Cloudflare 账户可建多个 Tunnel 或多个 hostname,把家里所有设备(路由器、NAS、PC、摄像头)统一管理:
- 每个设备建一个 hostname:`router.你的域名`、`nas.你的域名`、`pc.你的域名`...
- 统一加 Access,一套邮箱验证即可全部保护
- 集中在一个后台管理,非常省事
- # 用 Cloudflare API 自动配置 Access 登录保护(代码方式)

> 目的:上一篇(02)用 Web 界面给域名加 Access。这篇改用 **API + 脚本** 自动创建 Access 应用和策略,适合批量部署多台设备(NAS、路由器等),也可接入自动化流程。
> 提示:文中 API_TOKEN、ACCOUNT_ID、域名均为占位,请替换为你自己的实际值。

---

## 一、准备:拿到 API 凭据

### 1. 创建 Cloudflare API Token(编辑 Zero Trust)
在 https://dash.cloudflare.com → 右上角头像 → **My Profile → API Tokens → Create Token**
- 权限建议:**Access:Apps and Policies 编辑**(Edit)
- 范围:你的账户
- 创建后复制 `CF_API_TOKEN`(只显示一次)

### 2. 找到 account_id
在同一个 API 页面或 URL 里,`https://dash.cloudflare.com/<account_id>` 中间的即为 account_id。
或用 API 查询:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

### 3. 用环境变量存放(避免硬编码)
```bash
export CF_API_TOKEN="你的token"
export CF_ACCOUNT_ID="你的账户id"
export APP_DOMAIN="router.你的域名.com"
export EMAIL="你自己@example.com"
```

---

## 二、核心 API 概念

| 对象 | API | 作用 |
|------|-----|------|
| Access Application | `POST /accounts/{id}/access/apps` | 定义一个受保护的域名 |
| Access Policy | `POST /accounts/{id}/access/apps/{app_id}/policies` | 定义谁能访问(规则)|
| 查询 | `GET .../access/apps` | 查看已有应用 |

认证:请求头 `Authorization: Bearer <token>`、`Content-Type: application/json`。

---

## 三、代码一:创建 Access 应用

```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "router-access",
    "domain": "'$APP_DOMAIN'",
    "type": "self_hosted",
    "session_duration": "24h",
    "allowed_idps": []
  }'
```

返回 JSON 里的 `result.id` 就是 `APP_ID`,下一步要用。

> 若域名已有对应隧道 hostname,应用会自动关联该域名下的访问。

---

## 四、代码二:创建 Access 策略(允许你的邮箱)

用上一步得到的 `APP_ID`:

```bash
APP_ID="从上一步返回的 result.id"

curl -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "only-me",
    "decision": "allow",
    "precedence": 100,
    "include": [
      { "email": { "email": "'$EMAIL'" } }
    ],
    "require": []
  }'
```

- `decision`: `allow`(允许)或 `deny`(拒绝)
- `include`:命中这些规则的人被放行。这里用 `email.email` 限定只有你自己的邮箱
- 返回 `result.id` 即 policy id

---

## 五、代码三:查询已配置的应用(验证)

```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```
返回里能看到所有 Access 应用及其域名、策略,用于确认配置生效。

---

## 六、完整一键脚本(创建 App + Policy)

把下面保存为 `setup-access.sh`,改顶部变量后运行 `sh setup-access.sh`:

```bash
#!/bin/sh
# 自动创建 Access 应用和"仅我邮箱"策略
set -e

# ---- 配置区 ----
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}"
APP_DOMAIN="${APP_DOMAIN:-router.你的域名.com}"
APP_NAME="${APP_NAME:-router-access}"
EMAIL="${EMAIL:-你@example.com}"
SESSION="${SESSION:-24h}"
# ----------------

[ -z "$CF_API_TOKEN" ] && { echo "缺 CF_API_TOKEN"; exit 1; }
[ -z "$CF_ACCOUNT_ID" ] && { echo "缺 CF_ACCOUNT_ID"; exit 1; }

API="https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID"

# 1) 创建应用
APP_JSON=$(curl -s -X POST "$API/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"$APP_NAME\",\"domain\":\"$APP_DOMAIN\",\"type\":\"self_hosted\",\"session_duration\":\"$SESSION\"}")
APP_ID=$(echo "$APP_JSON" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "App 创建, id=$APP_ID"

# 2) 创建策略
curl -s -X POST "$API/access/apps/$APP_ID/policies" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"name\":\"only-me\",\"decision\":\"allow\",\"include\":[{\"email\":{\"email\":\"$EMAIL\"}}]}"
echo ""
echo "策略已创建。"
```

---

## 七、批量给多台设备加保护

对多台设备(路由器、NAS、PC),循环调用:
```bash
for HOST in router nas pc; do
  APP_DOMAIN="$HOST.你的域名.com" sh setup-access.sh
done
```
每台设备一个子域名,一套邮箱即可全部受控访问。

---

## 八、删除/清理(可选)

删除应用(同时删其策略):
```bash
curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/access/apps/$APP_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

---

## 九、常用 API 参考

| 用途 | 方法 + 路径 |
|------|------------|
| 创建应用 | POST /accounts/{id}/access/apps |
| 列应用 | GET /accounts/{id}/access/apps |
| 更新应用 | PUT /accounts/{id}/access/apps/{app_id} |
| 删除应用 | DELETE /accounts/{id}/access/apps/{app_id} |
| 创建策略 | POST /accounts/{id}/access/apps/{app_id}/policies |
| 列策略 | GET /accounts/{id}/access/apps/{app_id}/policies |

官方文档:https://developers.cloudflare.com/api/operations/zero-trust-access-applications-list-access-applications

## 许可

本项目采用 [MIT License](LICENSE) 授权 —— 可自由使用、修改、分发,包括商业用途,只需保留版权声明。

> **免责提醒:** 脚本会修改路由器的系统文件(`/jffs`)与开机自启脚本(`/jffs/scripts/services-start`),
> 动手前请先读懂每一步在做什么,并确认自己有能力恢复(备份 `/jffs`、确认救援模式可用)。
> 软件按「原样」提供,不附带任何担保,使用风险自负。
