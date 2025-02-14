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

	let showInitialSpinner = true;
	let profile: any = null;

	// 모달 상태
	let isModalOpen = false;
	let isCreating = false;
	let title = '';
	let description = '';
	let showNameSheet = false;
	let userName = '';
	let isUpdatingName = false;
	let showProfileSheet = false;
	let avatarSeed = '';
	let avatarOptions = [''];  // 아바타 옵션 배열
	let selectedAvatarIndex = 0;  // 선택된 아바타 인덱스
	let isUpdatingProfile = false;

	// 토스트 상태
	let showToast = false;
	let toastMessage = '';
	let toastType: 'success' | 'error' | 'info' = 'success';

	let unsubscribe: () => void;

	async function loadProfile() {
		if (!$user) return;
		
		const { data, error } = await supabase
			.from('profiles')
			.select('*')
			.eq('id', $user.id)
			.single();
			
		if (!error && data) {
			profile = data;

			// 아바타 URL이 없거나 DiceBear API 기반이 아닌 경우 업데이트
			const isDiceBearUrl = (url?: string) => url?.includes('api.dicebear.com') ?? false;
			const createDiceBearUrl = (name: string) => 
				`https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(name)}&backgroundColor=b6e3d4`;

			if (!isDiceBearUrl(data.avatar_url)) {
				const newAvatarUrl = createDiceBearUrl(data.name || $user.email?.split('@')[0] || '');

				// Auth 메타데이트 업데이트
				await supabase.auth.updateUser({
					data: { avatar_url: newAvatarUrl }
				});

				// 프로필 테이블 업데이트
				await supabase
					.from('profiles')
					.update({ avatar_url: newAvatarUrl })
					.eq('id', $user.id);

				// 로컬 상태 업데이트
				profile.avatar_url = newAvatarUrl;
				$user = {
					...$user,
					user_metadata: {
						...$user.user_metadata,
						avatar_url: newAvatarUrl
					}
				} as typeof $user;
			}
		}
	}

	onMount(() => {
		setTimeout(() => {
			showInitialSpinner = false;
		}, 300);

		// 사용자 상태 구독
		unsubscribe = user.subscribe(async ($user) => {
			if ($user) {
				await loadProfile();
				// 사용자 이름이 없으면 이름 입력 시트 표시
				if (!profile?.name) {
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

			// 새로운 아바타 URL 생성
			const newAvatarUrl = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(userName.trim())}&backgroundColor=b6e3d4`;

			// 1. Auth 메타데이트 업데이트
			const { error: authError } = await supabase.auth.updateUser({
				data: { 
					name: userName.trim(),
					avatar_url: newAvatarUrl
				}
			});

			if (authError) throw authError;

			// 2. 프로필 테이블 업데이트
			const { error: profileError } = await supabase
				.from('profiles')
				.update({ 
					name: userName.trim(),
					avatar_url: newAvatarUrl
				})
				.eq('id', $user.id);

			if (profileError) throw profileError;

			// 3. 로컬 상태 업데이트
			$user = {
				...$user,
				user_metadata: {
					...$user.user_metadata,
					name: userName.trim(),
					avatar_url: newAvatarUrl
				}
			} as typeof $user;

			showNameSheet = false;
			toastMessage = '이름이 저장되었습니다';
			toastType = 'success';
			showToast = true;
		} catch (err) {
			console.error('Failed to update name:', err);
			toastMessage = '이름 저장에 실패했습니다';
			toastType = 'error';
			showToast = true;
		} finally {
			isUpdatingName = false;
		}
	}

	function openNameSheet() {
		userName = profile?.name || '';
		showNameSheet = true;
	}

	function openProfileSheet() {
		userName = profile?.name || '';
		// 현재 아바타 URL에서 시드 추출
		const currentUrl = profile?.avatar_url || '';
		const seedMatch = currentUrl.match(/seed=([^&]+)/);
		avatarSeed = seedMatch ? decodeURIComponent(seedMatch[1]) : (profile?.name || $user?.email?.split('@')[0] || '');
		generateAvatarOptions();
		showProfileSheet = true;
	}

	function generateAvatarOptions() {
		// 현재 시드는 그대로 유지
		const currentSeed = avatarSeed;
		
		// 5개의 새로운 랜덤 옵션 생성
		const newOptions = Array.from({ length: 5 }, () => Math.random().toString(36).substring(7));
		avatarOptions = [currentSeed, ...newOptions];
		selectedAvatarIndex = 0;  // 현재 아바타를 선택된 상태로 유지
	}

	function refreshAvatarOptions() {
		// 현재 선택된 아바타는 유지하고 나머지만 새로 생성
		const currentSeed = avatarOptions[selectedAvatarIndex];
		const newOptions = Array.from({ length: 5 }, () => Math.random().toString(36).substring(7));
		avatarOptions = [currentSeed, ...newOptions];
		selectedAvatarIndex = 0;  // 첫 번째 옵션(현재 선택된 아바타)을 선택된 상태로 유지
	}

	function selectAvatar(index: number) {
		selectedAvatarIndex = index;
		avatarSeed = avatarOptions[index];
	}

	async function handleUpdateProfile() {
		if (!userName.trim() || !$user) return;

		try {
			isUpdatingProfile = true;

			// 선택된 아바타의 시드와 URL 생성
			const selectedSeed = avatarOptions[selectedAvatarIndex];
			const newAvatarUrl = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(selectedSeed)}&backgroundColor=b6e3d4`;

			// 1. Auth 메타데이트
			const { error: authError } = await supabase.auth.updateUser({
				data: { 
					name: userName.trim(),
					avatar_url: newAvatarUrl
				}
			});

			if (authError) throw authError;

			// 2. 프로필 테이블 업데이트
			const { error: profileError } = await supabase
				.from('profiles')
				.update({ 
					name: userName.trim(),
					avatar_url: newAvatarUrl
				})
				.eq('id', $user.id);

			if (profileError) throw profileError;

			// 3. 로컬 상태 업데이트
			profile = { 
				...profile, 
				name: userName.trim(),
				avatar_url: newAvatarUrl
			};
			
			$user = {
				...$user,
				user_metadata: {
					...$user.user_metadata,
					name: userName.trim(),
					avatar_url: newAvatarUrl,
					avatar_seed: selectedSeed
				}
			} as typeof $user;

			showProfileSheet = false;  // 프로필 시트 닫기
			toastMessage = '프로필이 저장되었습니다';
			toastType = 'success';
			showToast = true;
		} catch (err) {
			console.error('Failed to update profile:', err);
			toastMessage = '프로필 저장에 실패했습니다';
			toastType = 'error';
			showToast = true;
		} finally {
			isUpdatingProfile = false;
		}
	}

	function generateNewAvatar() {
		avatarOptions.push(Math.random().toString(36).substring(7));
		avatarOptions = avatarOptions;  // 배열 업데이트를 위한 재할당
	}
</script>

{#if showInitialSpinner || $isLoading || $authLoading}
	<div class="global-spinner" in:fade={{duration: 200}} out:fade={{duration: 200}}>
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
						<button class="avatar-button" on:click={openProfileSheet}>
							<div class="avatar">
								<img
									src={profile?.avatar_url || `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent($user?.email?.split('@')[0] || '')}&backgroundColor=b6e3d4`}
									alt="프로필 아바타"
								/>
							</div>
							<div class="avatar-edit-icon">
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
									<path d="M12 20h9"></path>
									<path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path>
								</svg>
							</div>
						</button>
						<div class="welcome-text">
							<span class="greeting-label font-regular">환영합니다</span>
							<h1 class="user-name font-bold">
								안녕하세요, {profile?.name || $user?.email?.split('@')[0] || ''}님
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
	<BottomSheet show={showNameSheet} onClose={() => {}} title="이름 설정" blurBackground={true} showCloseButton={false}>
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

{#if showProfileSheet}
	<BottomSheet show={showProfileSheet} onClose={() => (showProfileSheet = false)} title="프로필 설정">
		<form on:submit|preventDefault={handleUpdateProfile} class="create-form">
			<div class="form-group">
				<label class="font-bold">프로필 사진</label>
				<div class="avatar-selection">
					<div class="current-avatar">
						<div class="avatar-option selected">
							<img
								src={`https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(avatarOptions[selectedAvatarIndex])}&backgroundColor=b6e3d4`}
								alt="현재 프로필 아바타"
							/>
						</div>
					</div>
					<div class="avatar-candidates">
						<div class="candidates-header">
							<span class="font-regular">다른 후보</span>
							<button
								type="button"
								class="refresh-button font-regular"
								on:click={refreshAvatarOptions}
							>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.3"/>
								</svg>
								새로 고치기
							</button>
						</div>
						<div class="avatar-grid">
							{#each avatarOptions.slice(1) as seed, i}
								<button
									type="button"
									class="avatar-option"
									class:selected={i + 1 === selectedAvatarIndex}
									on:click={() => selectAvatar(i + 1)}
								>
									<img
										src={`https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(seed)}&backgroundColor=b6e3d4`}
										alt="프로필 아바타 옵션"
									/>
								</button>
							{/each}
						</div>
					</div>
				</div>
			</div>
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
					variant="outline" 
					on:click={() => (showProfileSheet = false)} 
					flex={1} 
					class="font-regular"
				>
					취소
				</Button>
				<Button
					variant="primary"
					type="submit"
					disabled={isUpdatingProfile}
					loading={isUpdatingProfile}
					flex={2}
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

	.user-name-button {
		all: unset;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-size: 1.25rem;
		color: #111827;
		line-height: 1.25;
		padding: 0.25rem 0.5rem;
		margin: -0.25rem -0.5rem;
		border-radius: 0.375rem;
		transition: all 0.2s ease;
	}

	.user-name-button:hover {
		background: rgba(6, 75, 69, 0.05);
	}

	.user-name-button .edit-icon {
		opacity: 0;
		color: #064b45;
		transition: opacity 0.2s ease;
	}

	.user-name-button:hover .edit-icon {
		opacity: 1;
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

	.avatar-settings {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.avatar-preview {
		width: 4rem;
		height: 4rem;
		border-radius: 50%;
		overflow: hidden;
		background: white;
		border: 2px solid #e5e7eb;
	}

	.avatar-preview img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.avatar-button {
		all: unset;
		position: relative;
		cursor: pointer;
		border-radius: 50%;
		transition: transform 0.15s ease;
	}

	.avatar-button:hover {
		transform: scale(1.02);
	}

	.avatar-button:active {
		transform: scale(0.98);
	}

	.avatar-edit-icon {
		position: absolute;
		bottom: 0;
		right: 0;
		width: 20px;
		height: 20px;
		background: #064b45;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		opacity: 0.9;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.15);
	}

	.user-name {
		margin: 0;
		font-size: 1.25rem;
		color: #111827;
		line-height: 1.25;
	}

	.avatar-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.75rem;
	}

	.avatar-selection {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.current-avatar {
		display: flex;
		justify-content: center;
	}

	.current-avatar .avatar-option {
		width: 6rem;
		height: 6rem;
		padding: 0;
	}

	.avatar-candidates {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		background: #f8fafc;
		padding: 1rem;
		border-radius: 0.75rem;
	}

	.candidates-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		color: #6b7280;
	}

	.refresh-button {
		all: unset;
		display: flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.375rem 0.75rem;
		font-size: 0.875rem;
		color: #374151;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 9999px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.refresh-button:hover {
		border-color: #064b45;
		color: #064b45;
	}

	.refresh-button svg {
		color: currentColor;
	}

	.avatar-option {
		all: unset;
		position: relative;
		width: 100%;
		padding-bottom: 100%;
		border-radius: 50%;
		overflow: hidden;
		background: white;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.avatar-option::after {
		content: '';
		position: absolute;
		inset: 0;
		border: 2px solid #e5e7eb;
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.avatar-option:hover::after {
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}

	.avatar-option.selected::after {
		border-color: #064b45;
		border-width: 3px;
	}

	.avatar-option img {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.add-option {
		background: #f3f4f6;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.add-option svg {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 1.5rem;
		height: 1.5rem;
		color: #6b7280;
		transition: color 0.2s ease;
	}

	.add-option:hover svg {
		color: #064b45;
	}
</style>
