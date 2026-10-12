import { zhCN } from "./zh-CN";

/**
 * A rule for strings whose final rendered text embeds dynamic values, for
 * example "Stop in 8 hours" from `Stop in ${duration} hours`. The pattern
 * matches the rendered English text and the template uses $1, $2, ... for
 * the captured segments. Patterns must anchor to the English words around
 * the dynamic part so translated text is never matched a second time.
 */
type TranslationPattern = Readonly<{ pattern: RegExp; template: string }>;

const exactMatches: ReadonlyMap<string, string> = new Map(Object.entries(zhCN));

const patterns: readonly TranslationPattern[] = [
	// Confirmation dialogs. Exact source wording from the components.
	{
		pattern:
			/^Are you sure you want to stop the workspace "(.+)"\? This will terminate all running processes and disconnect any active sessions\.$/,
		template:
			"确定要停止工作区“$1”吗?这将终止所有运行中的进程并断开所有活动连接。",
	},
	{
		pattern:
			/^Are you sure you want to restart the workspace "(.+)"\? This will stop all running processes and delete non-persistent data\.$/,
		template:
			"确定要重启工作区“$1”吗?这将停止所有运行中的进程并删除非持久化数据。",
	},
	{
		pattern:
			/^Are you sure you want to stop (.+)\? This will terminate all running processes and disconnect any active sessions\.$/,
		template: "确定要停止$1吗?这将终止所有运行中的进程并断开所有活动连接。",
	},
	{
		pattern:
			/^Are you sure you want to cancel the build for workspace "(.+)"\? This will (.+)\.$/,
		template: "确定要取消工作区“$1”的构建吗?$2。",
	},
	{
		pattern:
			/^Are you sure you want to cancel the provisioner job "(.+)"\? This operation will result in the associated workspaces not getting created\.$/,
		template:
			"确定要取消 Provisioner 任务“$1”吗?该操作将导致关联的工作区无法创建。",
	},
	{
		pattern:
			/^Delete enqueued for "(.+)", but no matching provisioners are available\. The workspace will be deleted once one comes online\.$/,
		template:
			"已为“$1”排队删除,但没有可用的 Provisioner。工作区将在 Provisioner 上线后被删除。",
	},

	// Success and failure toasts.
	{
		pattern: /^Workspace "(.+)" updated successfully\.$/,
		template: "工作区“$1”更新成功。",
	},
	{
		pattern: /^Schedule for workspace "(.+)" updated successfully\.$/,
		template: "工作区“$1”的计划已更新。",
	},
	{
		pattern: /^Failed to update schedule for workspace "(.+)"\.$/,
		template: "更新工作区“$1”的计划失败。",
	},
	{
		pattern: /^Shutdown time for "(.+)" updated successfully\.$/,
		template: "“$1”的停止时间已更新。",
	},
	{
		pattern: /^Unable to process latest data for workspace "(.+)"\.$/,
		template: "无法处理工作区“$1”的最新数据。",
	},
	{
		pattern: /^Unable to get changes for workspace "(.+)"\.$/,
		template: "无法获取工作区“$1”的变更。",
	},
	{
		pattern: /^Template "(.+)" updated successfully\.$/,
		template: "模板“$1”更新成功。",
	},
	{
		pattern: /^Template "(.+)" data refreshed successfully\.$/,
		template: "模板“$1”数据刷新成功。",
	},
	{
		pattern: /^Template "(.+)" schedule updated successfully\.$/,
		template: "模板“$1”的计划已更新。",
	},
	{
		pattern: /^Template "(.+)" variables updated successfully\.$/,
		template: "模板“$1”的变量已更新。",
	},
	{
		pattern: /^Template version "(.+)" built successfully\.$/,
		template: "模板版本“$1”构建成功。",
	},
	{
		pattern: /^Version "(.+)" promoted successfully\.$/,
		template: "版本“$1”已提升。",
	},
	{
		pattern: /^Version "(.+)" archived successfully\.$/,
		template: "版本“$1”已归档。",
	},
	{
		pattern: /^Invalidated (\d+) presets? for version "(.+)"\.$/,
		template: "已使版本“$2”的 $1 个预设失效。",
	},
	{
		pattern: /^Secret "(.+)" created successfully\.$/,
		template: "密钥“$1”创建成功。",
	},
	{
		pattern: /^Secret "(.+)" updated successfully\.$/,
		template: "密钥“$1”更新成功。",
	},
	{
		pattern: /^Secret "(.+)" deleted successfully\.$/,
		template: "密钥“$1”删除成功。",
	},
	{
		pattern: /^Enabled secret "(.+)"\.$/,
		template: "已启用密钥“$1”。",
	},
	{
		pattern: /^Disabled secret "(.+)"\.$/,
		template: "已禁用密钥“$1”。",
	},
	{
		pattern: /^Organization "(.+)" created successfully\.$/,
		template: "组织“$1”创建成功。",
	},
	{
		pattern: /^Organization "(.+)" settings updated successfully\.$/,
		template: "组织“$1”的设置已更新。",
	},
	{
		pattern: /^Organization "(.+)" deleted successfully\.$/,
		template: "组织“$1”删除成功。",
	},
	{
		pattern: /^Group "(.+)" deleted successfully\.$/,
		template: "用户组“$1”删除成功。",
	},
	{
		pattern: /^Group "(.+)" added to workspace successfully\.$/,
		template: "用户组“$1”已添加到工作区。",
	},
	{
		pattern: /^Group role "(.+)" updated successfully\.$/,
		template: "用户组角色“$1”已更新。",
	},
	{
		pattern: /^Group "(.+)" removed successfully\.$/,
		template: "用户组“$1”已移除。",
	},
	{
		pattern: /^This group gives (\d+) quota credits to each of its members\.$/,
		template: "该用户组为每位成员提供 $1 个配额积分。",
	},
	{
		pattern: /^User "(.+)" deleted successfully\.$/,
		template: "用户“$1”删除成功。",
	},
	{
		pattern: /^User "(.+)" suspended successfully\.$/,
		template: "用户“$1”已停用。",
	},
	{
		pattern: /^User "(.+)" activated successfully\.$/,
		template: "用户“$1”已启用。",
	},
	{
		pattern: /^User "(.+)" removed successfully\.$/,
		template: "用户“$1”已移除。",
	},
	{
		pattern: /^Password for "(.+)" updated successfully\.$/,
		template: "用户“$1”的密码已更新。",
	},
	{
		pattern: /^Role for "(.+)" updated to "(.+)" successfully\.$/,
		template: "“$1”的角色已更新为“$2”。",
	},
	{
		pattern: /^"(.+)" role updated successfully\.$/,
		template: "“$1”的角色已更新。",
	},
	{
		pattern: /^"(.+)" removed successfully\.$/,
		template: "“$1”已移除。",
	},
	{
		pattern: /^(.+)'s roles have been updated\.$/,
		template: "“$1”的角色已更新。",
	},
	{
		pattern: /^OAuth2 application "(.+)" created successfully\.$/,
		template: "OAuth2 应用“$1”创建成功。",
	},
	{
		pattern: /^OAuth2 application "(.+)" revoked successfully\.$/,
		template: "OAuth2 应用“$1”已撤销。",
	},
	{
		pattern: /^Successfully updated the OAuth2 application "(.+)"\.$/,
		template: "OAuth2 应用“$1”更新成功。",
	},
	{
		pattern: /^You have successfully deleted the "(.+)" OAuth2 application\.$/,
		template: "OAuth2 应用“$1”删除成功。",
	},
	{
		pattern: /^Model "(.+)" added\.$/,
		template: "模型“$1”已添加。",
	},
	{
		pattern: /^Model "(.+)" updated\.$/,
		template: "模型“$1”已更新。",
	},
	{
		pattern: /^Model "(.+)" deleted\.$/,
		template: "模型“$1”已删除。",
	},
	{
		pattern: /^Model "(.+)" enabled\.$/,
		template: "模型“$1”已启用。",
	},
	{
		pattern: /^Model "(.+)" disabled\.$/,
		template: "模型“$1”已禁用。",
	},
	{
		pattern: /^Provider "(.+)" added\.$/,
		template: "提供商“$1”已添加。",
	},
	{
		pattern: /^Provider "(.+)" updated\.$/,
		template: "提供商“$1”已更新。",
	},
	{
		pattern: /^Provider "(.+)" deleted\.$/,
		template: "提供商“$1”已删除。",
	},
	{
		pattern: /^Provider "(.+)" enabled\.$/,
		template: "提供商“$1”已启用。",
	},
	{
		pattern: /^Provider "(.+)" disabled\.$/,
		template: "提供商“$1”已禁用。",
	},
	{
		pattern: /^MCP server "(.+)" added\.$/,
		template: "MCP 服务器“$1”已添加。",
	},
	{
		pattern: /^MCP server "(.+)" updated\.$/,
		template: "MCP 服务器“$1”已更新。",
	},
	{
		pattern: /^MCP server "(.+)" deleted\.$/,
		template: "MCP 服务器“$1”已删除。",
	},
	{
		pattern: /^MCP server "(.+)" enabled\.$/,
		template: "MCP 服务器“$1”已启用。",
	},
	{
		pattern: /^MCP server "(.+)" disabled\.$/,
		template: "MCP 服务器“$1”已禁用。",
	},
	{
		pattern: /^Permissions for "(.+)" updated\.$/,
		template: "“$1”的权限已更新。",
	},
	{
		pattern: /^Deleted AI Gateway key "(.+)" successfully\.$/,
		template: "AI Gateway 密钥“$1”删除成功。",
	},
	{
		pattern: /^Created (.+)\.$/,
		template: "已创建$1。",
	},
	{
		pattern: /^Saved (.+)\.$/,
		template: "已保存$1。",
	},
	{
		pattern: /^(.+) accepted the run\.$/,
		template: "“$1”已接受本次运行。",
	},
	{
		pattern: /^Failed to open "(.+)"\.$/,
		template: "无法打开“$1”。",
	},
	{
		pattern: /^Failed to select proxy "(.+)"\.$/,
		template: "无法选择代理“$1”。",
	},
	{
		pattern: /^Failed to rebuild devcontainer "(.+)"\.$/,
		template: "无法重新构建 devcontainer“$1”。",
	},
	{
		pattern: /^Failed to download "(.+)" logs\.$/,
		template: "下载“$1”的日志失败。",
	},
	{
		pattern: /^Error downloading workspace "(.+)" logs\.$/,
		template: "下载工作区“$1”的日志出错。",
	},
	{
		pattern: /^Unable to watch "(.+)" agent logs\.$/,
		template: "无法监视 Agent“$1”的日志。",
	},
	{
		pattern: /^Error on getting "(.+)" build logs\.$/,
		template: "获取构建“$1”的日志时出错。",
	},
	{
		pattern: /^Couldn't download (.+)$/,
		template: "无法下载$1",
	},
	{
		pattern: /^Build status is (.+)$/,
		template: "构建状态：$1",
	},
	{
		pattern: /^Checking whether (.+) is available\. Try again in a moment\.$/,
		template: "正在检查$1是否可用,请稍后重试。",
	},

	// Health check results.
	{
		pattern: /^"(.+)" is taking longer than expected$/,
		template: "“$1”耗时超出预期",
	},
	{
		pattern: /^"(.+)" failed$/,
		template: "“$1”失败",
	},
	{
		pattern: /^"(.+)" left pipes open$/,
		template: "“$1”未关闭管道",
	},

	// Specific action labels, matched before the generic verbs below.
	{
		pattern: /^Remove redirect URI (\d+)$/,
		template: "移除重定向 URI $1",
	},
	{
		pattern: /^Remove (.+) filter$/,
		template: "移除$1筛选器",
	},
	{
		pattern: /^Delete mapping for (.+)$/,
		template: "删除“$1”的映射",
	},
	{
		pattern: /^Delete (\d+) workspaces?$/,
		template: "删除 $1 个工作区",
	},
	{
		pattern: /^Stop (\d+) workspaces?$/,
		template: "停止 $1 个工作区",
	},
	{
		pattern: /^Stop in (.+)$/,
		template: "$1后停止",
	},
	{
		pattern: /^Toggle secret (.+)$/,
		template: "切换密钥 $1",
	},
	{
		pattern: /^View (.+) details$/,
		template: "查看$1详情",
	},
	{
		pattern: /^Close (.+) tab$/,
		template: "关闭$1标签页",
	},
	{
		pattern: /^Open project actions for (.+)$/,
		template: "打开项目$1的操作",
	},
	{
		pattern: /^Open actions for (.+)$/,
		template: "打开“$1”的操作",
	},
	{
		pattern: /^Open chat actions for (.+)$/,
		template: "打开“$1”的对话操作",
	},
	{
		pattern: /^Copy branch name: (.+)$/,
		template: "复制分支名：$1",
	},
	{
		pattern: /^Protocol for port (\d+)$/,
		template: "端口 $1 的协议",
	},
	{
		pattern: /^Sharing level for port (\d+)$/,
		template: "端口 $1 的共享级别",
	},
	{
		pattern: /^Account menu for (.+)$/,
		template: "$1的账户菜单",
	},
	{
		pattern: /^Notification method for (.+)$/,
		template: "$1的通知方式",
	},
	{
		pattern: /^Owned by (.+)$/,
		template: "所有者：$1",
	},
	{
		pattern: /^Run now (.+)$/,
		template: "立即运行 $1",
	},
	{
		pattern: /^Load external image from (.+)$/,
		template: "加载来自$1的外部图片",
	},
	{
		pattern: /^Create a workspace using the (.+) template$/,
		template: "使用模板$1创建工作区",
	},
	{
		pattern: /^Allow Coder Agents to create workspaces using (.+) in (.+)$/,
		template: "允许 Coder Agents 在 $2 中使用 $1 创建工作区",
	},
	{
		pattern: /^(.+) workspace menu$/,
		template: "$1的工作区菜单",
	},
	{
		pattern: /^(.+) AM or PM$/,
		template: "$1 上午或下午",
	},
	{
		pattern: /^(.+) Icon$/,
		template: "$1图标",
	},
	{
		pattern: /^(.+) information$/,
		template: "$1信息",
	},
	{
		pattern: /^(.+) price loading$/,
		template: "正在加载$1的价格",
	},
	{
		pattern: /^(.+) help$/,
		template: "$1帮助",
	},
	{
		pattern: /^(.+) \(you\)$/,
		template: "$1(你)",
	},

	// Counts and plurals.
	{
		pattern: /^\+(\d+) more roles?$/,
		template: "还有 $1 个角色",
	},
	{
		pattern: /^(\d+) more redirect URIs?$/,
		template: "还有 $1 个重定向 URI",
	},
	{
		pattern: /^(\d+) more items?$/,
		template: "还有 $1 项",
	},
	{
		pattern: /^(\d+) pull requests$/,
		template: "$1 个 Pull Request",
	},
	{
		pattern: /^([\d,]+) members?$/,
		template: "$1 名成员",
	},
	{
		pattern: /^(\d+) attachments? could not be sent \(upload failed\)$/,
		template: "$1 个附件无法发送(上传失败)",
	},
	{
		pattern: /^(\d+) workspace files? could not be sent \(upload failed\)$/,
		template: "$1 个工作区文件无法发送(上传失败)",
	},
	{
		pattern:
			/^(\d+) files? failed to upload to the workspace\. Remove or retry the failed files\.$/,
		template: "$1 个文件上传到工作区失败。请移除或重试失败的文件。",
	},
	{
		pattern: /^Omitting (\d+) pages$/,
		template: "省略了 $1 页",
	},
	{
		pattern: /^Last (\d+) days$/,
		template: "过去 $1 天",
	},
	{
		pattern: /^Unsupported file type: (.+)$/,
		template: "不支持的文件类型：$1",
	},
	{
		pattern: /^Lifecycle hook notice: (.+)$/,
		template: "生命周期钩子通知：$1",
	},
	{
		pattern: /^Disconnected (.+)\.$/,
		template: "已断开$1。",
	},
	{
		pattern: /^Port (\d+)$/,
		template: "端口 $1",
	},
	{
		pattern: /^Used by (.+)$/,
		template: "$1 人使用",
	},

	// Generic verb labels (aria labels and menu items). Exact dictionary
	// entries always win, so these only fire on interpolated labels.
	{
		pattern: /^Search (.+)…$/,
		template: "搜索$1…",
	},
	{
		pattern: /^Search (.+)$/,
		template: "搜索$1",
	},
	{
		pattern: /^Select user (.+)$/,
		template: "选择用户 $1",
	},
	{
		pattern: /^Select workspace (.+)$/,
		template: "选择工作区 $1",
	},
	{
		pattern: /^Organization (.+)$/,
		template: "组织 $1",
	},
	{
		pattern: /^Expand (.+)$/,
		template: "展开$1",
	},
	{
		pattern: /^Collapse (.+)$/,
		template: "折叠$1",
	},
	{
		pattern: /^Remove (.+)$/,
		template: "移除$1",
	},
	{
		pattern: /^Delete (.+)$/,
		template: "删除$1",
	},
	{
		pattern: /^Stop (.+)$/,
		template: "停止$1",
	},
	{
		pattern: /^Enable (.+)$/,
		template: "启用$1",
	},
	{
		pattern: /^View (.+)$/,
		template: "查看$1",
	},
	{
		pattern: /^Open (.+)$/,
		template: "打开$1",
	},
	{
		pattern: /^Download (.+)$/,
		template: "下载$1",
	},
	{
		pattern: /^Disconnect (.+)$/,
		template: "断开$1",
	},
	{
		pattern: /^Copy (.+)$/,
		template: "复制$1",
	},
	{
		pattern: /^Go to (.+)$/,
		template: "前往$1",
	},
	{
		pattern: /^Configure (.+)$/,
		template: "配置$1",
	},

	// Single-node relative-time strings. Most "Created {date}" strings are
	// split into separate text nodes and translated as fragments, with the
	// date itself localized through dayjs.
	{
		pattern: /^Version: (.+)$/,
		template: "版本：$1",
	},
	{
		pattern: /^Created (.+)$/,
		template: "创建于 $1",
	},
	{
		pattern: /^Updated (.+)$/,
		template: "更新于 $1",
	},
	{
		pattern: /^Started (.+)$/,
		template: "启动于 $1",
	},
	{
		pattern: /^Last used (.+)$/,
		template: "最近使用 $1",
	},
	{
		pattern: /^(\d+) results?$/,
		template: "$1 条结果",
	},
];

// Text that already contains Chinese cannot match an English dictionary entry;
// bailing early also guards against patterns matching their own output.
const CONTAINS_CJK = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/;

/**
 * Collapses internal whitespace so JSX text spanning multiple source lines
 * ("Are you sure you want to\n  delete this?") looks up the same dictionary
 * key as a single-line string.
 */
export function collapseWhitespace(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

export function translate(text: string): string | undefined {
	if (CONTAINS_CJK.test(text)) {
		return undefined;
	}

	const key = collapseWhitespace(text);
	if (!key) {
		return undefined;
	}

	const exact = exactMatches.get(key);
	if (exact) {
		return exact;
	}

	for (const { pattern, template } of patterns) {
		if (pattern.test(key)) {
			return key.replace(pattern, template);
		}
	}

	return undefined;
}

/**
 * Translates raw text content while preserving its leading, trailing, and
 * internal whitespace. Internal whitespace in the source may differ from the
 * collapsed dictionary key, so the key is matched with a whitespace-flexible
 * pattern.
 */
export function translateText(raw: string): string | undefined {
	const key = collapseWhitespace(raw);
	const translation = translate(raw);
	if (!key || !translation) {
		return undefined;
	}

	const flexibleKey = new RegExp(
		key
			.split(/ +/)
			.map((word) => escapeRegExp(word))
			.join("\\s+"),
	);
	return raw.replace(flexibleKey, () => translation);
}

function escapeRegExp(text: string): string {
	return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
