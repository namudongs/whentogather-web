<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { fade } from 'svelte/transition';
	import { supabase } from '$lib/supabaseClient';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import type { Moim, User, Participant, Mannam } from '$lib/types';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import BottomSheet from '$lib/components/BottomSheet.svelte';
	import Button from '$lib/components/Button.svelte';
	import ParticipantAvatar from '$lib/components/ParticipantAvatar.svelte';
	import Toast from '$lib/components/Toast.svelte';
	import { user } from '$lib/stores/auth';
	import { moims, isLoading, error as moimError, createMoim, loadMoims } from '$lib/stores/moim';
	import { format } from 'date-fns';
	import { ko } from 'date-fns/locale/ko';
	import { writable } from 'svelte/store';

	/*** 페이지 전역 상태 ***/
	const moim = writable<any>(null);
	let participants: any[] = [];
	const mannams = writable<any[]>([]);
	let errorMessage = '';
	let loading = false;
	let showInitialSpinner = true;
	let isJoining = false;
	let showNameSheet = false;
	let userName = '';
	let isUpdatingName = false;
	let profile: any = null;

	// 토스트 상태
	let showToast = false;
	let toastMessage = '';
	let toastType: 'success' | 'error' | 'info' = 'success';

	// 모달 상태
	let showJoinModal = false;
	let showCreateMannamSheet = false;
	let showEditMoimSheet = false;
	let showDeleteConfirmSheet = false;

	// 모임 수정 폼 데이터
	let editTitle = '';
	let editDescription = '';

	// URL 파라미터에서 초대 코드를 추출
	let inviteCode = '';
	$: inviteCode = $page.params.moim_url;

	// 만남 생성 폼 데이터
	let mannamTitle = '';
	let mannamDescription = '';
	let mannamStartDate = '';
	let mannamEndDate = '';
	let mannamTimeRange = { start: '09:00', end: '21:00' };
	let mannamTimeSlotMinutes = 30;
	let mannamError = '';
	
	// 날짜 범위 제한 체크
	$: {
		if (mannamStartDate && mannamEndDate) {
			const start = new Date(mannamStartDate);
			const end = new Date(mannamEndDate);
			const diffDays = Math.floor((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
			
			if (diffDays > 7) {
				mannamEndDate = '';
				mannamError = '날짜 범위는 7일을 초과할 수 없습니다.';
			} else if (end < start) {
				mannamEndDate = '';
				mannamError = '종료 날짜는 시작 날짜보다 이후여야 합니다.';
			} else {
				mannamError = '';
			}
		}
	}

	/*** 도움말(툴클) 상태 – 각 도움말 아이콘마다 별도의 상태와 위치를 관리 ***/
	let showStartDateHelp = false;
	let startDateHelpPosition = { x: 0, y: 0 };

	let showEndDateHelp = false;
	let endDateHelpPosition = { x: 0, y: 0 };

	let showTimeRangeHelp = false;
	let timeRangeHelpPosition = { x: 0, y: 0 };

	let showSlotHelp = false;
	let slotHelpPosition = { x: 0, y: 0 };

	// 실시간 구독 채널 참조
	let subscription: any;

	// 이전 페이지가 초대 페이지인지 확인
	function isComingFromInvite() {
		return document.referrer.includes(`/${inviteCode}/invite`);
	}

	/*** 페이지 초기화 ***/
	onMount(() => {
		setTimeout(() => {
			showInitialSpinner = false;
		}, 300);

		const initializePage = async () => {
			try {
				loading = true;
				// 1) 로그인 상태 확인: 세션이 없으면 /[moim_url]/invite 페이지로 리다이렉트
				const { data: sessionData } = await supabase.auth.getSession();
				if (!sessionData?.session) {
					await goto(`/${inviteCode}/invite`);
					return;
				}
				$user = sessionData.session.user;

				// 사용자 이름이 없으면 이름 입력 시트 표시
				if (!$user.user_metadata?.name) {
					showNameSheet = true;
				}

				// 초대 페이지에서 왔다면 자동으로 참여
				const fromInvite = isComingFromInvite();

				// 2) 모임 정보 조회 (moim_url로 조회)
				const { data: moimData, error: moimError } = await supabase
					.from('moims')
					.select('*')
					.eq('moim_url', inviteCode)
					.maybeSingle();
				if (moimError) {
					errorMessage = moimError.message || '모임 정보를 불러오지 못했습니다.';
					return;
				}
				if (!moimData) {
					errorMessage = '해당 초대 코드에 관한 모임이 없습니다. 초대 코드: ' + inviteCode;
					return;
				}
				moim.set(moimData);

				// 3) 참여자 목록 조회
				const { data: partsData, error: partsError } = await supabase
					.from('moim_participants')
					.select('user_id, role')
					.eq('moim_id', moimData.id);
				if (partsError) {
					errorMessage = '참여자 목록을 불러오는 중에 에러가 발생했습니다.' + partsError.message;
					return;
				}
				const updatedPartsData = partsData || [];
				const participantUserIds = updatedPartsData.map((p: any) => p.user_id);
				// 현재 사용자가 참여자 목록에 없다면
				if (!participantUserIds.includes($user.id)) {
					if (fromInvite) {
						// 초대 페이지에서 왔다면 자동으로 참여
						await joinMoim();
					} else {
						// 그렇지 않으면 모달 표시
						showJoinModal = true;
					}
				}

				// 참여자들의 프로필 정보 조회
				if (updatedPartsData.length > 0) {
					const userIds = updatedPartsData.map((p: any) => p.user_id);
					const { data: profilesData, error: profilesError } = await supabase
						.from('profiles')
						.select('id, name, email, avatar_url')
						.in('id', userIds);
					if (profilesError) {
						errorMessage = `참여자의 프로필 정보를 불러오는 중에 에러가 발생했습니다: ${
							profilesError?.message || '알 수 없는 오류'
						}`;
						return;
					}
					participants = updatedPartsData.map((participant: any) => ({
						...participant,
						profile: profilesData?.find((profile: any) => profile.id === participant.user_id)
					}));
				} else {
					participants = [];
				}

				// 4) 만남 목록 조회
				const { data: mannamsData, error: mannamsError } = await supabase
					.from('mannams')
					.select('*')
					.eq('moim_id', moimData.id)
					.order('created_at', { ascending: false });
				if (mannamsError) {
					errorMessage = `만남 목록을 불러오는 중에 에러가 발생했습니다: ${
						mannamsError?.message || '알 수 없는 오류'
					}`;
					return;
				}
				mannams.set(mannamsData ?? []);

				// 5) 실시간 구독 설정 (참여자 목록 업데이트)
				subscription = supabase
					.channel('moim_participants_changes')
					.on(
						'postgres_changes',
						{
							event: '*',
							schema: 'public',
							table: 'moim_participants',
							filter: `moim_id=eq.${moimData.id}`
						},
						async () => {
							const { data: updatedPartsData } = await supabase
								.from('moim_participants')
								.select('user_id, role')
								.eq('moim_id', moimData.id);
							if (updatedPartsData) {
								participants = updatedPartsData;
							}
						}
					)
					.subscribe();
			} catch (error) {
				console.error('Failed to initialize page:', error);
				errorMessage = '페이지를 불러오는 중 오류가 발생했습니다.';
			} finally {
				loading = false;
			}
		};

		initializePage();
		loadProfile();
	});

	// 컴포넌트 언마운트 시 구독 해제
	onDestroy(() => {
		if (subscription) {
			supabase.removeChannel(subscription);
		}
	});

	/*** 페이지 내 함수 ***/
	function goBack() {
		goto('/dashboard');
	}

	function copyInviteLink() {
		const inviteLink = `${window.location.origin}/${inviteCode}/invite`;
		navigator.clipboard.writeText(inviteLink);
		toastMessage = '초대 링크가 복사되었습니다';
		toastType = 'success';
		showToast = true;
	}

	function openEditMoimSheet() {
		editTitle = $moim?.title || '';
		editDescription = $moim?.description || '';
		showEditMoimSheet = true;
	}

	async function handleEditMoim() {
		if (!editTitle.trim()) return;

		try {
			const { error } = await supabase
				.from('moims')
				.update({
					title: editTitle,
					description: editDescription
				})
				.eq('id', $moim?.id);

			if (error) throw error;

			moim.update((moimData) => ({
				...moimData,
				title: editTitle,
				description: editDescription
			}));
			showEditMoimSheet = false;
			toastMessage = '모임 정보가 수정되었습니다';
			toastType = 'success';
			showToast = true;
		} catch (err) {
			toastMessage = '모임 정보 수정에 실패했습니다';
			toastType = 'error';
			showToast = true;
		}
	}

	async function handleDeleteMoim() {
		try {
			const { error } = await supabase
				.from('moims')
				.delete()
				.eq('id', $moim?.id);

			if (error) throw error;

			showDeleteConfirmSheet = false;
			goto('/dashboard');
		} catch (err) {
			toastMessage = '모임 삭제에 실패했습니다';
			toastType = 'error';
			showToast = true;
		}
	}

	function goToCreateMannam() {
		goto(`/${$page.params.moim_url}/create`);
	}

	function openCreateMannamSheet() {
		showCreateMannamSheet = true;
	}

	async function handleCreateMannam() {
		if (!$moim || !$user) return;
		try {
			const { data: mannam, error: err } = await supabase
				.from('mannams')
				.insert({
					moim_id: $moim.id,
					creator_id: $user.id,
					title: mannamTitle,
					description: mannamDescription,
					start_date: mannamStartDate,
					end_date: mannamEndDate,
					time_range: mannamTimeRange,
					time_slot_minutes: mannamTimeSlotMinutes,
					status: 'pending'
				})
				.select()
				.single();
			if (err) throw err;
			mannams.update((mannamsData) => [...mannamsData, mannam]);
			// 입력 폼 초기화
			mannamTitle = '';
			mannamDescription = '';
			mannamStartDate = '';
			mannamEndDate = '';
			mannamTimeRange = { start: '09:00', end: '21:00' };
			mannamTimeSlotMinutes = 30;
			showCreateMannamSheet = false;
		} catch (err) {
			mannamError =
				err instanceof Error ? err.message : '만남을 생성하는 중에 오류가 발생했습니다.';
		}
	}

	async function joinMoim() {
		if (!$user) {
			errorMessage = '로그인이 필요합니다.';
			return;
		}
		try {
			isJoining = true;
			const { data: insertedParticipants, error: insertError } = await supabase
				.from('moim_participants')
				.insert({ moim_id: $moim?.id, user_id: $user.id, role: 'participant' })
				.select();
			if (insertError) {
				errorMessage = `참여자를 추가하는 중에 에러가 발생했습니다: ${
					insertError?.message || '알 수 없는 오류'
				}`;
				return;
			}
			showJoinModal = false;
			window.location.reload();
		} catch (err) {
			errorMessage =
				err instanceof Error ? err.message : '참여 처리 중 알 수 없는 오류가 발생했습니다.';
		} finally {
			isJoining = false;
		}
	}

	async function handleUpdateName() {
		if (!userName.trim() || !$user) return;

		try {
			isUpdatingName = true;

			// 새로운 아바타 URL 생성
			const newAvatarUrl = `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(userName.trim())}&backgroundColor=b6e3d4`;

			// 1. Auth 메타데이터 업데이트
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

				// Auth 메타데이터 업데이트
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

	$: title = $moim ? `${$moim.title} - 언제모여` : '언제모여';

	interface Profile {
		id: string;
		name: string;
		email: string;
		avatar_url: string;
	}

	// Computed properties
	$: isCreator = $moim?.creator_id === $user?.id;
</script>

<svelte:head>
	<title>{title}</title>
</svelte:head>

{#if showInitialSpinner || loading}
	<div class="global-spinner" in:fade={{duration: 200}} out:fade={{duration: 200}}>
		<Spinner size="large" />
	</div>
{:else if errorMessage}
	<div class="error-container">
		<ErrorMessage message={errorMessage} />
		<Button variant="outline" on:click={goBack} class="font-regular">돌아가기</Button>
	</div>
{:else}
	<div class="moim-container" in:fade={{duration: 200}}>
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<div class="header-content">
					<!-- svelte-ignore a11y_consider_explicit_label -->
					<button class="back-btn font-regular" on:click={goBack}>
						<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M19 12H5M12 19l-7-7 7-7"/>
						</svg>
					</button>
					<div class="title-with-badge">
						<span class="header-badge font-regular">모임</span>
						<h1 class="moim-title font-extrabold">{$moim?.title || '모임 상세'}</h1>
					</div>
				</div>
			</header>

			<main class="moim-content">
				{#if $moim}
					<!-- 모임 설명 섹션 -->
					<section class="moim-description-section">
						{#if $moim.description}
							<p class="moim-description font-regular">{$moim.description}</p>
							<div class="meta-divider"></div>
						{/if}
						<div class="meta">
							<div class="info-item">
								<svg
									class="info-icon"
									xmlns="http://www.w3.org/2000/svg"
									viewBox="0 0 24 24"
									fill="none"
									stroke="currentColor"
									stroke-width="2"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
									/>
								</svg>
								<span class="info-text">{format(new Date($moim.created_at), 'PPP p', { locale: ko })} 생성</span>
							</div>
							{#if $moim.updated_at && new Date($moim.updated_at).getTime() - new Date($moim.created_at).getTime() > 1000}
								<div class="info-item">
									<svg
										class="info-icon"
										xmlns="http://www.w3.org/2000/svg"
										viewBox="0 0 24 24"
										fill="none"
										stroke="currentColor"
										stroke-width="2"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
										/>
									</svg>
									<span class="info-text">{format(new Date($moim.updated_at), 'PPP p', { locale: ko })} 수정</span>
								</div>
							{/if}
						</div>
						<div class="moim-actions">
							<button class="action-badge font-regular" on:click={copyInviteLink}>
								<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>
									<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>
								</svg>
								초대 링크 복사
							</button>
							{#if $moim.creator_id === $user?.id}
								<button class="action-badge font-regular" on:click={openEditMoimSheet}>
									<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M12 20h9"></path>
										<path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path>
									</svg>
									정보 수정
								</button>
								<button class="action-badge warning font-regular" on:click={() => (showDeleteConfirmSheet = true)}>
									<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M3 6h18"></path>
										<path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"></path>
										<path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"></path>
									</svg>
									삭제
								</button>
							{/if}
						</div>
					</section>

					<!-- 참여자 섹션 -->
					<section class="moim-section">
						<div class="section-header">
							<div class="title-with-badge">
								<h2 class="section-title font-bold">참여자</h2>
								<div class="count-badge font-regular">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
										<circle cx="9" cy="7" r="4"></circle>
										<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
										<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
									</svg>
									{participants.length}명
								</div>
							</div>
						</div>
						<div class="participants-grid">
							{#each participants as participant}
								<ParticipantAvatar
									name={participant.profile?.name || '이름없음'}
									role={participant.role}
									avatarUrl={participant.profile?.avatar_url}
									email={participant.profile?.email}
								/>
							{/each}
						</div>
					</section>

					<!-- 만남 섹션 -->
					<section class="moim-section">
						<div class="section-header">
							<div class="title-with-badge">
								<h2 class="section-title font-bold">만남</h2>
								<div class="count-badge font-regular">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
										<line x1="16" y1="2" x2="16" y2="6"></line>
										<line x1="8" y1="2" x2="8" y2="6"></line>
										<line x1="3" y1="10" x2="21" y2="10"></line>
									</svg>
									{$mannams.length}개
								</div>
							</div>
						</div>

						<div class="mannams-container">
							<Button 
								variant="primary" 
								on:click={goToCreateMannam} 
								class="create-mannam-btn font-bold"
							>
								<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<line x1="12" y1="5" x2="12" y2="19"></line>
									<line x1="5" y1="12" x2="19" y2="12"></line>
								</svg>
								새로운 만남 만들기
							</Button>
							
							{#if $mannams.length > 0}
								<div class="mannams-grid">
									{#each $mannams as mannam}
										<a href="/{inviteCode}/{mannam.mannam_url}" class="mannam-card">
											<div class="mannam-status-indicator" class:confirmed={mannam.status === 'confirmed'} class:cancelled={mannam.status === 'cancelled'}></div>
											<div class="mannam-content">
												<h3 class="mannam-title font-bold">
													<span class="mannam-status-badge font-light" class:confirmed={mannam.status === 'confirmed'} class:cancelled={mannam.status === 'cancelled'}>
														{#if mannam.status === 'confirmed'}
															<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
																<path d="M20 6L9 17l-5-5"></path>
															</svg>
															확정
														{:else if mannam.status === 'cancelled'}
															<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
																<line x1="18" y1="6" x2="6" y2="18"></line>
																<line x1="6" y1="6" x2="18" y2="18"></line>
															</svg>
															취소
														{:else}
															<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
																<circle cx="12" cy="12" r="10"></circle>
																<polyline points="12 6 12 12 16 14"></polyline>
															</svg>
															조율 중
														{/if}
													</span>
													{mannam.title}
												</h3>
												{#if mannam.description}
													<p class="mannam-description font-regular">{mannam.description}</p>
												{/if}
												<div class="mannam-meta font-light">
													<span class="meta-item">
														<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
															<rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
															<line x1="16" y1="2" x2="16" y2="6"></line>
															<line x1="8" y1="2" x2="8" y2="6"></line>
															<line x1="3" y1="10" x2="21" y2="10"></line>
														</svg>
														{new Date(mannam.start_date).toLocaleDateString()} - {new Date(mannam.end_date).toLocaleDateString()}
													</span>
													<span class="meta-item">
														<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
															<circle cx="12" cy="12" r="10"></circle>
															<polyline points="12 6 12 12 16 14"></polyline>
														</svg>
														{mannam.time_range.start} - {mannam.time_range.end}
													</span>
												</div>
											</div>
										</a>
									{/each}
								</div>
							{:else}
								<div class="empty-state">
									<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
										<rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
										<line x1="16" y1="2" x2="16" y2="6"></line>
										<line x1="8" y1="2" x2="8" y2="6"></line>
										<line x1="3" y1="10" x2="21" y2="10"></line>
									</svg>
									<p class="font-regular">아직 만남이 없습니다</p>
									<p class="subtitle font-light">새로운 만남을 만들어보세요</p>
								</div>
							{/if}
						</div>
					</section>
				{:else}
					<div class="empty-state">
						<p class="font-regular">모임 정보를 찾을 수 없습니다</p>
					</div>
				{/if}
			</main>
		</div>
	</div>
{/if}

<Toast
	message={toastMessage}
	type={toastType}
	bind:show={showToast}
/>

<BottomSheet show={showJoinModal} onClose={() => (showJoinModal = false)} title="모임 참여하기" blurBackground={true} showCloseButton={false}>
	<div class="join-content">
		<p class="join-message font-bold">"{$moim?.title}" 모임에 참여하시겠습니까?</p>
		<p class="join-description font-regular">모임에 참여하면 일정 조율에 참여할 수 있습니다.</p>
		<div class="form-actions">
			<Button variant="outline" on:click={() => (showJoinModal = false)} flex={1} class="font-regular">취소</Button>
			<Button variant="primary" on:click={joinMoim} flex={2} class="font-bold">
				{#if isJoining}
					<Spinner size="small" />
				{:else}
					참여하기
				{/if}
			</Button>
		</div>
	</div>
</BottomSheet>

<BottomSheet show={showEditMoimSheet} onClose={() => (showEditMoimSheet = false)} title="모임 정보 수정">
	<form on:submit|preventDefault={handleEditMoim} class="create-form">
		<div class="form-group">
			<label for="title" class="font-bold">모임 제목</label>
			<input
				id="title"
				type="text"
				bind:value={editTitle}
				placeholder="예: 동아리 회의"
				class="form-input font-regular"
			/>
		</div>
		<div class="form-group">
			<label for="description" class="font-bold">모임 설명 (선택)</label>
			<textarea
				id="description"
				bind:value={editDescription}
				placeholder="모임에 대한 간단한 소개 또는 설명을 작성해 주세요."
				class="form-input font-regular"
				rows="4"
			></textarea>
		</div>
		<div class="form-actions">
			<Button
				variant="outline"
				on:click={() => (showEditMoimSheet = false)}
				flex={1}
				class="font-regular"
			>취소</Button>
			<Button
				variant="primary"
				type="submit"
				flex={2}
				class="font-bold"
			>수정하기</Button>
		</div>
	</form>
</BottomSheet>

<BottomSheet show={showDeleteConfirmSheet} onClose={() => (showDeleteConfirmSheet = false)} title="모임 삭제">
	<div class="delete-confirm-content">
		<p class="delete-message font-bold">"{$moim?.title}" 모임을 삭제하시겠습니까?</p>
		<p class="delete-description font-regular">모임을 삭제하면 모든 만남과 참여자 정보가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.</p>
		<div class="form-actions">
			<Button
				variant="outline"
				on:click={() => (showDeleteConfirmSheet = false)}
				flex={1}
				class="font-regular"
			>취소</Button>
			<Button
				variant="primary"
				on:click={handleDeleteMoim}
				flex={2}
				class="font-bold"
			>삭제하기</Button>
		</div>
	</div>
</BottomSheet>

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

<style>
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

	.error-container {
		max-width: 500px;
		margin: 2rem auto;
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.moim-container {
		width: 100%;
		min-height: 100vh;
		background: white;
	}

	.moim-content-wrapper {
		max-width: 500px;
		margin: 0 auto;
		padding: 1rem;
		padding-top: 0.5rem;
	}

	.moim-header {
		position: sticky;
		top: 0;
		background: white;
		padding-bottom: 0.5rem;
		margin-bottom: 1.25rem;
		z-index: 100;
	}

	.header-content {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0 0.5rem;
	}

	.back-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		margin-left: -0.5rem;
		cursor: pointer;
		color: #064b45;
		line-height: 0;
	}

	.moim-title {
		margin: 0;
		font-size: 1.25rem;
		color: #111827;
	}

	.moim-content {
		padding: 0 0.5rem;
	}

	.moim-description-section {
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: #f8fafc;
		border-radius: 0.75rem;
	}

	.moim-description {
		margin: 0 0 0.75rem;
		font-size: 0.875rem;
		line-height: 1.6;
		color: #374151;
	}

	.meta-divider {
		margin: 0 0 1rem;
	}

	.meta {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.info-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.info-icon {
		width: 1.25rem;
		height: 1.25rem;
	}

	.moim-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
	}

	.moim-section {
		margin-bottom: 2rem;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
	}

	.section-title {
		font-size: 1.25rem;
		color: #111827;
		margin: 0;
	}

	.participants-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin: -0.25rem;
		padding: 0.25rem;
	}

	.mannams-container {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.mannams-grid {
		display: grid;
		gap: 0.75rem;
	}

	.mannam-card {
		position: relative;
		display: block;
		text-decoration: none;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.75rem;
		overflow: hidden;
		transition: all 0.2s ease;
	}

	.mannam-card:hover {
		transform: translateY(-2px);
		border-color: #064b45;
		box-shadow: 0 0 0 1px rgba(6, 75, 69, 0.1);
	}

	.mannam-status-indicator {
		position: absolute;
		top: 0;
		left: 0;
		width: 4px;
		height: 100%;
		background: rgba(251, 146, 60, 0.5);
	}

	.mannam-status-indicator.confirmed {
		background: rgb(22, 163, 74);
	}

	.mannam-status-indicator.cancelled {
		background: rgb(239, 68, 68);
	}

	.mannam-content {
		padding: 1.25rem;
	}

	.mannam-title {
		margin: 0;
		font-size: 1.125rem;
		color: #111827;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.mannam-status-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		background-color: rgba(251, 146, 60, 0.15);
		color: rgb(194, 65, 12);
	}

	.mannam-status-badge.confirmed {
		background-color: rgba(74, 222, 128, 0.15);
		color: rgb(22, 101, 52);
	}

	.mannam-status-badge.cancelled {
		background-color: rgba(248, 113, 113, 0.15);
		color: rgb(153, 27, 27);
	}

	.mannam-status-badge svg {
		width: 14px;
		height: 14px;
	}

	.mannam-description {
		margin: 0.5rem 0;
		font-size: 0.875rem;
		color: #374151;
		line-height: 1.5;
	}

	.mannam-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
		margin-top: 1rem;
		color: #6b7280;
		font-size: 0.813rem;
	}

	.meta-item {
		display: flex;
		align-items: center;
		gap: 0.35rem;
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

	.join-content {
		padding: 1.5rem;
		text-align: center;
	}

	.join-message {
		font-size: 1.125rem;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	.join-description {
		font-size: 0.875rem;
		color: #6b7280;
		margin: 0 0 2rem;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
	}

	.count-badge {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		background-color: rgb(243 244 246);
		border-radius: 9999px;
		font-size: 0.875rem;
	}

	.title-with-badge {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.header-badge {
		padding: 0.25rem 0.5rem;
		background-color: #064b45;
		color: white;
		border-radius: 9999px;
		font-size: 0.75rem;
	}

	.action-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.375rem 0.75rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 9999px;
		color: #374151;
		font-size: 0.75rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.action-badge:hover {
		border-color: #064b45;
		color: #064b45;
	}

	.action-badge.warning {
		background: white;
		border-color: #e5e7eb;
		color: #374151;
	}

	.action-badge.warning:hover {
		border-color: #ef4444;
		color: #ef4444;
		background: white;
	}

	.action-badge svg {
		color: currentColor;
	}

	.delete-confirm-content {
		padding: 1.5rem;
		text-align: center;
	}

	.delete-message {
		font-size: 1.125rem;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	.delete-description {
		font-size: 0.875rem;
		color: #6b7280;
		margin: 0 0 2rem;
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
