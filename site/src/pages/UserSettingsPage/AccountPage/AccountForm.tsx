import { type FormikTouched, useFormik } from "formik";
import * as Yup from "yup";
import type { UpdateUserProfileRequest } from "#/api/typesGenerated";
import { ErrorAlert } from "#/components/Alert/ErrorAlert";
import { Button } from "#/components/Button/Button";
import { Form, FormFields } from "#/components/Form/Form";
import { FormField } from "#/components/FormField/FormField";
import { Spinner } from "#/components/Spinner/Spinner";
import {
	getFormHelpers,
	nameValidator,
	onChangeTrimmed,
} from "#/utils/formUtils";

// The reserved ".invalid" TLD marks placeholder addresses minted by identity
// providers that have no real mailbox for the user.
const isPlaceholderEmail = (email: string) =>
	email.trim().toLowerCase().endsWith(".invalid");

type AccountFormProps = {
	editable: boolean;
	emailEditable: boolean;
	isLoading: boolean;
	initialValues: UpdateUserProfileRequest;
	onSubmit: (values: UpdateUserProfileRequest) => void;
	updateProfileError?: unknown;
	// initialTouched is only used for testing the error state of the form.
	initialTouched?: FormikTouched<UpdateUserProfileRequest>;
};

export const AccountForm: React.FC<AccountFormProps> = ({
	editable,
	emailEditable,
	isLoading,
	onSubmit,
	initialValues,
	updateProfileError,
	initialTouched,
}) => {
	const validationSchema = Yup.object({
		username: nameValidator("Username"),
		name: Yup.string(),
		email: emailEditable
			? Yup.string()
					.email("Email must be a valid email address.")
					.required("Email is required.")
			: Yup.string(),
	});

	const form = useFormik({
		initialValues,
		validationSchema,
		onSubmit,
		initialTouched,
	});
	const getFieldHelpers = getFormHelpers(form, updateProfileError);

	// getFormHelpers carries validation errors in helperText, so the hint is
	// only applied when there is nothing to display.
	const emailHelpers = getFieldHelpers("email");
	const emailHint =
		emailEditable && isPlaceholderEmail(form.values.email ?? "")
			? "Your account uses a placeholder email address. Enter your real email to receive notifications."
			: undefined;

	return (
		<Form onSubmit={form.handleSubmit}>
			<FormFields>
				{Boolean(updateProfileError) && (
					<ErrorAlert error={updateProfileError} />
				)}

				<FormField
					field={{
						...emailHelpers,
						helperText: emailHelpers.helperText ?? emailHint,
					}}
					onChange={onChangeTrimmed(form)}
					autoComplete="email"
					aria-disabled={!emailEditable}
					disabled={!emailEditable}
					className="w-full"
					label="Email"
				/>
				<FormField
					field={getFieldHelpers("username")}
					onChange={onChangeTrimmed(form)}
					aria-disabled={!editable}
					autoComplete="username"
					disabled={!editable}
					className="w-full"
					label="Username"
				/>
				<FormField
					field={{
						...getFieldHelpers("name"),
						helperText:
							'The human-readable name is optional and can be accessed in a template via the "data.coder_workspace_owner.me.full_name" property.',
					}}
					autoComplete="name"
					className="w-full"
					label="Name"
					onBlur={(event) => {
						event.target.value = event.target.value.trim();
						form.handleChange(event);
					}}
				/>
				<div>
					<Button disabled={isLoading} type="submit">
						<Spinner loading={isLoading} />
						Update account
					</Button>
				</div>
			</FormFields>
		</Form>
	);
};
