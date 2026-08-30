import http from '@/api/http';

export interface RegistrationValues {
    username: string;
    email: string;
    nameFirst: string;
    nameLast: string;
    password: string;
    passwordConfirmation: string;
    recaptchaData?: string;
}

export default (values: RegistrationValues) => http.post('/auth/register', {
    username: values.username,
    email: values.email,
    name_first: values.nameFirst,
    name_last: values.nameLast,
    password: values.password,
    password_confirmation: values.passwordConfirmation,
    'g-recaptcha-response': values.recaptchaData,
}).then(({ data }) => data.data as { complete: boolean; intended: string });
