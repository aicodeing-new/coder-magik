import { API } from "#/api/api";
import {
	DetailedError,
	getErrorMessage,
	isWorkspaceNotFound,
} from "#/api/errors";
import type { CreateWorkspaceRequest } from "#/api/typesGenerated";

export const batchIdParameter = "workspace_batch_id";

export async function createWorkspaceBatch(
	request: CreateWorkspaceRequest,
	ownerId: string,
	batchId: string,
) {
	const parameters = request.rich_parameter_values ?? [];
	const count = Number(
		parameters.find((p) => p.name === "machine_count")?.value,
	);
	if (!Number.isInteger(count) || count < 2 || count > 4) {
		throw new Error("Choose between two and four workspaces.");
	}
	if (request.name.length > 30) {
		throw new Error(
			"Use a base name of at most 30 characters to leave room for the numbered suffix.",
		);
	}
	const names = Array.from(
		{ length: count },
		(_, i) => `${request.name}-${i + 1}`,
	);
	const pending: string[] = [];
	const completed: string[] = [];
	// Check every name before creating anything. A retry may find members
	// already created by this submission, including after a lost POST response.
	for (const name of names) {
		const existing = await API.getWorkspaceByOwnerAndName(ownerId, name).catch(
			(error: unknown) => {
				if (isWorkspaceNotFound(error)) return undefined;
				throw error;
			},
		);
		if (!existing) {
			pending.push(name);
			continue;
		}
		const values = await API.getWorkspaceBuildParameters(
			existing.latest_build.id,
		);
		if (
			!values.some((p) => p.name === batchIdParameter && p.value === batchId)
		) {
			throw new Error(
				`Workspace ${name} already exists. Choose another base name.`,
			);
		}
		completed.push(name);
	}
	for (const name of pending) {
		try {
			await API.createWorkspace(ownerId, {
				...request,
				name,
				rich_parameter_values: [
					...parameters.filter((p) => p.name !== batchIdParameter),
					{ name: batchIdParameter, value: batchId },
				],
			});
			completed.push(name);
		} catch (error) {
			throw new DetailedError(
				`Could not confirm creation of ${name}. Confirmed workspaces: ${completed.join(", ") || "none"}. Retry this form to continue.`,
				getErrorMessage(
					error,
					error instanceof Error ? error.message : "Workspace creation failed.",
				),
			);
		}
	}
}
