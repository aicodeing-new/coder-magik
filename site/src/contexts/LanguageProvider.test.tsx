import { render, screen, waitFor } from "@testing-library/react";
import { afterEach } from "vitest";
import { LANGUAGE_STORAGE_KEY } from "#/i18n/language";
import { LanguageProvider } from "./LanguageProvider";

afterEach(() => {
	window.localStorage.removeItem(LANGUAGE_STORAGE_KEY);
});

describe("LanguageProvider", () => {
	it("activates the DOM translator in Chinese mode", async () => {
		window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "zh");
		render(
			<LanguageProvider>
				<p>Sign Out</p>
			</LanguageProvider>,
		);
		await waitFor(() => screen.getByText("退出登录"));
	});

	it("leaves the DOM untouched in English mode", async () => {
		window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "en");
		render(
			<LanguageProvider>
				<p>Sign Out</p>
			</LanguageProvider>,
		);
		await Promise.resolve();
		screen.getByText("Sign Out");
	});

	it("stops translating after unmount", async () => {
		window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "zh");
		const { unmount } = render(
			<LanguageProvider>
				<p>Sign Out</p>
			</LanguageProvider>,
		);
		await waitFor(() => screen.getByText("退出登录"));
		unmount();

		const paragraph = document.createElement("p");
		paragraph.textContent = "Sign Out";
		document.body.append(paragraph);
		await Promise.resolve();
		expect(paragraph.textContent).toBe("Sign Out");
		paragraph.remove();
	});
});
