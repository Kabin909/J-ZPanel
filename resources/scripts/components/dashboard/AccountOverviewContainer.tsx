import * as React from 'react';
import ContentBox from '@/components/elements/ContentBox';
import UpdatePasswordForm from '@/components/dashboard/forms/UpdatePasswordForm';
import UpdateEmailAddressForm from '@/components/dashboard/forms/UpdateEmailAddressForm';
import ConfigureTwoFactorForm from '@/components/dashboard/forms/ConfigureTwoFactorForm';
import PageContentBlock from '@/components/elements/PageContentBlock';
import tw from 'twin.macro';
import { breakpoint } from '@/theme';
import styled from 'styled-components/macro';
import MessageBox from '@/components/MessageBox';
import { useLocation } from 'react-router-dom';
import { useTheme, ThemeMode } from '@/components/ThemeProvider';

const Container = styled.div`
    ${tw`flex flex-wrap`};

    & > div {
        ${tw`w-full`};

        ${breakpoint('sm')`
      width: calc(50% - 1rem);
    `}

        ${breakpoint('md')`
      ${tw`w-auto flex-1`};
    `}
    }
`;

export default () => {
    const { mode, setMode } = useTheme();
    const { state } = useLocation<undefined | { twoFactorRedirect?: boolean }>();

    return (
        <PageContentBlock title={'Account Overview'}>
            {state?.twoFactorRedirect && (
                <MessageBox title={'2-Factor Required'} type={'error'}>
                    Your account must have two-factor authentication enabled in order to continue.
                </MessageBox>
            )}

            <Container css={[tw`lg:grid lg:grid-cols-3 mb-10`, state?.twoFactorRedirect ? tw`mt-4` : tw`mt-10`]}>
                <ContentBox title={'Update Password'} showFlashes={'account:password'}>
                    <UpdatePasswordForm />
                </ContentBox>
                <ContentBox css={tw`mt-8 sm:mt-0 sm:ml-8`} title={'Update Email Address'} showFlashes={'account:email'}>
                    <UpdateEmailAddressForm />
                </ContentBox>
                <ContentBox css={tw`md:ml-8 mt-8 md:mt-0`} title={'Two-Step Verification'}>
                    <ConfigureTwoFactorForm />
                </ContentBox>
                <ContentBox css={tw`md:ml-8 mt-8`} title={'Appearance'}>
                    <p css={tw`text-sm mb-4`} style={{ color: 'var(--jz-muted)' }}>Choose how J&Z Panel looks on this device.</p>
                    <div css={tw`grid grid-cols-3 gap-2`}>
                        {(['dark', 'light', 'system'] as ThemeMode[]).map((value) => (
                            <button key={value} type={'button'} onClick={() => setMode(value)} css={tw`py-2 px-3 rounded border text-sm capitalize`} style={{ color: 'var(--jz-text)', background: mode === value ? 'var(--jz-surface-2)' : 'transparent', borderColor: mode === value ? 'var(--jz-primary)' : 'var(--jz-border)' }}>
                                {value}
                            </button>
                        ))}
                    </div>
                </ContentBox>
            </Container>
        </PageContentBlock>
    );
};
