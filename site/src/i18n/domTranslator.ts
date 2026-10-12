import { translateText } from "./dictionary";

// Elements whose text content is user or machine data (code, terminal output,
// editor buffers) rather than UI copy.
const SKIPPED_TAGS = new Set([
	"SCRIPT",
	"STYLE",
	"NOSCRIPT",
	"CODE",
	"PRE",
	"TEXTAREA",
	"KBD",
	"SAMP",
	"VAR",
]);

const SKIPPED_SELECTOR =
	'[data-no-translate], .xterm, .monaco-editor, [contenteditable="true"]';

const TRANSLATED_ATTRIBUTES = [
	"placeholder",
	"title",
	"aria-label",
	"aria-placeholder",
] as const;

let observer: MutationObserver | undefined;

/**
 * Translates the current DOM from English to Chinese and keeps translating
 * as React re-renders nodes. Strings stay English in the source; React owns
 * the DOM and only writes values it re-renders, so translated text persists
 * until React replaces it, at which point the mutation observer translates
 * the new value. Returns a deactivation function.
 */
export function activateDomTranslator(): () => void {
	if (observer) {
		return deactivate;
	}

	translateSubtree(document.body);
	observer = new MutationObserver(onMutations);
	observer.observe(document.body, {
		attributes: true,
		attributeFilter: [...TRANSLATED_ATTRIBUTES],
		characterData: true,
		childList: true,
		subtree: true,
	});
	return deactivate;
}

function deactivate() {
	observer?.disconnect();
	observer = undefined;
}

function onMutations(mutations: MutationRecord[]) {
	for (const mutation of mutations) {
		if (mutation.type === "characterData") {
			if (mutation.target instanceof Text) {
				translateTextNode(mutation.target);
			}
			continue;
		}

		if (mutation.type === "attributes") {
			if (mutation.target instanceof Element) {
				translateElementAttributes(mutation.target);
			}
			continue;
		}

		for (const node of mutation.addedNodes) {
			if (node instanceof Text) {
				translateTextNode(node);
			} else if (node instanceof Element) {
				translateSubtree(node);
			}
		}
	}
}

function isSkipped(element: Element): boolean {
	return (
		SKIPPED_TAGS.has(element.tagName) ||
		element.closest(SKIPPED_SELECTOR) !== null
	);
}

function translateSubtree(root: Element) {
	if (isSkipped(root)) {
		return;
	}

	translateElementAttributes(root);
	const walker = document.createTreeWalker(
		root,
		NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT,
		{
			acceptNode: (node) =>
				node instanceof Element && isSkipped(node)
					? NodeFilter.FILTER_REJECT
					: NodeFilter.FILTER_ACCEPT,
		},
	);

	let node = walker.nextNode();
	while (node) {
		if (node instanceof Text) {
			translateTextNode(node);
		} else if (node instanceof Element) {
			translateElementAttributes(node);
		}
		node = walker.nextNode();
	}
}

function translateTextNode(node: Text) {
	const raw = node.nodeValue ?? "";
	if (raw.trim() === "") {
		return;
	}

	const translated = translateText(raw);
	if (translated && translated !== raw) {
		node.nodeValue = translated;
	}
}

function translateElementAttributes(element: Element) {
	for (const attribute of TRANSLATED_ATTRIBUTES) {
		const value = element.getAttribute(attribute);
		if (!value) {
			continue;
		}

		const translated = translateText(value);
		if (translated && translated !== value) {
			element.setAttribute(attribute, translated);
		}
	}
}
