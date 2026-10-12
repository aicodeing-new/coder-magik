import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { UpdateUserProfileRequest } from "#/api/typesGenerated";
import { MockUserMember } from "#/testHelpers/entities";
import { render } from "#/testHelpers/renderHelpers";
import { AccountForm } from "./AccountForm";

// NOTE: it does not matter what the role props of MockUser are set to,
//       only that editable is set to true or false. This is passed from
//       the call to /authorization done by auth provider
describe("AccountForm", () => {
	const mockInitialValues: UpdateUserProfileRequest = {
		username: MockUserMember.username,
		name: MockUserMember.name ?? MockUserMember.username,
		email: MockUserMember.email,
		avatar_url: MockUserMember.avatar_url ?? "",
	};

	describe("when editable is set to true", () => {
		it("allows updating username", async () => {
			// When
			render(
				<AccountForm
					editable
					emailEditable={false}
					initialValues={mockInitialValues}
					isLoading={false}
					onSubmit={vi.fn()}
				/>,
			);

			// Then
			const el = await screen.findByLabelText("Username");
			expect(el).toBeEnabled();
			const btn = await screen.findByRole("button", {
				name: /Update account/i,
			});
			expect(btn).toBeEnabled();
		});
	});

	it("sets name autocomplete to name", async () => {
		// When
		render(
			<AccountForm
				editable
				emailEditable={false}
				initialValues={mockInitialValues}
				isLoading={false}
				onSubmit={vi.fn()}
			/>,
		);

		// Then
		const nameInput = await screen.findByLabelText("Name");
		expect(nameInput).toHaveAttribute("autocomplete", "name");
	});
	describe("when editable is set to false", () => {
		it("does not allow updating username", async () => {
			// When
			render(
				<AccountForm
					editable={false}
					emailEditable={false}
					initialValues={mockInitialValues}
					isLoading={false}
					onSubmit={vi.fn()}
				/>,
			);

			// Then
			const el = await screen.findByLabelText("Username");
			expect(el).toBeDisabled();
		});
	});

	describe("when emailEditable is set to false", () => {
		it("does not allow updating email", async () => {
			// When
			render(
				<AccountForm
					editable
					emailEditable={false}
					initialValues={mockInitialValues}
					isLoading={false}
					onSubmit={vi.fn()}
				/>,
			);

			// Then
			const el = await screen.findByLabelText("Email");
			expect(el).toBeDisabled();
		});
	});

	describe("when emailEditable is set to true", () => {
		it("submits the completed email", async () => {
			// Given
			const onSubmit = vi.fn();
			const user = userEvent.setup();
			render(
				<AccountForm
					editable
					emailEditable
					initialValues={{
						...mockInitialValues,
						email: "ou_test@feishu.invalid",
					}}
					isLoading={false}
					onSubmit={onSubmit}
				/>,
			);

			// When
			const emailInput = await screen.findByLabelText("Email");
			expect(emailInput).toBeEnabled();
			expect(
				await screen.findByText(
					"Your account uses a placeholder email address. Enter your real email to receive notifications.",
				),
			).toBeDefined();
			await user.clear(emailInput);
			await user.type(emailInput, "zhangsan@example.com");
			await user.click(screen.getByRole("button", { name: /Update account/i }));

			// Then
			expect(onSubmit).toBeCalledTimes(1);
			expect(onSubmit).toBeCalledWith(
				expect.objectContaining({
					...mockInitialValues,
					email: "zhangsan@example.com",
				}),
				expect.anything(),
			);
		});

		it("rejects an invalid email", async () => {
			// Given
			const onSubmit = vi.fn();
			const user = userEvent.setup();
			render(
				<AccountForm
					editable
					emailEditable
					initialValues={mockInitialValues}
					isLoading={false}
					onSubmit={onSubmit}
				/>,
			);

			// When
			const emailInput = await screen.findByLabelText("Email");
			await user.clear(emailInput);
			await user.type(emailInput, "not-an-email");
			await user.click(screen.getByRole("button", { name: /Update account/i }));

			// Then
			expect(
				await screen.findByText("Email must be a valid email address."),
			).toBeDefined();
			expect(onSubmit).not.toBeCalled();
		});
	});
});
