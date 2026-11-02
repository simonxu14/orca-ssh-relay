// Read-only health check. Run with the installed Orca Electron in Node mode.
const { spawnSync } = require('child_process');
const path = require('path');
const app = process.env.ORCA_APP_PATH || '/Applications/Orca.app';
const root = path.join(app, 'Contents/Resources/app.asar.unpacked/out');
const { RuntimeClient } = require(root + '/cli/runtime/client.js');
const { getDefaultUserDataPath } = require(root + '/cli/runtime/metadata.js');
const { readEnvironmentStore } = require(root + '/shared/runtime-environment-store-file.js');
const { getPreferredPairingOffer } = require(root + '/shared/runtime-environments.js');
const { encodePairingOffer } = require(root + '/shared/pairing.js');
const json = process.argv.includes('--json');
(async () => {
  const ud = getDefaultUserDataPath();
  const environments = readEnvironmentStore(ud).environments;
  if (process.argv.includes('--environments')) {
    console.log(JSON.stringify(environments.filter(e => e.sshAccess).map(e => ({id: e.id, name: e.name})), null, 2));
    return;
  }
  const environmentId = process.env.ORCA_ENVIRONMENT_ID;
  if (!environmentId) throw Error('请先运行 work-tunnel environments，再在 config.local.env 中设置 ORCA_ENVIRONMENT_ID。');
  const env = environments.find(e => e.id === environmentId);
  if (!env?.sshAccess) throw Error('没有找到家里 Orca 的原生 SSH 绑定，请先打开 Orca。');
  const endpoint = env.endpoints.find(e => e.id === env.preferredEndpointId)?.endpoint;
  if (env.preferredEndpointId !== env.sshAccess.endpointId || endpoint !== `ws://127.0.0.1:${env.sshAccess.localPort}`)
    throw Error('家里主机当前未优先使用 Orca 管理的 SSH 入口。');
  // Pin this check to the native tunnel; never fall back to the backup listener.
  const client = new RuntimeClient(ud, 15000, encodePairingOffer(getPreferredPairingOffer(env)), null);
  const [status, repos, terminals] = await Promise.all([
    client.call('status.get', {}), client.call('repo.list', {}),
    client.call('terminal.list', {limit: 200, includeVisualLayouts: false})
  ]);
  if (status.result.pairedDeviceId !== env.pairedDeviceId)
    throw Error('配对设备身份不一致，已停止检查；请勿直接更新运行实例编号。');
  if (status.result.runtimeId !== env.runtimeId)
    throw Error('同一配对设备的运行实例编号已变化，工作端 SSH 绑定记录需要核对更新；网络通道已可达。');
  if (status.result.graphStatus !== 'ready')
    throw Error('家里 Orca 已可达，但会话界面尚未就绪。');
  const listener = spawnSync('/usr/sbin/lsof', ['-nP', `-iTCP:${env.sshAccess.localPort}`, '-sTCP:LISTEN', '-Fp'], {encoding: 'utf8'});
  if (listener.status !== 0) throw Error('未找到原生 SSH 本地监听，请在 Orca 中检查连接状态。');
  const pids = [...listener.stdout.matchAll(/^p(\d+)$/gm)].map(m => m[1]);
  if (!pids.length || !pids.every(pid => spawnSync('/bin/ps', ['-p', pid, '-o', 'comm='], {encoding: 'utf8'}).stdout.trim() === path.join(app, 'Contents/MacOS/Orca')))
    throw Error('原生 SSH 入口的监听进程不是当前安装的 Orca。');
  const backupPort = process.env.ORCA_RELAY_BACKUP_PORT || '17668';
  const legacy = spawnSync('/usr/sbin/lsof', ['-nP', `-iTCP:${backupPort}`, '-sTCP:LISTEN', '-Fp'], {encoding: 'utf8'});
  if (![0, 1].includes(legacy.status)) throw Error('无法检查旧 17668 端口。');
  const result = {pass: true, environment: env.name, runtimeId: status.result.runtimeId,
    nativeEndpoint: endpoint, listenerPids: pids.map(Number),
    projects: repos.result.repos.map(r => r.displayName),
    sessionCount: terminals.result.terminals.length,
    legacyPortListening: legacy.status === 0};
  if (json) console.log(JSON.stringify(result, null, 2));
  else {
    console.log(`Orca 原生 SSH 主通道正常：${env.name}`);
    console.log(`入口：${endpoint}（由 Orca 管理，无需手动启动脚本）`);
    console.log(`家里项目：${result.projects.join('、')}；现有会话：${result.sessionCount}`);
    console.log(`备用转发：${result.legacyPortListening ? '正在监听' : '已停止（正常，日常不需要）'}`);
  }
})().catch(e => { console.error(json ? JSON.stringify({pass: false, error: e.message}) : e.message); process.exitCode = 1; });
