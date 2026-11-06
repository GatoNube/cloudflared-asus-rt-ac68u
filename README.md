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

## 使用流程(从零到能远程访问)

> 整套方案用**免费域名 + 免费服务,0 成本**。免费域名可到两个渠道找一个**能托管到 Cloudflare** 的:① 免费顶级域名注册商(NS 改到 CF);② 免费二级域名服务。详见 01 篇"前置条件"。

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

## 许可

本项目采用 [MIT License](LICENSE) 授权 —— 可自由使用、修改、分发,包括商业用途,只需保留版权声明。

> **免责提醒:** 脚本会修改路由器的系统文件(`/jffs`)与开机自启脚本(`/jffs/scripts/services-start`),
> 动手前请先读懂每一步在做什么,并确认自己有能力恢复(备份 `/jffs`、确认救援模式可用)。
> 软件按「原样」提供,不附带任何担保,使用风险自负。
