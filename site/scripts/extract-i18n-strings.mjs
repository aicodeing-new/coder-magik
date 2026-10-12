#!/usr/bin/env node
/**
 * Extracts user-facing English strings from site/src so they can be
 * translated into the runtime dictionary at src/i18n/zh-CN.ts. See
 * src/i18n/README.md for the full workflow.
 *
 * Usage: node scripts/extract-i18n-strings.mjs [outputDir]
 * Writes extracted-strings.json (all strings with occurrences) and
 * extracted-strings.txt (one string per line, sorted) into outputDir.
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import * as ts from "typescript";

const siteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const srcRoot = path.join(siteRoot, "src");
const outputDir = process.argv[2] ?? "/tmp/i18n-extract";

/** Attribute and object-literal keys whose string values render as UI copy. */
const TEXT_KEYS = new Set([
	"label",
	"title",
	"description",
	"placeholder",
	"helperText",
	"tooltip",
	"alt",
	"subtitle",
	"caption",
	"summary",
	"confirmTitle",
	"confirmMessage",
	"emptyMessage",
	"emptyTitle",
	"header",
	"heading",
	"breadcrumb",
	"aria-label",
	"aria-placeholder",
	"aria-description",
]);

/** Toast and notification helpers whose first argument is user-facing. */
const MESSAGE_FUNCTIONS = new Set([
	"displayError",
	"displaySuccess",
	"displayWarning",
	"displayMessage",
]);

/** Single words that are sentence fragments, never translated alone. */
const STOPWORDS = new Set([
	"a", "an", "the", "and", "or", "of", "to", "in", "on", "at", "by", "for",
	"with", "from", "into", "is", "are", "was", "were", "be", "been", "it",
	"its", "this", "that", "these", "those", "your", "you", "we", "not", "no",
	"ago", "via", "per", "as", "if", "then", "else", "will", "can", "all",
	"any", "out", "up", "down", "off", "over", "under", "new", "old",
]);

const isTestArtifact = (filePath) =>
	/\.test\.(ts|tsx)$/.test(filePath) ||
	/\.spec\.(ts|tsx)$/.test(filePath) ||
	/\.stories\.tsx$/.test(filePath) ||
	/\.d\.ts$/.test(filePath);

function walk(current, filePath, visit) {
	for (const child of current.getChildren()) {
		visit(child);
		walk(child, filePath, visit);
	}
}

const literalText = (node) =>
	ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)
		? node.text
		: undefined;

const collapse = (text) => text.replace(/\s+/g, " ").trim();

const isTranslatable = (text) => {
	if (!text || !/[A-Za-z]/.test(text)) return false;
	if (text.length > 400) return false;
	// URLs, emails, and identifier-ish values are not UI copy.
	if (/^(https?:)?\/\//.test(text) || /\S+@\S+\.\S+/.test(text)) return false;
	if (/^[a-z0-9_.:/-]+$/i.test(text) && !/\s/.test(text) && !/[A-Z]/.test(text)) {
		return false;
	}
	const words = text.split(" ");
	if (words.length === 1 && STOPWORDS.has(text.toLowerCase())) return false;
	return true;
};

const strings = new Map();
const patterns = new Map();

function addString(text, filePath) {
	const key = collapse(text);
	if (!isTranslatable(key)) return;
	const entry = strings.get(key) ?? { count: 0, files: new Set() };
	entry.count += 1;
	entry.files.add(path.relative(siteRoot, filePath));
	strings.set(key, entry);
}

function addPattern(sourceText, filePath) {
	patterns.set(sourceText, {
		source: sourceText,
		file: path.relative(siteRoot, filePath),
	});
}

function collectFromFile(filePath) {
	const sourceText = fs.readFileSync(filePath, "utf8");
	const sourceFile = ts.createSourceFile(
		filePath,
		sourceText,
		ts.ScriptTarget.Latest,
		true,
		filePath.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
	);

	walk(sourceFile, filePath, (node) => {
		// <p>Some text</p>
		if (ts.isJsxText(node)) {
			addString(node.text, filePath);
			return;
		}

		// label="Some text" or helperText={`Some text`}
		if (ts.isJsxAttribute(node)) {
			const name = node.name.getText().replace(/^["']|["']$/g, "");
			if (TEXT_KEYS.has(name) && node.initializer) {
				const text = literalText(node.initializer);
				if (text !== undefined) {
					addString(text, filePath);
				} else if (ts.isTemplateExpression(node.initializer)) {
					addPattern(node.initializer.getText(), filePath);
				} else if (ts.isJsxExpression(node.initializer)) {
					const inner = node.initializer.expression;
					if (inner) {
						const text = literalText(inner);
						if (text !== undefined) addString(text, filePath);
						if (ts.isTemplateExpression(inner)) {
							addPattern(inner.getText(), filePath);
						}
					}
				}
			}
			return;
		}

		// {"Some text"} and {condition ? "Yes" : "No"}
		if (ts.isConditionalExpression(node)) {
			for (const branch of [node.whenTrue, node.whenFalse]) {
				if (ts.isStringLiteral(branch) || ts.isNoSubstitutionTemplateLiteral(branch)) {
					addString(branch.text, filePath);
				}
			}
			return;
		}

		// { label: "Some text" } in navigation and option configs.
		if (ts.isPropertyAssignment(node)) {
			const name = node.name.getText().replace(/^["']|["']$/g, "");
			if (TEXT_KEYS.has(name)) {
				const text = literalText(node.initializer);
				if (text !== undefined) {
					addString(text, filePath);
				} else if (ts.isTemplateExpression(node.initializer)) {
					addPattern(node.initializer.getText(), filePath);
				}
			}
			return;
		}

		// toast.success("...") / displayError("...")
		if (ts.isCallExpression(node)) {
			const expression = node.expression;
			const isToast =
				ts.isPropertyAccessExpression(expression) &&
				ts.isIdentifier(expression.expression) &&
				expression.expression.text === "toast" &&
				["success", "error", "warning", "info", "message", "loading"].includes(
					expression.name.text,
				);
			const isDisplayFn =
				ts.isIdentifier(expression) && MESSAGE_FUNCTIONS.has(expression.text);
			if ((isToast || isDisplayFn) && node.arguments.length > 0) {
				const first = node.arguments[0];
				const text = literalText(first);
				if (text !== undefined) {
					addString(text, filePath);
				} else if (ts.isTemplateExpression(first)) {
					addPattern(first.getText(), filePath);
				}
			}
		}
	});
}

function collectFiles(dir) {
	const files = [];
	for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
		const fullPath = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			if (entry.name === "i18n" || entry.name.startsWith(".")) continue;
			files.push(...collectFiles(fullPath));
		} else if (/\.(ts|tsx)$/.test(entry.name) && !isTestArtifact(fullPath)) {
			files.push(fullPath);
		}
	}
	return files;
}

fs.mkdirSync(outputDir, { recursive: true });
const files = collectFiles(srcRoot);
for (const file of files) {
	collectFromFile(file);
}

const sorted = [...strings.entries()]
	.map(([key, { count, files: sourceFiles }]) => ({
		key,
		count,
		files: [...sourceFiles].slice(0, 4),
	}))
	.sort((a, b) => a.key.localeCompare(b.key));

fs.writeFileSync(
	path.join(outputDir, "extracted-strings.json"),
	`${JSON.stringify(
		{ total: sorted.length, strings: sorted },
		null,
		"\t",
	)}\n`,
);

fs.writeFileSync(
	path.join(outputDir, "extracted-strings.txt"),
	`${sorted.map((entry) => JSON.stringify(entry.key)).join("\n")}\n`,
);

fs.writeFileSync(
	path.join(outputDir, "pattern-candidates.json"),
	`${JSON.stringify([...patterns.values()], null, "\t")}\n`,
);

console.log(
	`Extracted ${sorted.length} distinct strings and ${patterns.size} pattern candidates from ${files.length} files into ${outputDir}`,
);
