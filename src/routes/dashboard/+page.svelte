<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { fade, fly, slide } from 'svelte/transition';
	import Logo from '$lib/components/Logo.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import BottomSheet from '$lib/components/BottomSheet.svelte';
	import Button from '$lib/components/Button.svelte';
	import ParticipantAvatar from '$lib/components/ParticipantAvatar.svelte';
	import { user, logout, isLoading as authLoading } from '$lib/stores/auth';
	import { moims, isLoading, error as moimError, createMoim, loadMoims } from '$lib/stores/moim';
	import { supabase } from '$lib/supabaseClient';
	import Toast from '$lib/components/Toast.svelte';

	// 모달 상태
	let isModalOpen = false;
	let isCreating = false;
	let title = '';
	let description = '';
	let showNameSheet = false;
	let userName = '';
	let isUpdatingName = false;

	// 토스트 상태
	let showToast = false;
	let toastMessage = '';
	let toastType: 'success' | 'error' | 'info' = 'success';

	let unsubscribe: () => void;

	onMount(() => {
		// 사용자 상태 구독
		unsubscribe = user.subscribe(async ($user) => {
			if ($user) {
				// 사용자 이름이 없으면 이름 입력 시트 표시
				if (!$user.user_metadata?.name) {
					showNameSheet = true;
				}
				try {
					await loadMoims();
				} catch (error) {
					console.error('Failed to load moims:', error);
				}
			}
		});

		return () => {
			if (unsubscribe) unsubscribe();
		};
	});

	async function handleSignOut() {
		await logout();
		goto('/login');
	}

	function openCreateModal() {
		isModalOpen = true;
		title = '';
		description = '';
		$moimError = '';
	}

	function closeModal() {
		isModalOpen = false;
	}

	async function handleCreateMoim() {
		if (!title.trim()) {
			return;
		}

		try {
			isCreating = true;
			const newMoim = await createMoim(title, description);
			isCreating = false;
			closeModal();
			// 생성된 모임 페이지로 이동 (URL 구조 변경)
			goto(`/${newMoim.moim_url}`);
		} catch (error) {
			isCreating = false;
			// 에러는 이미 moimError 스토어에 저장됨
		}
	}

	// 모임 셀 클릭 시, 모임 상세 페이지로 이동하는 함수 (URL 구조 변경)
	function goToMeetingDetail(meeting: any) {
		goto(`/${meeting.moim_url}`);
	}

	async function handleUpdateName() {
		if (!userName.trim() || !$user) return;

		try {
			isUpdatingName = true;
			const { error } = await supabase.auth.updateUser({
				data: { name: userName.trim() }
			});

			if (error) throw error;

			// 스토어의 사용자 정보도 업데이트
			$user = {
				...$user,
				user_metadata: {
					...$user.user_metadata,
					name: userName.trim()
				}
			} as typeof $user;

			showNameSheet = false;
			toastMessage = '이름이 저장되었습니다';
			toastType = 'success';
			showToast = true;
		} catch (err) {
			toastMessage = '이름 저장에 실패했습니다';
			toastType = 'error';
			showToast = true;
		} finally {
			isUpdatingName = false;
		}
	}
</script>

{#if $isLoading || $authLoading}
	<div class="global-spinner">
		<Spinner size="large" />
	</div>
{:else if $moimError}
	<div class="error-container">
		<ErrorMessage message={$moimError} />
	</div>
{:else}
	<div
		class="dashboard-container"
		in:fade={{duration: 200}}
	>
		<div class="dashboard-content-wrapper">
			<header class="dashboard-header">
				<div class="header-content">
					<div class="logo-container">
						<Logo />
					</div>
					<button class="sign-out-btn font-regular" on:click={handleSignOut}>
						<svg
							xmlns="http://www.w3.org/2000/svg"
							width="16"
							height="16"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						>
							<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
							<polyline points="16 17 21 12 16 7"></polyline>
							<line x1="21" y1="12" x2="9" y2="12"></line>
						</svg>
						로그아웃
					</button>
				</div>
			</header>

			<main class="dashboard-content">
				<section class="welcome-section">
					<div class="welcome-content">
						<div class="avatar">
							<img
								src={`https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent($user?.user_metadata?.name || $user?.email?.split('@')[0] || '')}&backgroundColor=b6e3d4`}
								alt="프로필 아바타"
							/>
						</div>
						<div class="welcome-text">
							<span class="greeting-label font-regular">환영합니다</span>
							<h1 class="user-name font-bold">
								안녕하세요, {$user?.user_metadata?.name || $user?.email?.split('@')[0] || ''}님
							</h1>
						</div>
					</div>
				</section>

				<section class="meetings-section">
					<div class="title-with-badge">
						<h2 class="font-bold">내 모임</h2>
						<div class="count-badge font-regular">
							<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
							</svg>
							{$moims?.length || 0}개
						</div>
					</div>
					<section class="quick-actions">
						<Button variant="primary" on:click={openCreateModal} class="font-bold">
							<svg
								xmlns="http://www.w3.org/2000/svg"
								width="20"
								height="20"
								viewBox="0 0 24 24"
								fill="none"
								stroke="currentColor"
								stroke-width="2"
								stroke-linecap="round"
								stroke-linejoin="round"
							>
								<line x1="12" y1="5" x2="12" y2="19"></line>
								<line x1="5" y1="12" x2="19" y2="12"></line>
							</svg>
							새로운 모임 만들기
						</Button>
					</section>

					{#if $moimError}
						<ErrorMessage message={$moimError} />
					{:else if $moims && $moims.length > 0}
						<ul class="meetings-list">
							{#each $moims as meeting, i}
								<li class="meeting-item" in:slide={{ delay: i * 100, duration: 300 }}>
									<button
										type="button"
										class="meeting-button"
										on:click={() => goToMeetingDetail(meeting)}
									>
										<div class="meeting-status-bar"></div>
										<div class="meeting-content">
											<h3 class="meeting-title font-bold">{meeting.title}</h3>
											{#if meeting.description}
												<p class="meeting-description font-regular">{meeting.description}</p>
											{/if}
											<div class="meeting-meta font-light">
												<span class="meta-item">
													<svg
														xmlns="http://www.w3.org/2000/svg"
														width="14"
														height="14"
														viewBox="0 0 24 24"
														fill="none"
														stroke="currentColor"
														stroke-width="2"
														stroke-linecap="round"
														stroke-linejoin="round"
													>
														<circle cx="12" cy="12" r="10"></circle>
														<polyline points="12 6 12 12 16 14"></polyline>
													</svg>
													{new Date(meeting.created_at).toLocaleDateString()}
												</span>
												{#if meeting.participant_count}
													<span class="meta-item">
														<svg
															xmlns="http://www.w3.org/2000/svg"
															width="14"
															height="14"
															viewBox="0 0 24 24"
															fill="none"
															stroke="currentColor"
															stroke-width="2"
															stroke-linecap="round"
															stroke-linejoin="round"
														>
															<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
															<circle cx="9" cy="7" r="4"></circle>
															<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
															<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
														</svg>
														{meeting.participant_count}명
													</span>
												{/if}
											</div>
										</div>
									</button>
								</li>
							{/each}
						</ul>
					{:else}
						<div class="empty-state">
							<svg
								xmlns="http://www.w3.org/2000/svg"
								width="48"
								height="48"
								viewBox="0 0 24 24"
								fill="none"
								stroke="currentColor"
								stroke-width="1"
								stroke-linecap="round"
								stroke-linejoin="round"
							>
								<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
								<circle cx="9" cy="7" r="4"></circle>
								<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
								<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
							</svg>
							<p class="font-regular">아직 모임이 없습니다</p>
							<p class="subtitle font-light">새로운 모임을 만들어보세요</p>
						</div>
					{/if}
				</section>
			</main>
		</div>
	</div>
{/if}

<BottomSheet show={isModalOpen} onClose={closeModal} title="새로운 모임 만들기">
	<form on:submit|preventDefault={handleCreateMoim} class="create-form">
		{#if $moimError}
			<ErrorMessage message={$moimError} />
		{/if}
		<div class="form-group">
			<label for="title" class="font-bold">모임 제목</label>
			<input
				id="title"
				type="text"
				bind:value={title}
				placeholder="예: 동아리 회의"
				class="form-input font-regular"
			/>
		</div>
		<div class="form-group">
			<label for="description" class="font-bold">모임 설명 (선택)</label>
			<textarea
				id="description"
				bind:value={description}
				placeholder="모임에 대한 간단한 소개 또는 설명을 작성해 주세요."
				class="form-input font-regular"
				rows="4"
			></textarea>
		</div>
		<div class="form-actions">
			<Button variant="outline" on:click={closeModal} flex={1} class="font-regular">취소</Button>
			<Button
				variant="primary"
				type="submit"
				disabled={isCreating}
				loading={isCreating}
				flex={2}
				class="font-bold">모임 생성하기</Button
			>
		</div>
	</form>
</BottomSheet>

{#if showNameSheet}
	<BottomSheet show={showNameSheet} onClose={() => {}} title="이름 설정">
		<form on:submit|preventDefault={handleUpdateName} class="create-form">
			<div class="form-group">
				<label for="name" class="font-bold">이름</label>
				<input
					id="name"
					type="text"
					bind:value={userName}
					placeholder="이름을 입력해 주세요"
					class="form-input font-regular"
				/>
				<p class="help-text font-regular">다른 사용자에게 표시될 이름입니다.</p>
			</div>
			<div class="form-actions">
				<Button
					variant="primary"
					type="submit"
					disabled={isUpdatingName}
					loading={isUpdatingName}
					flex={1}
					class="font-bold"
				>
					저장하기
				</Button>
			</div>
		</form>
	</BottomSheet>
{/if}

<style>
	:global(body) {
		margin: 0;
		background: white;
	}

	/* 전역 스피너 */
	.global-spinner {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		background: #ffffff;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.dashboard-container {
		width: 100%;
		min-height: 100vh;
		background: white;
	}

	.dashboard-content-wrapper {
		max-width: 500px;
		margin: 0 auto;
		padding: 1rem;
		padding-top: 0.5rem;
	}

	.dashboard-header {
		position: sticky;
		top: 0;
		background: white;
		padding-bottom: 0.5rem;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 1.25rem;
		z-index: 100;
	}

	.header-content {
		max-width: 500px;
		margin: 0 auto;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0 0.5rem;
	}

	.logo-container {
		margin-right: 1rem;
	}

	.avatar {
		width: 1.75rem;
		height: 1.75rem;
		border-radius: 50%;
		overflow: hidden;
		background: #f3f4f6;
	}

	.avatar img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.sign-out-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.75rem;
		color: #064b45;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.sign-out-btn:hover {
		color: #ef4444;
		background: rgba(6, 75, 69, 0.02);
	}

	.dashboard-content {
		display: flex;
		flex-direction: column;
		padding: 1.5rem 0.5rem 0.5rem;
	}

	.welcome-section {
		margin-bottom: 1em;
		padding: 1.5rem;
		background: #f8fafc;
		border-radius: 1rem;
		border: 1px solid #e5e7eb;
	}

	.welcome-content {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.avatar {
		width: 3rem;
		height: 3rem;
		border-radius: 50%;
		overflow: hidden;
		background: white;
		border: 2px solid #e5e7eb;
	}

	.avatar img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.welcome-text {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.greeting-label {
		font-size: 0.875rem;
		color: #6b7280;
	}

	.user-name {
		margin: 0;
		font-size: 1.25rem;
		color: #111827;
		line-height: 1.25;
	}

	.quick-actions {
		display: grid;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.meetings-section {
		margin-top: 1rem;
	}

	.meetings-section h2 {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0;
		color: #111827;
	}

	.title-with-badge {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1.5rem;
	}

	.count-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		background-color: rgb(243 244 246);
		border-radius: 9999px;
		font-size: 0.875rem;
		line-height: 1;
	}

	.meetings-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.meeting-item {
		border: none;
		padding: 0;
		background: none;
	}

	.meeting-button {
		all: unset;
		display: block;
		width: 100%;
		box-sizing: border-box;
		cursor: pointer;
		border-radius: 0.5rem;
		transition: all 0.2s ease;
		position: relative;
		overflow: hidden;
		background: white;
		border: 1px solid #d1d5db;
	}

	.meeting-button:hover {
		transform: translateY(-2px);
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}

	.meeting-status-bar {
		position: absolute;
		top: 0;
		left: 0;
		width: 4px;
		height: 100%;
		background: #064b45;
		opacity: 0.9;
	}

	.meeting-content {
		padding: 1rem 1.25rem;
	}

	.meeting-meta {
		display: flex;
		gap: 1rem;
		margin-top: 0.75rem;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.meta-item {
		display: flex;
		align-items: center;
		gap: 0.35rem;
	}

	.meeting-title {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 500;
		color: #111827;
		display: -webkit-box;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.meeting-description {
		margin: 0.5rem 0;
		font-size: 0.875rem;
		color: #374151;
		display: -webkit-box;
		-webkit-box-orient: vertical;
		overflow: hidden;
		line-height: 1.5;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		background: #f8fafc;
		border-radius: 0.75rem;
		color: #374151;
		text-align: center;
	}

	.empty-state svg {
		color: #9ca3af;
		margin-bottom: 1rem;
	}

	.empty-state p {
		margin: 0;
		font-size: 0.875rem;
	}

	.empty-state .subtitle {
		font-size: 0.875rem;
		color: #6b7280;
		margin-top: 0.25rem;
	}

	.create-form {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-input {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		color: #111827;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}

	.form-input::placeholder {
		color: #9ca3af;
	}

	textarea.form-input {
		resize: vertical;
		min-height: 80px;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
		margin-top: 0.5rem;
	}

	.help-text {
		font-size: 0.813rem;
		color: #6b7280;
		margin-top: 0.25rem;
	}
</style>
