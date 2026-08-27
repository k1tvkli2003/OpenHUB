<p align="center">
  <img src="native_windows/assets/brand/openhub-route-hub.png" width="150" alt="OpenHUB 标志">
  <br>
  <img src="native_windows/assets/brand/openhub-wordmark.png" width="300" alt="OpenHUB">
</p>

# OpenHUB

OpenHUB 是一个本地优先、与模型供应商无关的 AI 编程代理控制平面。它在同一个 Windows
界面中显示 Codex、Hermes Agent 和 OpenCode 的任务状态、模型、心跳、上下文活动和
令牌用量，并提供运行时真正支持的暂停、继续、停止和打开操作。

主要能力：

- 子代理用量归并到父任务，同时保留可查看的任务谱系；
- 一个仅限本机回环地址的 OpenAI 兼容端点，可在请求级切换可用账号；
- GPT-5.6 Sol、Terra 和 Luna 的完整后备模型目录；
- 以 `~/.codex` 为唯一来源的技能、记忆和全局指令实时共享；
- 运行时遥测断开后的 20 秒重连宽限与持久状态、用量增量补齐；
- 只清理白名单旧文件的预览、摘要校验和二次确认流程；
- 账号池并发刷新，以及可独立选择历史记录处理方式的账号删除。

## Windows 安装

1. 从 GitHub Releases 下载 `OpenHUB-Windows-2.0.0.zip`。
2. 完整解压到可写目录。
3. 运行 `Launch-OpenHUB.ps1` 或 `OpenHUB.exe`。
4. 在 **Accounts** 中添加账号，在 **Pulse** 中查看已发现的运行时。

压缩包自带固定版本的本地后端，启动时不需要 Python、Git、`uv` 或在线安装依赖。
当前公开构建提供 SHA-256 校验和，但尚未进行 Authenticode 签名。

共享端点：

```text
http://127.0.0.1:2455/backend-api/openhub/v1
```

本地状态保存在 `%USERPROFILE%\.openhub`。不要把该目录、`.codex`、Hermes 或
OpenCode 的运行时数据提交到仓库。

## 开发与验证

使用 FastAPI 开发重载器时应显式关闭代理头投影：

```powershell
uv run fastapi run app/main.py --reload --no-proxy-headers
```

完整的架构、客户端配置、安全边界、构建命令和发布验证说明请参阅
[英文 README](README.md) 与 [贡献指南](.github/CONTRIBUTING.md)。

OpenHUB 使用 MIT 许可证，并保留原上游项目及贡献者的归属说明。
