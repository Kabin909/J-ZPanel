import React, { useEffect, useRef, useState } from 'react';
import { Link, RouteComponentProps } from 'react-router-dom';
import register from '@/api/auth/register';
import LoginFormContainer from '@/components/auth/LoginFormContainer';
import { useStoreState } from 'easy-peasy';
import { Formik, FormikHelpers } from 'formik';
import { object, ref, string } from 'yup';
import Field from '@/components/elements/Field';
import tw from 'twin.macro';
import Button from '@/components/elements/Button';
import Reaptcha from 'reaptcha';
import useFlash from '@/plugins/useFlash';

interface Values { username: string; email: string; nameFirst: string; nameLast: string; password: string; passwordConfirmation: string; }

const strength = (value: string) => {
    let score = 0;
    if (value.length >= 12) score++;
    if (/[a-z]/.test(value) && /[A-Z]/.test(value)) score++;
    if (/\d/.test(value)) score++;
    if (/[^A-Za-z0-9]/.test(value)) score++;
    return score;
};

export default ({ history }: RouteComponentProps) => {
    const refCaptcha = useRef<Reaptcha>(null);
    const [token, setToken] = useState('');
    const { clearFlashes, clearAndAddHttpError } = useFlash();
    const { enabled: recaptchaEnabled, siteKey } = useStoreState((state) => state.settings.data!.recaptcha);

    useEffect(() => { clearFlashes(); }, []);

    const onSubmit = (values: Values, { setSubmitting }: FormikHelpers<Values>) => {
        clearFlashes();
        if (recaptchaEnabled && !token) {
            refCaptcha.current!.execute().catch((error) => { setSubmitting(false); clearAndAddHttpError({ error }); });
            return;
        }
        register({ ...values, recaptchaData: token })
            .then((response) => { if (response.complete) window.location.href = response.intended || '/'; })
            .catch((error) => { setToken(''); refCaptcha.current?.reset(); setSubmitting(false); clearAndAddHttpError({ error }); });
    };

    return <Formik onSubmit={onSubmit} initialValues={{ username: '', email: '', nameFirst: '', nameLast: '', password: '', passwordConfirmation: '' }} validationSchema={object({
        username: string().required('A username is required.'), email: string().email().required('An email is required.'), nameFirst: string().required('First name is required.'), nameLast: string().required('Last name is required.'),
        password: string().min(12, 'Use at least 12 characters.').required('A password is required.'), passwordConfirmation: string().oneOf([ref('password')], 'Passwords must match.').required('Please confirm your password.'),
    })}>{({ isSubmitting, values, setSubmitting, submitForm }) => <LoginFormContainer title={'Create your account'}>
        <div css={tw`grid grid-cols-1 sm:grid-cols-2 gap-4`}><Field light type="text" label="First name" name="nameFirst" disabled={isSubmitting} /><Field light type="text" label="Last name" name="nameLast" disabled={isSubmitting} /></div>
        <div css={tw`mt-4`}><Field light type="text" label="Username" name="username" disabled={isSubmitting} /></div>
        <div css={tw`mt-4`}><Field light type="email" label="Email" name="email" disabled={isSubmitting} /></div>
        <div css={tw`mt-4`}><Field light type="password" label="Password" name="password" disabled={isSubmitting} /></div>
        <div style={{ marginTop: 8 }}><div style={{ display: 'flex', gap: 4 }}>{[1,2,3,4].map((n) => <span key={n} style={{ height: 4, flex: 1, borderRadius: 99, background: strength(values.password) >= n ? 'var(--jz-primary)' : 'var(--jz-surface-2)' }} />)}</div><small style={{ color: 'var(--jz-muted)' }}>Use 12+ characters with upper/lowercase letters and numbers.</small></div>
        <div css={tw`mt-4`}><Field light type="password" label="Confirm password" name="passwordConfirmation" disabled={isSubmitting} /></div>
        <div css={tw`mt-6`}><Button type="submit" size="xlarge" isLoading={isSubmitting} disabled={isSubmitting}>Create Account</Button></div>
        {recaptchaEnabled && <Reaptcha ref={refCaptcha} size="invisible" sitekey={siteKey || '_invalid_key'} onVerify={(response) => { setToken(response); submitForm(); }} onExpire={() => { setSubmitting(false); setToken(''); }} />}
        <div css={tw`mt-5 text-center text-sm`}><span style={{ color: 'var(--jz-muted)' }}>Already have an account? </span><Link to="/auth/login" style={{ color: 'var(--jz-primary)' }}>Sign in</Link></div>
    </LoginFormContainer>}</Formik>;
};
