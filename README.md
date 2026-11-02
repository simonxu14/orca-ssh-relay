# Orca SSH Relay

macOS 上的 Orca 远程连接辅助工具：通过一台公网 SSH 中转服务器，从工作电脑访问家里 Mac 上已有的项目、终端和会话。

日常连接由 **Orca 原生 SSH** 管理；本工具提供只读状态检查、家里端反向隧道准备，以及手动备用通道。它复用 Orca 已有配对，不创建新的项目或会话。

## 连接逻辑

```mermaid
flowchart LR
    W[工作 Mac / Orca] -->|Orca 原生 SSH 主通道| R[公网 SSH 中转服务器]
    H[家里 Mac / SSH 后台连接] -->|反向转发| R
    R -->|已有转发通道| O[家里 Orca 服务]
    W -. 手动备用 SSH 通道 .-> R
```

1. **家里端**主动连到中转服务器，把家里 Orca 的 `127.0.0.1:6768` 转发到服务器的 `127.0.0.1:16768`。家里网络不需要开放公网入站端口。
2. **工作端主通道**由 Orca 自己连接中转服务器，并分配本地动态端口。打开 Orca 后使用已有原生 SSH 绑定，日常无需启动备用脚本。
3. **备用通道**由 `work-tunnel backup-start` 手动创建，本地默认入口为 `127.0.0.1:17668`。启动备用不会自动切换 Orca 的连接设置。
4. **业务运行位置**仍在家里 Mac。中转服务器只转发连接；项目、代码、Agent 和会话不会迁到服务器。

Orca 配对仍负责应用层认证。SSH 隧道可达不代表已经配对成功。

## 适用条件

- 两端是装有 Orca 的 Mac；家里端已启用共享、联网并保持唤醒。
- 一台可访问的 OpenSSH 中转服务器，使用两个独立、只允许指定转发的账户。
- 工作端已通过 Orca 正常配对家里端，并配置原生 SSH 入口。
- `native-status.js` 使用已安装 Orca 的内部运行时模块。Orca 升级改变内部接口后，状态检查可能需要适配。

## 工作端：已有连接的日常使用

```bash
cp config.example.env config.local.env
chmod 600 config.local.env
./work-tunnel environments
```

把列表中目标环境的 ID 填入 `config.local.env` 的 `ORCA_ENVIRONMENT_ID`；工作端保持 `ORCA_RELAY_ROLE=work`。配置文件是受信任的本机 shell 文件，请自行编辑，不从不可信来源执行。

```bash
./work-tunnel status
./work-tunnel status --json
```

也可以双击根目录的 `查看工作端状态.command`。检查会读取 Orca 保存的连接资料，并验证：

- 首选入口确实是 Orca 管理的动态 SSH 端口；
- 远端配对设备和运行实例身份匹配；
- 会话图就绪，项目和终端列表可读取；
- 本地监听者确实是当前安装的 Orca。

状态检查只读，不发送聊天消息，也不会自动重配对、更新运行实例身份或启动备用通道。

## 首次配置家里端

先由服务器管理员按 [中转服务器说明](docs/relay-server.md) 准备独立账户和转发限制。

在**家里 Mac** 克隆本仓库，然后：

1. 复制配置示例为 `config.local.env`，设置 `ORCA_RELAY_ROLE=home` 和自己的中转服务器地址、SSH 端口。
2. 通过服务器控制台等可信渠道确认 SSH 主机公钥，将匹配服务器地址和端口的记录保存为 `known_hosts.local`。单独执行 `ssh-keyscan` 不能完成真实性核验。
3. 运行 `home-install/01-准备家里端.command`。它生成家里端独立密钥、SSH 配置和暂存的 launchd 文件；已有配置会拒绝覆盖，此步骤不会启动连接。
4. 将脚本输出的**公钥**登记到服务器的家里端账户。私钥留在家里 Mac。
5. 打开家里 Orca，运行 `home-install/02-启动家里端.command`，安装并启动登录后台连接。

停止家里端并移除其登录启动项：

```bash
./home-install/03-停止家里端.command
```

脚本在后台连接之前检查本机 Orca 服务是否可达；后台连接启动后，仍需在工作端确认实际配对和会话访问。

## 工作端：配置与使用备用通道

将 [工作端 SSH 示例](examples/ssh_config_work.example) 复制到：

```text
~/Library/Application Support/Orca SSH Relay/ssh_config_work
```

修改服务器地址，并准备示例引用的独立工作端密钥和已核验的主机公钥文件。已有密钥勿覆盖；带口令的密钥需要先在本机 SSH agent 中解锁，以支持脚本的非交互连接。

```bash
./work-tunnel backup-start
./work-tunnel backup-status
./work-tunnel backup-stop
```

对应的中文 `.command` 文件可直接双击。`start` / `stop` 是备用命令的兼容别名。修改 `ORCA_RELAY_BACKUP_PORT` 时，需同时修改 SSH 配置的 `LocalForward` 本地端口。

备用入口默认是 `ws://127.0.0.1:17668`。在 Orca 中手动选择对应连接后使用；恢复主通道后再停止备用。具体操作见 [连接恢复说明](docs/troubleshooting.md)。

## 文件与本机数据

| 位置 | 内容 |
|---|---|
| `work-tunnel` | 工作端入口和备用转发控制 |
| `native-status.js` | 原生 SSH 连接的只读检查 |
| `home-install/` | 家里端准备、启动、停止脚本 |
| `examples/`、`docs/` | 通用配置示例和架构说明 |
| `config.local.env` | 本机环境选择和连接配置，Git 忽略 |
| `.local/` | 本机历史归档，Git 忽略，不随克隆分发 |
| `~/.ssh/orca-relay/` | 当前 Mac 的 SSH 密钥 |
| `~/Library/Application Support/Orca SSH Relay/` | SSH 配置、启动项暂存文件和运行日志 |

公开仓库不携带个人服务器地址、真实设备 ID、密钥、主机指纹、配对凭据或真实运行记录。已有 Orca 配对数据继续由 Orca 自身管理。

## 验证

```bash
bash tests/offline.sh
```

离线测试使用临时 HOME、临时密钥和真实 OpenSSH 配置解析，覆盖配置定制、含空格路径、loopback 转发、拒绝覆盖已有配置，以及主机公钥缺失和端口无效时提前退出。测试不连接真实中转服务器，不安装真实用户启动项。

`work-tunnel status` 属于使用已配对环境的在线只读检查；离线测试不代表新服务器或其他 Mac 已完成端到端验收。
