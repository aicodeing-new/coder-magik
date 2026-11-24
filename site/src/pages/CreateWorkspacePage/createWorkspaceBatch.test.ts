import { API } from "#/api/api";
import { MockWorkspace } from "#/testHelpers/entities";
import { batchIdParameter, createWorkspaceBatch } from "./createWorkspaceBatch";

const request = {
	name: "aitest",
	rich_parameter_values: [{ name: "machine_count", value: "2" }],
};

const missing = { isAxiosError: true, response: { status: 404 } };

afterEach(() => vi.restoreAllMocks());

it("checks the last name for conflicts before creating the first workspace", async () => {
	vi.spyOn(API, "getWorkspaceByOwnerAndName")
		.mockRejectedValueOnce(missing)
		.mockResolvedValueOnce(MockWorkspace);
	vi.spyOn(API, "getWorkspaceBuildParameters").mockResolvedValue([]);
	const create = vi.spyOn(API, "createWorkspace");
	await expect(createWorkspaceBatch(request, "owner", "group")).rejects.toThrow(
		"aitest-2 already exists",
	);
	expect(create).not.toHaveBeenCalled();
});

it("resumes after a partial creation without resubmitting the confirmed workspace", async () => {
	const lookup = vi
		.spyOn(API, "getWorkspaceByOwnerAndName")
		.mockRejectedValue(missing);
	const create = vi
		.spyOn(API, "createWorkspace")
		.mockResolvedValueOnce(MockWorkspace)
		.mockRejectedValueOnce(new Error("disconnected"));
	await expect(createWorkspaceBatch(request, "owner", "group")).rejects.toThrow(
		"Confirmed workspaces: aitest-1",
	);
	lookup.mockResolvedValueOnce(MockWorkspace);
	vi.spyOn(API, "getWorkspaceBuildParameters").mockResolvedValue([
		{ name: batchIdParameter, value: "group" },
	]);
	create.mockResolvedValue(MockWorkspace);
	await createWorkspaceBatch(request, "owner", "group");
	expect(create.mock.calls.map(([, req]) => req.name)).toEqual([
		"aitest-1",
		"aitest-2",
		"aitest-2",
	]);
});
