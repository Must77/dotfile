# config/

按 home 相对路径镜像家目录中的配置文件，部署：`rsync -av config/ ~/`

- `.config/opencode/cli.json`：END/HOME 改为移动输入框光标，取消对话首尾跳转，`ctrl+c`/`ctrl+d` 不再退出程序（仅 `ctrl+x q` 退出）
- `.codex/config.toml`：codex 模型、沙箱、状态行等设置
- `.config/opencode/opencode.jsonc`：OpenCode 主配置（火山 Ark provider，GLM/DeepSeek/Kimi 模型定义）
- `.config/Code/User/chatLanguageModels.json`：VS Code Copilot Chat 的 BYOK 自定义端点（同上模型，含 effort 档位 high/max）
- `.config/Code/User/settings.json`：VS Code Chat 相关设置（BYOK 显示开关、utility 模型固定为 GLM 5.3 Flash）

**API key 策略**：以上文件入库时一律把明文 key 替换为 `REPLACE_WITH_YOUR_ARK_API_KEY` 占位符，真实 key 只存在于本机原文件中。用 `rsync -av config/ ~/` 部署后，需手动把两处占位符换回真实 key（注意 rsync 会覆盖家目录同名文件，若本机文件较新请反向同步或逐个核对）。
