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
	import { user } from '$lib/stores/auth';

	/*** 페이지 전역 상태 ***/
	let moim: any = null;
	let participants: any[] = [];
	let mannams: any[] = [];
	let errorMessage = '';
	let loading = true;

	// URL 파라미터에서 초대 코드를 추출
	let inviteCode = '';
	$: inviteCode = $page.params.invite_code;

	// 모달 상태
	let showJoinModal = false;
	let showCreateMannamSheet = false;

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

	/*** 도움말(툴팁) 상태 – 각 도움말 아이콘마다 별도의 상태와 위치를 관리 ***/
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
		return document.referrer.includes(`/moim/${inviteCode}/invite`);
	}

	/*** 페이지 초기화 ***/
	onMount(() => {
		const initializePage = async () => {
			try {
				loading = true;
				// 1) 로그인 상태 확인: 세션이 없으면 /moim/[invite_code]/invite 페이지로 리다이렉트
				const { data: sessionData } = await supabase.auth.getSession();
				if (!sessionData?.session) {
					await goto(`/moim/${inviteCode}/invite`);
					return;
				}
				$user = sessionData.session.user;

				// 초대 페이지에서 왔다면 자동으로 참여
				const fromInvite = isComingFromInvite();

				// 2) 모임 정보 조회 (invite_code로 조회)
				const { data: moimData, error: moimError } = await supabase
					.from('moims')
					.select('*')
					.eq('invite_code', inviteCode)
					.maybeSingle();
				if (moimError) {
					errorMessage = moimError.message || '모임 정보를 불러오지 못했습니다.';
					return;
				}
				if (!moimData) {
					errorMessage = '해당 초대 코드에 관한 모임이 없습니다. 초대 코드: ' + inviteCode;
					return;
				}
				moim = moimData;

				// 3) 참여자 목록 조회
				const { data: partsData, error: partsError } = await supabase
					.from('moim_participants')
					.select('user_id, role')
					.eq('moim_id', moim.id);
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
						.select('id, name')
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
					.eq('moim_id', moim.id)
					.order('created_at', { ascending: false });
				if (mannamsError) {
					errorMessage = `만남 목록을 불러오는 중에 에러가 발생했습니다: ${
						mannamsError?.message || '알 수 없는 오류'
					}`;
					return;
				}
				mannams = mannamsData ?? [];

				// 5) 실시간 구독 설정 (참여자 목록 업데이트)
				subscription = supabase
					.channel('moim_participants_changes')
					.on(
						'postgres_changes',
						{
							event: '*',
							schema: 'public',
							table: 'moim_participants',
							filter: `moim_id=eq.${moim.id}`
						},
						async () => {
							const { data: updatedPartsData } = await supabase
								.from('moim_participants')
								.select('user_id, role')
								.eq('moim_id', moim.id);
							if (updatedPartsData) {
								participants = updatedPartsData;
							}
						}
					)
					.subscribe();
			} catch (err) {
				errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
			} finally {
				loading = false;
			}
		};

		initializePage();
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

	function openCreateMannamSheet() {
		showCreateMannamSheet = true;
	}

	async function handleCreateMannam() {
		if (!moim || !$user) return;
		try {
			const { data: mannam, error: err } = await supabase
				.from('mannams')
				.insert({
					moim_id: moim.id,
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
			mannams = [...mannams, mannam];
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
			const { data: insertedParticipants, error: insertError } = await supabase
				.from('moim_participants')
				.insert({ moim_id: moim.id, user_id: $user.id, role: 'participant' })
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
		}
	}
</script>

{#if loading}
	<div class="global-spinner">
		<Spinner size="large" />
	</div>
{:else}
	<div class="moim-container">
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<button class="back-btn" on:click={goBack} aria-label="Go back">
					<svg
						xmlns="http://www.w3.org/2000/svg"
						width="24"
						height="24"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2"
						stroke-linecap="round"
						stroke-linejoin="round"
					>
						<path d="M19 12H5" />
						<path d="M12 19l-7-7 7-7" />
					</svg>
				</button>
				<h1 class="moim-title font-extrabold">
					{moim ? moim.title : '모임 상세'}
				</h1>
			</header>

			<main class="moim-content">
				{#if errorMessage}
					<p class="error">{errorMessage}</p>
				{:else if moim}
					<!-- 모임 정보 섹션 -->
					<section class="moim-info info-box">
						{#if moim.description}
							<p class="moim-description">{moim.description}</p>
						{:else}
							<p class="no-description">설명 없음</p>
						{/if}
						<p class="meta">
							<strong>생성일:</strong>
							{new Date(moim.created_at).toLocaleString()}
						</p>
						<p class="meta">
							<strong>마지막 업데이트:</strong>
							{new Date(moim.updated_at).toLocaleString()}
						</p>
					</section>

					<!-- 참여자 목록 섹션 -->
					<section class="participants-box info-box">
						<h2 class="section-title">참여자 목록</h2>
						{#if participants.length > 0}
							<ul class="participants-list">
								{#each participants as participant}
									<li class="participant-item">
										<span class="participant-name">
											{participant.profile?.name || '이름 없음'}
										</span>
										{#if participant.role === 'creator'}
											<span class="creator-tag">모임장</span>
										{/if}
									</li>
								{/each}
							</ul>
						{:else}
							<p class="no-participants">아직 참여자가 없습니다.</p>
						{/if}
					</section>

					<!-- 만남 목록 섹션 -->
					<section class="mannams-box info-box">
						<div class="mannams-header">
							<h2 class="section-title">만남 목록</h2>
							<button on:click={openCreateMannamSheet} class="add-mannam-btn">
								<svg
									class="h-4 w-4"
									xmlns="http://www.w3.org/2000/svg"
									viewBox="0 0 24 24"
									fill="none"
									stroke="currentColor"
									stroke-width="2"
									stroke-linecap="round"
									stroke-linejoin="round"
								>
									<line x1="12" y1="5" x2="12" y2="19" />
									<line x1="5" y1="12" x2="19" y2="12" />
								</svg>
								만남 추가하기
							</button>
						</div>
						{#if mannams.length > 0}
							<div class="mannams-list">
								{#each mannams as mannam}
									<!-- svelte-ignore a11y_click_events_have_key_events -->
									<div
										class="mannam-cell"
										on:click={() => goto(`/moim/${inviteCode}/mannams/${mannam.id}`)}
										role="button"
										tabindex="0"
									>
										<h3 class="mannam-title">{mannam.title}</h3>
										{#if mannam.description}
											<p class="mannam-description">{mannam.description}</p>
										{/if}
										<div class="mannam-meta">
											<p class="meta">
												생성일: {new Date(mannam.created_at).toLocaleDateString()}
											</p>
											<p class="meta status {mannam.status}">
												{#if mannam.status === 'pending'}
													대기중
												{:else if mannam.status === 'confirmed'}
													확정됨
												{:else}
													취소됨
												{/if}
											</p>
										</div>
									</div>
								{/each}
							</div>
						{:else}
							<div class="empty-mannams">
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
								<p class="empty-text">아직 만남이 없어요.</p>
							</div>
						{/if}
					</section>
				{:else}
					<p class="not-found">해당 모임 정보를 찾을 수 없습니다.</p>
				{/if}
			</main>
		</div>
	</div>
{/if}

<!-- 모임 참여 바텀시트 -->
<BottomSheet
	show={showJoinModal}
	onClose={() => goto('/dashboard')}
	title="모임 참여"
	blurBackground={true}
>
	<div class="join-sheet-content">
		<p class="join-description">이 모임에 참여하시겠습니까?</p>
		<div class="join-description-sub">모임에 참여하면 일정 조율에 참여할 수 있습니다.</div>
		<div class="form-actions">
			<Button variant="outline" on:click={() => goto('/dashboard')} flex={1}>돌아가기</Button>
			<Button variant="primary" on:click={joinMoim} flex={2}>참여하기</Button>
		</div>
	</div>
</BottomSheet>

<!-- 만남 생성 바텀시트 -->
<BottomSheet
	show={showCreateMannamSheet}
	onClose={() => {
		showCreateMannamSheet = false;
		mannamError = '';
	}}
	title="새로운 만남 만들기"
	blurBackground={false}
>
	<div class="create-mannam-content">
		{#if mannamError}
			<div class="error-message">{mannamError}</div>
		{/if}
		<form on:submit|preventDefault={handleCreateMannam} class="create-mannam-form">
			<!-- 만남 제목 -->
			<div class="form-group">
				<label for="mannamTitle" class="form-label">만남 제목</label>
				<input
					type="text"
					id="mannamTitle"
					bind:value={mannamTitle}
					required
					class="form-input"
					placeholder="3월 정기 모임"
				/>
			</div>

			<!-- 만남 설명 -->
			<div class="form-group">
				<label for="mannamDescription" class="form-label">설명</label>
				<textarea
					id="mannamDescription"
					bind:value={mannamDescription}
					rows="3"
					class="form-input"
					placeholder="이번 모임의 주제나 준비물 등을 적어주세요"
				></textarea>
			</div>

			<!-- 시작 날짜 / 종료 날짜 -->
			<div class="form-row">
				<div class="form-group flex-1">
					<div class="label-with-help">
						<label for="mannamStartDate" class="form-label">시작 날짜</label>
						<button
							type="button"
							class="help-icon"
							aria-label="시작 날짜에 대한 도움말"
							on:mouseenter={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								startDateHelpPosition = { x: rect.left, y: rect.top };
								showStartDateHelp = true;
							}}
							on:mouseleave={() => (showStartDateHelp = false)}
							on:click={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								startDateHelpPosition = { x: rect.left, y: rect.top };
								showStartDateHelp = !showStartDateHelp;
							}}
						>
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
								<circle cx="12" cy="12" r="10"></circle>
								<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
								<line x1="12" y1="17" x2="12.01" y2="17"></line>
							</svg>
						</button>
						{#if showStartDateHelp}
							<div
								class="help-tooltip"
								style="left: {startDateHelpPosition.x}px; top: {startDateHelpPosition.y + 20}px"
								transition:fade
							>
								만남 가능 날짜의 시작일입니다. 참여자들은 이 날짜부터 시간을 선택할 수 있습니다.
							</div>
						{/if}
					</div>
					<input
						type="date"
						id="mannamStartDate"
						bind:value={mannamStartDate}
						required
						class="form-input"
					/>
				</div>

				<div class="form-group flex-1">
					<div class="label-with-help">
						<label for="mannamEndDate" class="form-label">종료 날짜</label>
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<!-- svelte-ignore a11y_no_static_element_interactions -->
						<span
							class="help-icon"
							aria-label="종료 날짜에 대한 도움말"
							on:mouseenter={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								endDateHelpPosition = { x: rect.left, y: rect.top };
								showEndDateHelp = true;
							}}
							on:mouseleave={() => (showEndDateHelp = false)}
							on:click={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								endDateHelpPosition = { x: rect.left, y: rect.top };
								showEndDateHelp = !showEndDateHelp;
							}}
						>
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
								<circle cx="12" cy="12" r="10"></circle>
								<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
								<line x1="12" y1="17" x2="12.01" y2="17"></line>
							</svg>
						</span>
						{#if showEndDateHelp}
							<div
								class="help-tooltip"
								style="left: {endDateHelpPosition.x}px; top: {endDateHelpPosition.y + 20}px"
								transition:fade
							>
								만남 가능 날짜의 종료일입니다. 참여자들은 이 날짜까지만 시간을 선택할 수 있습니다.
							</div>
						{/if}
					</div>
					<input
						type="date"
						id="mannamEndDate"
						bind:value={mannamEndDate}
						required
						class="form-input"
					/>
				</div>
			</div>

			<!-- 날짜 선택 안내 메시지 -->
			<div class="date-range-info">
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="info-icon">
					<circle cx="12" cy="12" r="10"></circle>
					<line x1="12" y1="16" x2="12" y2="12"></line>
					<line x1="12" y1="8" x2="12.01" y2="8"></line>
				</svg>
				<span>날짜 범위는 최대 7일까지 선택할 수 있습니다.</span>
			</div>

			<!-- 시간 범위 -->
			<div class="form-group">
				<div class="label-with-help">
					<!-- svelte-ignore a11y_label_has_associated_control -->
					<label class="form-label">시간 범위</label>
					<span
						class="help-icon"
						role="button"
						tabindex="0"
						aria-label="시간 범위에 대한 도움말"
						on:mouseenter={(e) => {
							const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
							timeRangeHelpPosition = { x: rect.left, y: rect.top };
							showTimeRangeHelp = true;
						}}
						on:mouseleave={() => (showTimeRangeHelp = false)}
						on:keydown={(e) => {
							if (e.key === 'Enter' || e.key === ' ') {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								timeRangeHelpPosition = { x: rect.left, y: rect.top };
								showTimeRangeHelp = !showTimeRangeHelp;
							}
						}}
					>
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
							<circle cx="12" cy="12" r="10"></circle>
							<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
							<line x1="12" y1="17" x2="12.01" y2="17"></line>
						</svg>
					</span>
					{#if showTimeRangeHelp}
						<div
							class="help-tooltip"
							style="left: {timeRangeHelpPosition.x}px; top: {timeRangeHelpPosition.y + 20}px"
							transition:fade
						>
							하루 중 만남이 가능한 시간대를 설정합니다. 예를 들어, 오전 9시부터 오후 6시까지로
							설정하면 해당 시간대 내에서만 선택이 가능합니다.
						</div>
					{/if}
				</div>
				<div class="form-row">
					<div class="form-group flex-1">
						<label for="mannamTimeRangeStart" class="form-sublabel">시작 시간</label>
						<input
							type="time"
							id="mannamTimeRangeStart"
							bind:value={mannamTimeRange.start}
							required
							class="form-input"
						/>
					</div>
					<div class="form-group flex-1">
						<label for="mannamTimeRangeEnd" class="form-sublabel">종료 시간</label>
						<input
							type="time"
							id="mannamTimeRangeEnd"
							bind:value={mannamTimeRange.end}
							required
							class="form-input"
						/>
					</div>
				</div>
			</div>

			<!-- 시간 슬롯 단위 -->
			<div class="form-group">
				<div class="label-with-help">
					<label for="mannamTimeSlotMinutes" class="form-label">시간 슬롯 단위</label>
					<span
						class="help-icon"
						role="button"
						tabindex="0"
						aria-label="시간 슬롯에 대한 도움말"
						on:mouseenter={(e) => {
							const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
							slotHelpPosition = { x: rect.left, y: rect.top };
							showSlotHelp = true;
						}}
						on:mouseleave={() => (showSlotHelp = false)}
						on:keydown={(e) => {
							if (e.key === 'Enter' || e.key === ' ') {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								slotHelpPosition = { x: rect.left, y: rect.top };
								showSlotHelp = !showSlotHelp;
							}
						}}
					>
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
							<circle cx="12" cy="12" r="10"></circle>
							<path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
							<line x1="12" y1="17" x2="12.01" y2="17"></line>
						</svg>
					</span>
					{#if showSlotHelp}
						<div
							class="help-tooltip"
							style="left: {slotHelpPosition.x}px; top: {slotHelpPosition.y + 20}px"
							transition:fade
						>
							시간을 선택할 수 있는 최소 단위입니다. 예를 들어, 30분으로 설정하면 30분 단위로 시간을
							선택할 수 있습니다.
						</div>
					{/if}
				</div>
				<select id="mannamTimeSlotMinutes" bind:value={mannamTimeSlotMinutes} class="form-input">
					<option value={15}>15분</option>
					<option value={30}>30분</option>
					<option value={60}>1시간</option>
				</select>
			</div>

			<!-- 폼 액션 버튼 -->
			<div class="form-actions">
				<Button
					variant="outline"
					on:click={() => {
						showCreateMannamSheet = false;
						mannamError = '';
					}}
					flex={1}
				>
					취소
				</Button>
				<Button variant="primary" type="submit" flex={2}>만남 생성하기</Button>
			</div>
		</form>
	</div>
</BottomSheet>

<style>
	.date-range-info {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		border-radius: 0.375rem;
		color: #4b5563;
		font-size: 0.775rem;
    margin-top: -0.5rem;
	}

	.info-icon {
		color: #6b7280;
	}

	:global(body) {
		margin: 0;
		background: white;
		font-family:
			'Pretendard Variable',
			-apple-system,
			BlinkMacSystemFont,
			system-ui,
			Roboto,
			sans-serif;
	}

	.label-with-help {
		position: relative;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.help-icon {
		cursor: pointer;
		color: #6d7178;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: color 0.2s;
		opacity: 0.9;
		background: none;
		border: none;
		padding: 0;
		margin: 0;
	}

	.help-icon:hover {
		color: #374151;
	}

	/* 툴팁은 position: fixed로 처리하여 getBoundingClientRect()로 구한 뷰포트 좌표를 그대로 사용 */
	.help-tooltip {
		position: fixed;
		background: #fff;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
		max-width: 300px;
		z-index: 1000;
		font-size: 0.875rem;
		line-height: 1.5;
		color: #374151;
		border: 1px solid #e5e7eb;
	}

	.form-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-sublabel {
		font-size: 0.813rem;
		color: #6b7280;
	}

	.form-input {
		width: 100%;
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}

	select.form-input {
		appearance: none;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
		background-position: right 0.5rem center;
		background-repeat: no-repeat;
		background-size: 1.5em 1.5em;
		padding-right: 2.5rem;
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

	.moim-container {
		width: 100%;
		min-height: 100vh;
		background: white;
	}

	.moim-content-wrapper {
		max-width: 500px;
		margin: 0 auto;
		padding: 1rem;
	}

	.moim-header {
		display: flex;
		gap: 0.5rem;
		padding: 0.75rem 0;
		border-bottom: 1px solid #f0f0f0;
		margin-bottom: 1rem;
		z-index: 100;
	}

	.back-btn {
		background: none;
		border: none;
		cursor: pointer;
		color: #064b45;
		transition: color 0.2s;
	}

	.back-btn:hover {
		color: #043835;
	}

	.moim-title {
		font-size: 1.5rem;
		margin: 0;
		text-align: left;
		color: #333;
		flex: 1;
	}

	.moim-content {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	/* 정보 박스 스타일 */
	.info-box {
		background: #fafafa;
		padding: 1rem;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
	}

	.moim-description,
	.no-description {
		margin: 0;
		font-size: 1rem;
		color: #4a5568;
	}

	.no-description {
		font-style: italic;
		color: #a0aec0;
	}

	.meta {
		font-size: 0.9rem;
		color: #718096;
		margin-top: 0.5rem;
	}

	/* 참여자 섹션 */
	.participants-box {
		margin-top: 1.5rem;
	}

	.section-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 0.75rem;
		color: #333;
	}

	.participants-list {
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.participant-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 0.5rem 0;
		border-bottom: 1px solid #e2e8f0;
	}

	.participant-item:last-child {
		border-bottom: none;
	}

	.participant-name {
		font-size: 1rem;
		color: #4a5568;
	}

	.creator-tag {
		background-color: #064b45;
		color: white;
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	/* 만남 섹션 */
	.mannams-box {
		margin-top: 1.5rem;
	}

	.mannams-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.mannams-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.add-mannam-btn {
		display: flex;
		gap: 0.2rem;
		background-color: #064b45;
		color: white;
		border: none;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		transition: background-color 0.2s;
		align-items: center;
		font-size: 0.8rem;
		margin-top: -0.5rem;
	}

	.add-mannam-btn:hover {
		background-color: #043835;
	}

	/* 만남 생성 폼 스타일 */
	.create-mannam-content {
		padding: 1rem;
	}

	.create-mannam-form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-row {
		display: flex;
		gap: 1rem;
	}

	.flex-1 {
		flex: 1;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}

	.error-message {
		padding: 0.75rem;
		margin-bottom: 1rem;
		background-color: #fee2e2;
		border: 1px solid #f87171;
		border-radius: 0.375rem;
		color: #991b1b;
		font-size: 0.875rem;
	}

	.mannam-cell {
		background: white;
		padding: 1rem;
		border-radius: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		margin-bottom: 1rem;
		cursor: pointer;
		transition:
			transform 0.2s,
			box-shadow 0.2s;
	}

	.mannam-cell:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.mannam-meta {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 0.5rem;
	}

	.status {
		padding: 0.25rem 0.5rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.status.pending {
		background-color: #fef3c7;
		color: #92400e;
	}

	.status.confirmed {
		background-color: #d1fae5;
		color: #065f46;
	}

	.status.cancelled {
		background-color: #fee2e2;
		color: #991b1b;
	}

	.mannam-title {
		margin: 0 0 8px 0;
		font-size: 1.1rem;
		color: #2d3748;
	}

	.mannam-description {
		font-size: 0.9rem;
		color: #4a5568;
		margin: 0;
	}

	.empty-mannams {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		background: #fafafa;
		border-radius: 8px;
		color: #666;
	}

	.empty-text {
		margin: 0 0 16px;
		font-size: 1rem;
		color: #718096;
	}

	.error {
		color: #e53e3e;
		text-align: center;
		padding: 1rem;
		background: #fff5f5;
		border-radius: 6px;
	}

	.not-found {
		text-align: center;
		color: #e53e3e;
		padding: 1rem;
	}

	.join-description {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1f2937;
	}

	.join-description-sub {
		font-size: 0.875rem;
		color: #6b7280;
		margin-bottom: 2rem;
	}
</style>
