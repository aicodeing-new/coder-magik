import type { Meta, StoryObj } from "@storybook/react-vite";
import { mockApiError } from "#/testHelpers/entities";
import { AccountForm } from "./AccountForm";

const meta: Meta<typeof AccountForm> = {
	title: "pages/UserSettingsPage/AccountForm",
	component: AccountForm,
	args: {
		isLoading: false,
		initialValues: {
			username: "test-user",
			name: "Test User",
			email: "test-user@org.com",
			avatar_url: "",
		},
		updateProfileError: undefined,
	},
};

export default meta;
type Story = StoryObj<typeof AccountForm>;

export const Example: Story = {};

export const Loading: Story = {
	args: {
		isLoading: true,
	},
};

export const WithError: Story = {
	args: {
		updateProfileError: mockApiError({
			message: "Username is invalid",
			validations: [
				{
					field: "username",
					detail: "Username is too long.",
				},
			],
		}),
		initialTouched: {
			username: true,
		},
	},
};

export const Editable: Story = {
	args: {
		editable: true,
	},
};

export const EditableEmail: Story = {
	args: {
		editable: true,
		emailEditable: true,
		initialValues: {
			username: "test-user",
			name: "Test User",
			email: "ou_test@feishu.invalid",
			avatar_url: "",
		},
	},
};
