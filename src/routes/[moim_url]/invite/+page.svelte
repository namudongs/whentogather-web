<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabaseClient';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { fade, fly } from 'svelte/transition';
	import type { SocialLoadingState } from '$lib/types';
	import Logo from '$lib/components/Logo.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';

	// URL 파라미터에서 초대 코드를 추출 (파일 이름은 [moim_url].svelte 내에 invite 폴더)
	let inviteCode = '';
	$: inviteCode = $page.params.moim_url;

	let loading = true;
	let errorMessage = '';
	let socialLoading: SocialLoadingState = {
		google: false,
		kakao: false,
		apple: false
	};

	// 페이지 로드시 로그인 여부 확인: 로그인 상태라면 바로 모임에 참여
	onMount(async () => {
		try {
			const {
				data: { session }
			} = await supabase.auth.getSession();
			if (session) {
				await joinMoimByInviteCode(inviteCode);
				goto(`/${inviteCode}`);
			}
		} catch (err: any) {
			errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	});

	// 소셜 로그인 함수들 (Google, Kakao, Apple)
	async function loginWithKakao() {
		try {
			socialLoading.kakao = true;
			// 절대 URL 사용
			const redirectUrl = `${window.location.origin}/${inviteCode}`;
			const { error } = await supabase.auth.signInWithOAuth({
				provider: 'kakao',
				options: { 
					redirectTo: redirectUrl,
					skipBrowserRedirect: false
				}
			});
			if (error) {
				errorMessage = error.message;
				socialLoading.kakao = false;
			}
		} catch (error: any) {
			errorMessage = error.message;
			socialLoading.kakao = false;
		}
	}

	async function loginWithGoogle() {
		try {
			socialLoading.google = true;
			// 절대 URL 사용
			const redirectUrl = `${window.location.origin}/${inviteCode}`;
			const { error } = await supabase.auth.signInWithOAuth({
				provider: 'google',
				options: { 
					redirectTo: redirectUrl,
					skipBrowserRedirect: false
				}
			});
			if (error) {
				errorMessage = error.message;
				socialLoading.google = false;
			}
		} catch (error: any) {
			errorMessage = error.message;
			socialLoading.google = false;
		}
	}

	async function loginWithApple() {
		try {
			socialLoading.apple = true;
			// 절대 URL 사용
			const redirectUrl = `${window.location.origin}/${inviteCode}`;
			const { error } = await supabase.auth.signInWithOAuth({
				provider: 'apple',
				options: { 
					redirectTo: redirectUrl,
					skipBrowserRedirect: false
				}
			});
			if (error) {
				errorMessage = error.message;
				socialLoading.apple = false;
			}
		} catch (error: any) {
			errorMessage = error.message;
			socialLoading.apple = false;
		}
	}

	import { joinMoimByInviteCode } from '$lib/stores/moim';

	// onAuthStateChange를 구독하여 로그인 후 자동으로 모임에 참여
	supabase.auth.onAuthStateChange(async (event, session) => {
		if (session) {
			try {
				await joinMoimByInviteCode(inviteCode);
				goto(`/${inviteCode}`);
			} catch (error) {
				console.error('Failed to join moim:', error);
				errorMessage = error instanceof Error ? error.message : '모임 참여에 실패했습니다.';
			}
		}
	});
</script>

{#if loading}
	<div class="global-spinner">
		<Spinner size="large" />
	</div>
{:else}
	<div
		class="moim-container"
		in:fade={{duration: 200}}
	>
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<div class="brand-section">
					<Logo />
					<h1 class="invite-title">초대 받으셨습니다!</h1>
					<p class="invite-message">
						<span class="code">{inviteCode}</span> 초대 코드를 통해<br />
						모임에 초대되었습니다.
					</p>
					<h2 class="invite-message-bold">모임에서 만남 일정을 함께 조율해요!</h2>
				</div>
			</header>
			<main class="moim-content">
				{#if errorMessage}
					<ErrorMessage message={errorMessage} />
				{/if}
				<div class="divider font-light">
					<span>소셜 로그인으로 시작하기</span>
				</div>
				<button
					type="button"
					class="social-btn kakao-btn font-regular"
					on:click={loginWithKakao}
					disabled={socialLoading.kakao}
				>
					{#if socialLoading.kakao}
						<div class="spinner social-spinner"></div>
						<span>연결 중</span>
					{:else} 
						<img src="/images/kakao.svg" alt="Kakao logo" />
						<span>카카오로 계속하기</span>
					{/if}
				</button>
				<button
					type="button"
					class="social-btn google-btn font-regular"
					on:click={loginWithGoogle}
					disabled={socialLoading.google}
				>
					{#if socialLoading.google}
						<div class="spinner social-spinner"></div>
						<span>연결 중</span>
					{:else}
						<img src="/images/google.svg" alt="Google logo" />
						<span>Google로 계속하기</span>
					{/if}
				</button>
				<button
					type="button"
					class="social-btn apple-btn font-regular"
					on:click={loginWithApple}
					disabled={socialLoading.apple}
				>
					{#if socialLoading.apple}
						<div class="spinner social-spinner"></div>
						<span>연결 중</span>
					{:else}
						<img src="/images/apple.svg" alt="Apple logo" />
						<span>Apple로 계속하기</span>
					{/if}
				</button>
				<div class="login-link">
					이메일 계정이 있으신가요? <a href="/login">이메일로 로그인하기</a>
				</div>
			</main>
		</div>
	</div>
{/if}

<style>
	:global(body) {
		margin: 0;
		background: white;
		color: #333;
		line-height: 1.5;
		font-family: 'Helvetica Neue', Arial, sans-serif;
	}

	.moim-container {
		width: 100%;
		max-height: 100vh;
		background: white;
		display: flex;
		flex-direction: column;
	}

	.moim-content-wrapper {
		max-width: 500px;
		margin: 0 auto;
		padding: 1rem;
		width: 100%;
		flex: 1;
		display: flex;
		flex-direction: column;
	}

	.moim-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 2.5rem 0 2rem;
		margin-bottom: 1rem;
		text-align: center;
	}

	.brand-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}

	.invite-title {
		font-size: 1.75rem;
		font-weight: 700;
		margin: 0;
		color: #064b45;
	}

	.invite-message {
		font-size: 1rem;
		color: #4a5568;
		margin-top: 3rem;
		line-height: 1.5;
	}

	.invite-message .code {
		font-weight: 600;
		color: #064b45;
	}

	.invite-message-bold {
		font-size: 1rem;
		color: #064b45;
		font-weight: 600;
	}

	.moim-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		width: 100%;
		max-width: 360px;
		margin: 0 auto;
	}

	.divider {
		display: flex;
		align-items: center;
		margin: 1.5rem 0;
		color: #666;
		font-size: 0.85rem;
	}

	.divider::before,
	.divider::after {
		content: '';
		flex: 1;
		border-bottom: 1px solid #eee;
	}

	.divider span {
		margin: 0 0.75rem;
	}

	.social-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 1rem;
		margin-bottom: 1rem;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 500;
		width: 100%;
		transition: all 0.15s ease;
		min-height: 3rem;
		cursor: pointer;
	}

	.social-btn:hover {
		filter: brightness(95%);
	}

	.social-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	.social-btn img {
		width: 18px;
		height: 18px;
	}

	.spinner {
		width: 1rem;
		height: 1rem;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-radius: 50%;
		border-top-color: white;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.social-spinner {
		border-color: rgba(0, 0, 0, 0.2);
		border-top-color: currentColor;
	}

	/* Google 버튼 스타일 */
	.google-btn {
		background: white;
		color: #3c4043;
		border: 1px solid #dadce0;
	}
	.google-btn:hover {
		background: #f8f9fa;
		border-color: #dadce0;
		filter: none;
	}

	/* Kakao 버튼 스타일 */
	.kakao-btn {
		background: #fee500;
		color: #000000;
	}

	/* Apple 버튼 스타일 */
	.apple-btn {
		background: #000000;
		color: white;
	}
	.apple-btn img {
		filter: invert(1) brightness(100%);
	}

	.global-spinner {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		background: white;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.login-link {
		text-align: center;
		font-size: 0.9rem;
		color: #4b5563;
		margin-top: 0.5rem;
	}

	.login-link a {
		color: #064b45;
		text-decoration: none;
		font-weight: 500;
	}

	.login-link a:hover {
		text-decoration: underline;
	}
</style>
