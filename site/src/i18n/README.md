# 前端中英双语(运行时词典翻译层)

此 fork 的界面支持中英文切换。源码中的字符串保持英文原样,由运行时
翻译层根据词典将渲染后的 DOM 文本翻译为中文;未收录的文本保持英文显示。
这样上游 (coder/coder) 的代码改动可以正常合并,不会与逐文件包裹 `t()`
调用产生冲突。

## 组成部分

| 文件 | 职责 |
|---|---|
| `src/i18n/language.ts` | 语言偏好类型、localStorage 读写(`coder:language`),按浏览器语言默认 |
| `src/i18n/dictionary.ts` | 词典查询:精确匹配 + 插值字符串正则规则 |
| `src/i18n/zh-CN.ts` | 生成的英文到中文词典(勿手改,见下方流程) |
| `src/i18n/domTranslator.ts` | MutationObserver 驱动的 DOM 翻译引擎 |
| `src/contexts/LanguageProvider.tsx` | 上下文 + `useLanguage()`;切换语言后整页刷新 |
| `scripts/extract-i18n-strings.mjs` | 从 `src/` 提取用户可见英文字符串 |

切换入口:右上角用户菜单的语言项,以及 设置 → 外观 → 语言。
语言偏好保存在浏览器 localStorage(每浏览器独立,非服务端账号设置)。
未保存偏好时按浏览器语言决定:zh 开头的 locale 默认中文,其余默认英文。

测试与 Storybook 固定英文(`language.ts` 中对 `MODE=test` 和
`STORYBOOK` 的判断),保证断言和 Pixel 视觉基线确定性。

## 翻译引擎行为

- 只翻译词典命中的文本节点和 `placeholder`/`title`/`aria-label`/
  `aria-placeholder` 属性;其余原文保留。
- 跳过 `code`、`pre`、`textarea`、`.xterm`、`.monaco-editor`、
  `[contenteditable]`、`[data-no-translate]`,避免破坏终端、编辑器和
  代码内容。
- React 重新写入某文本节点时会再次触发翻译;已含中文的文本不再匹配。
- 相对时间(dayjs `fromNow`)和 `humanDuration` 通过 dayjs `zh-cn`
  locale 与 humanize-duration `zh` 语言本地化。

## 词典更新流程

1. `node scripts/extract-i18n-strings.mjs /tmp/i18n-extract` 提取字符串。
2. 将新增字符串按本文件"翻译规则"翻译成 JSON(英文原句为键)。
3. 合并进 `src/i18n/zh-CN.ts`(键为压缩空白后的原句)。
4. 插值字符串(如 `` `Version: ${name}` ``)在 `dictionary.ts` 的
   `patterns` 中增加正则规则,规则必须锚定英文原文,避免匹配到已翻译文本。
5. `pnpm test src/i18n/` 回归。

# 翻译规则(术语表)

翻译时遵循以下规则;本规则同时用于人工与批量翻译。

## 保留英文的技术术语(不翻译)

- 产品与协议名:Coder、Coder Desktop、Coder CLI、VS Code、JetBrains、
  GitHub、GitLab、Discord、Terraform、Docker、Kubernetes、Dev Container
- 云原生与基础设施:Pod、Deployment、Namespace、PVC、Ingress、Helm、
  GPU、CPU、RAM、vCPU、H200、RDMA、NCCL、vLLM、SGLang
- 协议与标准:SSH、SFTP、RDP、VNC、HTTPS、HTTP、TCP、UDP、TLS、DERP、
  OIDC、OAuth2、SSO、SAML、LDAP、API、URL、URI、DNS、CIDR
- 工程概念:Agent、Provisioner、Token、ID/UUID、CLI、IDE、Git、
  WebSocket、cron、Regex、JSON、YAML、TOML、Markdown
- 单位与符号:ms、KB、MB、GB、TB、GiB、MiB、GHz

## 标准译法

| 英文 | 中文 |
|---|---|
| Workspace | 工作区 |
| Template | 模板 |
| Organization | 组织 |
| User | 用户 |
| Group | 用户组 |
| Audit log | 审计日志 |
| Build | 构建 |
| Schedule(设置页/任务) | 计划 |
| Autostart / Autostop | 自动启动 / 自动停止 |
| Quota | 配额 |
| Budget | 预算 |
| Credit | 积分 |
| Workspace proxy | 工作区代理 |
| Version | 版本 |
| Notification | 通知 |
| Dormant | 休眠 |
| Deletion / Delete | 删除 |
| Start / Stop / Restart | 启动 / 停止 / 重启 |
| Update | 更新 |
| Save / Cancel | 保存 / 取消 |
| Sign in / Sign out | 登录 / 退出登录 |
| Theme | 主题 |
| Appearance | 外观 |
| Settings | 设置 |
| Parameter | 参数 |
| Variable | 变量 |
| Secret | 密钥(Secret 值指 K8s Secret 时保留英文) |
| Apps / Applications | 应用 |
| Port forwarding | 端口转发 |
| Logs | 日志 |
| Insight | 洞察 |
| License | 许可证 |
| Entitlement | 授权 |
| Ownership | 所有权 |
| Sharing level | 共享级别 |
| Favorite | 收藏 |
| Owner | 所有者 |
| Custom | 自定义 |
| Default | 默认 |
| Template version | 模板版本 |
| Icon | 图标 |
| Description | 描述 |
| Display name | 显示名称 |

## 排版规则

1. 中文与英文单词、数字之间加一个空格,如 `复制 Token`、`2 个 GPU`。
2. 中文句子使用全角标点(,。:;!?""''),括号内为纯英文术语时可用半角括号。
3. 引用用户输入或名称时使用中文引号"",保留原文引号内的内容不变。
4. 按钮与菜单项保持简短,省略句号。
5. 句子片段(原句以小写字母或标点开头,是动态值前后的续句)翻译为
   语义连贯的中文续句片段,保持片段性质,不要补全成完整句子。
6. 出现 `\n`、`{{...}}`、`$1` 等占位符时原样保留。
7. 语气自然、面向开发者;错误提示用"无法/失败",不用口语化表达。
8. 英文原文中的省略号 `...` 保留为 `...`(不转换为 `……`)。
