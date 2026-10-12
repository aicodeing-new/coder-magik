import { afterEach } from "vitest";
import { collapseWhitespace, translate, translateText } from "./dictionary";
import { LANGUAGE_STORAGE_KEY } from "./language";

afterEach(() => {
	window.localStorage.removeItem(LANGUAGE_STORAGE_KEY);
});

describe("collapseWhitespace", () => {
	it("collapses internal whitespace and trims", () => {
		expect(
			collapseWhitespace("  Are you sure you want to\n\t delete this?  "),
		).toBe("Are you sure you want to delete this?");
	});
});

describe("translate", () => {
	it("translates exact dictionary matches", () => {
		expect(translate("Sign Out")).toBe("退出登录");
	});

	it("matches keys with different internal whitespace", () => {
		expect(translate("Sign\tOut")).toBe("退出登录");
	});

	it("returns undefined for unknown text", () => {
		expect(translate("an unknown log message")).toBeUndefined();
	});

	it("returns undefined for text that already contains Chinese", () => {
		expect(translate("Sign Out 已翻译")).toBeUndefined();
	});

	it("translates interpolated strings via patterns", () => {
		expect(translate("Version: v2.38.0")).toBe("版本：v2.38.0");
		expect(translate("Stop in 8 hours")).toBe("8 hours后停止");
	});

	it("translates confirmation and toast patterns", () => {
		expect(
			translate(
				'Are you sure you want to stop the workspace "my-workspace"? This will terminate all running processes and disconnect any active sessions.',
			),
		).toBe(
			"确定要停止工作区“my-workspace”吗?这将终止所有运行中的进程并断开所有活动连接。",
		);
		expect(translate('Template "gpu" updated successfully.')).toBe(
			"模板“gpu”更新成功。",
		);
		expect(translate("View build logs")).toBe("查看build logs");
	});

	it("prefers specific patterns over generic verbs", () => {
		expect(translate("Remove redirect URI 2")).toBe("移除重定向 URI 2");
		expect(translate("Remove engineering")).toBe("移除engineering");
	});

	it("does not re-match pattern output", () => {
		const once = translate("Stop in 8 hours");
		if (!once) {
			throw new Error("expected a translation");
		}
		expect(translate(once)).toBeUndefined();
	});
});

describe("translateText", () => {
	it("preserves leading and trailing whitespace", () => {
		expect(translateText("\n  Sign Out  ")).toBe("\n  退出登录  ");
	});

	it("preserves irregular internal whitespace", () => {
		expect(translateText("Sign\n\tOut")).toBe("退出登录");
	});

	it("returns undefined for whitespace-only text", () => {
		expect(translateText("   ")).toBeUndefined();
	});
});
