import { waitFor } from "@testing-library/react";
import { afterEach } from "vitest";
import { activateDomTranslator } from "./domTranslator";

afterEach(() => {
	document.body.innerHTML = "";
});

describe("domTranslator", () => {
	it("translates static text nodes after activation", () => {
		document.body.innerHTML = "<p>Sign Out</p>";
		const deactivate = activateDomTranslator();
		expect(document.body.querySelector("p")?.textContent).toBe("退出登录");
		deactivate();
	});

	it("preserves surrounding whitespace of translated text", () => {
		document.body.innerHTML = "<p>\n\t  Sign Out  \n</p>";
		const deactivate = activateDomTranslator();
		expect(document.body.querySelector("p")?.textContent).toBe(
			"\n\t  退出登录  \n",
		);
		deactivate();
	});

	it("translates placeholder and title attributes", () => {
		document.body.innerHTML = '<input placeholder="Account" title="Account" />';
		const deactivate = activateDomTranslator();
		const input = document.body.querySelector("input");
		expect(input?.getAttribute("placeholder")).toBe("账户");
		expect(input?.getAttribute("title")).toBe("账户");
		deactivate();
	});

	it("leaves unknown text untouched", () => {
		document.body.innerHTML = "<p>random log line 42</p>";
		const deactivate = activateDomTranslator();
		expect(document.body.querySelector("p")?.textContent).toBe(
			"random log line 42",
		);
		deactivate();
	});

	it("skips code, pre, textarea, and terminal elements", () => {
		document.body.innerHTML =
			"<div><code>Sign Out</code><pre>Sign Out</pre>" +
			'<textarea>Sign Out</textarea><div class="xterm">Sign Out</div></div>';
		const deactivate = activateDomTranslator();
		expect(document.body.querySelector("code")?.textContent).toBe("Sign Out");
		expect(document.body.querySelector("pre")?.textContent).toBe("Sign Out");
		expect(document.body.querySelector("textarea")?.textContent).toBe(
			"Sign Out",
		);
		expect(document.body.querySelector(".xterm")?.textContent).toBe("Sign Out");
		deactivate();
	});

	it("translates nodes added after activation", async () => {
		document.body.innerHTML = "";
		const deactivate = activateDomTranslator();
		const p = document.createElement("p");
		p.textContent = "Sign Out";
		document.body.append(p);
		await waitFor(() => expect(p.textContent).toBe("退出登录"));
		deactivate();
	});

	it("re-translates after React overwrites a node with English", async () => {
		document.body.innerHTML = "<p>Sign Out</p>";
		const deactivate = activateDomTranslator();
		const textNode = document.body.querySelector("p")?.firstChild;
		if (!(textNode instanceof Text)) {
			throw new Error("text node not found");
		}
		// Simulate React re-rendering a changed value into the same node.
		textNode.nodeValue = "Account";
		await waitFor(() => expect(textNode.nodeValue).toBe("账户"));
		deactivate();
	});

	it("is idempotent for repeated activation", () => {
		document.body.innerHTML = "<p>Sign Out</p>";
		const deactivate = activateDomTranslator();
		expect(document.body.querySelector("p")?.textContent).toBe("退出登录");
		deactivate();
	});

	it("stops translating after deactivation", async () => {
		document.body.innerHTML = "";
		const deactivate = activateDomTranslator();
		deactivate();
		const p = document.createElement("p");
		p.textContent = "Sign Out";
		document.body.append(p);
		await Promise.resolve();
		expect(p.textContent).toBe("Sign Out");
	});
});
