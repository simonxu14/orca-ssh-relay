# 中转服务器职责

服务器只承接两个方向的 SSH 转发。家里端发布 loopback 端口；工作端只允许访问这个指定端口。

| 账户示例 | 允许 | 拒绝 |
|---|---|---|
| `orca-home-relay` | 反向发布 `127.0.0.1:16768` | Shell、SFTP、其他监听地址/端口、正向转发 |
| `orca-work-client` | 正向访问 `127.0.0.1:16768` | Shell、SFTP、其他目标、反向转发 |

由管理员创建两个独立专用账户，分别登记两台 Mac 产生的公钥。账户必须能使用公钥建立转发连接；不可复用管理员账户或允许普通 Shell 登录。

配置参考 [sshd-users.conf.example](../examples/sshd-users.conf.example)。管理员应检查当前服务器的 Include 顺序、Match 规则和 authorized_keys 位置，将限制应用到这两个账户。

可进一步在对应的 authorized_keys 条目上限定用途，替换下列公钥占位符：

```text
restrict,port-forwarding,permitlisten="127.0.0.1:16768" ssh-ed25519 HOME_PUBLIC_KEY
restrict,port-forwarding,permitopen="127.0.0.1:16768" ssh-ed25519 WORK_PUBLIC_KEY
```

服务端监听保持 loopback，不需要把 16768 开放到公网。不要设置 `GatewayPorts yes` 来绕过这一限制。SSH 登录入口自身仍需对两台 Mac 可达。

应用前备份服务端配置并保留现有管理员连接，使用 `sshd -t` 检查语法，再用 `sshd -T -C user=...,addr=...,host=...` 分别确认专用账户和管理员账户的有效策略。确认后由管理员按本机服务管理方式重载；本项目不会自动修改服务器。

新建部署还应实际验证：指定转发成功、Shell 和 SFTP 被拒、其他转发目标被拒、发布端口只监听 loopback，以及 Orca 自身仍要求配对。

上述限制的定义见 OpenSSH 官方手册：[AllowTcpForwarding、PermitOpen、PermitListen、GatewayPorts](https://man.openbsd.org/sshd_config)，以及 [SSH 客户端配置](https://man.openbsd.org/ssh_config)。限制转发应与禁止会话、agent 和其他通道配合使用。
