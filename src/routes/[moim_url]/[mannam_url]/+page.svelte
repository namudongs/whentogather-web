<script lang="ts">
	import { page } from '$app/stores';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { format } from 'date-fns';
	import { ko } from 'date-fns/locale/ko';
	import TimeGrid from '$lib/components/mannam/TimeGrid.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import { goto } from '$app/navigation';
	import { fade } from 'svelte/transition';
	import ParticipantAvatar from '$lib/components/ParticipantAvatar.svelte';
	import BottomSheet from '$lib/components/BottomSheet.svelte';

	// State variables
	let moim: any = null;
	let mannam: any = null;
	let responses: any[] = [];
	let loading = true;
	let error = '';
	let heatmapData: { [key: string]: number } = {};
	let myResponse: any = null;
	let isDeleteSheetOpen = false;
	let isDeleteConfirmSheetOpen = false;
	let deleteType: 'cancel' | 'delete' | 'activate' | null = null;
	let timeGridComponent: any;
	let showAvatars = true;

	interface Profile {
		id: string;
		name: string;
		email: string;
		avatar_url: string;
	}

	// Computed properties
	$: isCreator = moim?.creator_id === $user?.id || mannam?.creator_id === $user?.id;
	$: formattedStartDate = mannam?.start_date
		? format(new Date(mannam.start_date), 'PPP', { locale: ko })
		: '';
	$: formattedEndDate = mannam?.end_date
		? format(new Date(mannam.end_date), 'PPP', { locale: ko })
		: '';

	onMount(loadData);

	async function loadData() {
		try {
			loading = true;
			error = '';

			// 1. 로그인 상태 확인
			const { data: sessionData } = await supabase.auth.getSession();
			if (!sessionData?.session) {
				await goto(`/${$page.params.moim_url}/invite`);
				return;
			}

			// 2. 모임 데이터 로드
			const { data: moimData, error: moimError } = await supabase
				.from('moims')
				.select(
					`
					*,
					moim_participants!inner (*)
				`
				)
				.eq('moim_url', $page.params.moim_url)
				.single();
			if (moimError) throw new Error('모임 정보를 불러오는데 실패했습니다.');
			if (!moimData) throw new Error('모임을 찾을 수 없습니다.');
			moim = moimData;

			// 3. 만남 데이터 로드
			const { data: mannamData, error: mannamError } = await supabase
				.from('mannams')
				.select('*')
				.eq('mannam_url', $page.params.mannam_url)
				.eq('moim_id', moim.id)
				.single();
			if (mannamError) throw new Error('만남 정보를 불러오는데 실패했습니다.');
			if (!mannamData) throw new Error('만남을 찾을 수 없습니다.');
			mannam = mannamData;

			// 4. 응답 데이터 로드
			const { data: responsesData, error: responsesError } = await supabase
				.from('mannam_responses')
				.select('*')
				.eq('mannam_id', mannam.id);
			if (responsesError) {
				console.error('응답 데이터 로드 에러:', responsesError);
				throw new Error('응답 정보를 불러오는데 실패했습니다.');
			}

			// 프로필 정보 로드
			const userIds = responsesData.map(r => r.user_id);
			let profilesData: Profile[] = [];
			
			if (userIds.length > 0) {
				const { data: profiles, error: profilesError } = await supabase
					.from('profiles')
					.select('id, name, email, avatar_url')
					.in('id', userIds);

				if (profilesError) {
					console.error('프로필 데이터 로드 에러:', profilesError);
					throw new Error('프로필 정보를 불러오는데 실패했습니다.');
				}
				profilesData = profiles || [];
			}

			// 응답 데이터와 프로필 정보 결합
			responses = responsesData.map(response => ({
				...response,
				user: profilesData.find(p => p.id === response.user_id) || { 
					id: response.user_id, 
					name: '이름없음',
					email: '',
					avatar_url: ''
				}
			}));

			// 5. 내 응답 찾기
			myResponse = responses.find((response) => response.user_id === $user?.id);

			// 6. 히트맵 데이터 생성
			heatmapData = responses.reduce((acc: any, response) => {
				try {
					const slots = Array.isArray(response.available_slots) 
						? response.available_slots 
						: JSON.parse(response.available_slots || '[]');
					slots.forEach((slot: any) => {
						const key = `${slot.date}-${slot.slot}`;
						acc[key] = (acc[key] || 0) + 1;
					});
				} catch (err) {
					console.error('히트맵 데이터 생성 중 에러:', err);
				}
				return acc;
			}, {});
		} catch (err) {
			console.error('데이터 로드 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	async function handleEdit() {
		await goto(`/${$page.params.moim_url}/${$page.params.mannam_url}/edit`);
	}

	async function handleDelete() {
		try {
			if (deleteType === 'activate') {
				const { error: updateError } = await supabase
					.from('mannams')
					.update({
						status: 'pending'
					})
					.eq('mannam_url', $page.params.mannam_url)
					.eq('moim_id', moim.id);

				if (updateError) {
					console.error('활성화 에러 상세:', updateError);
					throw new Error(`만남을 다시 활성화하는데 실패했습니다: ${updateError.message}`);
				}
			} else if (deleteType === 'cancel') {
				const { error: updateError } = await supabase
					.from('mannams')
					.update({
						status: 'cancelled',
						confirmed_slots: []
					})
					.eq('mannam_url', $page.params.mannam_url)
					.eq('moim_id', moim.id);

				if (updateError) {
					console.error('취소 에러 상세:', updateError);
					throw new Error(`만남을 취소하는데 실패했습니다: ${updateError.message}`);
				}
			} else {
				const { error: deleteError } = await supabase
					.from('mannams')
					.delete()
					.eq('mannam_url', $page.params.mannam_url)
					.eq('moim_id', moim.id);

				if (deleteError) throw new Error('만남을 삭제하는데 실패했습니다.');
				
				// 삭제의 경우에만 모임 목록으로 이동
				await goto(`/${$page.params.moim_url}`);
				return;
			}

			// 취소나 활성화의 경우 현재 페이지 새로고침
			await loadData();
			isDeleteConfirmSheetOpen = false;
		} catch (err) {
			console.error(`만남 ${deleteType === 'activate' ? '활성화' : (deleteType === 'cancel' ? '취소' : '삭제')} 중 에러 발생:`, err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		}
	}

	function handleDeleteClick(type: 'cancel' | 'delete' | 'activate') {
		deleteType = type;
		isDeleteSheetOpen = false;
		isDeleteConfirmSheetOpen = true;
	}
</script>

{#if loading}
	<div class="global-spinner">
		<Spinner size="large" />
	</div>
{:else if error}
	<div class="error-container">
		<ErrorMessage message={error} />
	</div>
{:else}
	<div class="moim-container" in:fade={{duration: 200}}>
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<div class="header-content">
					<button 
						class="back-btn font-regular" 
						on:click={() => goto(`/${$page.params.moim_url}`)}
						aria-label="뒤로 가기"
					>
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
							<path d="M19 12H5M12 19l-7-7 7-7" />
						</svg>
					</button>
					<div class="title-with-badge">
						<span class="header-badge font-regular" class:confirmed={mannam.status === 'confirmed'} class:cancelled={mannam.status === 'cancelled'}>
							{#if mannam.status === 'confirmed'}
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M20 6L9 17l-5-5"></path>
								</svg>
							{:else if mannam.status === 'cancelled'}
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<line x1="18" y1="6" x2="6" y2="18"></line>
									<line x1="6" y1="6" x2="18" y2="18"></line>
								</svg>
							{:else}
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<circle cx="12" cy="12" r="10"></circle>
									<polyline points="12 6 12 12 16 14"></polyline>
								</svg>
							{/if}
							{#if mannam.status === 'confirmed'}
								확정
							{:else if mannam.status === 'cancelled'}
								취소
							{:else}
								조율 중
							{/if}
						</span>
						<h1 class="moim-title font-extrabold">{mannam.title}</h1>
					</div>
				</div>
			</header>

			<main class="moim-content">
				<!-- 만남 정보 섹션 -->
				<section class="moim-description-section">
					{#if mannam.description}
						<p class="moim-description font-regular">{mannam.description}</p>
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
							<span class="info-text">{formattedStartDate} ~ {formattedEndDate}</span>
						</div>
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
									d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
								/>
							</svg>
							<span class="info-text"
								>시간 범위: {mannam.time_range?.start || '09:00'} ~ {mannam.time_range?.end ||
									'21:00'}</span
							>
						</div>
						{#if mannam.status === 'confirmed' && mannam.confirmed_slots?.length > 0}
							<div class="info-item confirmed">
								<svg
									class="info-icon"
									xmlns="http://www.w3.org/2000/svg"
									viewBox="0 0 24 24"
									fill="none"
									stroke="currentColor"
									stroke-width="2"
								>
									<path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								<span class="info-text">
									확정 시간: {format(new Date(mannam.confirmed_slots[0].date), 'M.d (E)', { locale: ko })} {mannam.confirmed_slots[0].slot}
									{#if mannam.confirmed_slots.length > 1}
										~ {format(new Date(mannam.confirmed_slots[mannam.confirmed_slots.length - 1].date), 'M.d (E)', { locale: ko })} {mannam.confirmed_slots[mannam.confirmed_slots.length - 1].slot}
									{/if}
								</span>
							</div>
						{/if}
					</div>
					{#if isCreator}
						<div class="badge-buttons">
							<button class="badge-button" on:click={handleEdit}>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
									<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
								</svg>
							    정보 수정
							</button>
							{#if responses.length > 0}
								<button class="badge-button confirm" on:click={() => goto(`/${$page.params.moim_url}/${$page.params.mannam_url}/confirm`)}>
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
									</svg>
									{mannam.status === 'confirmed' ? '확정 시간 변경' : '시간 확정'}
								</button>
							{/if}
							<button class="badge-button delete" on:click={() => isDeleteSheetOpen = true}>
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M3 6h18"></path>
									<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
								</svg>
								{mannam.status === 'cancelled' ? '관리' : '관리'}
							</button>
						</div>
					{/if}
				</section>

				<!-- 응답자 섹션 -->
				{#if responses.length > 0}
					<section class="moim-section">
						<div class="section-header">
							<div class="title-with-badge">
								<h2 class="section-title font-bold">응답자</h2>
								<div class="count-badge font-regular">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
										<circle cx="9" cy="7" r="4"></circle>
										<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
										<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
									</svg>
									{responses.length}명
								</div>
							</div>
						</div>
						<div class="participants-grid">
							{#each responses as response}
								<ParticipantAvatar
									name={response.user?.name || '이름없음'}
									role="participant"
									avatarUrl={response.user?.avatar_url}
									email={response.user?.email}
								/>
							{/each}
						</div>
					</section>
				{/if}

				<!-- 응답하기 버튼 섹션 -->
				<section class="response-button-section">
					<button 
						type="button"
						class="create-btn font-bold"
						class:responded={myResponse}
						on:click={() => goto(`/${$page.params.moim_url}/${$page.params.mannam_url}/respond`)}
					>
						<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
							<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
						</svg>
						{myResponse ? '응답 수정하기' : '시간 조율 응답하기'}
					</button>
				</section>

				<!-- 전체 응답 현황 섹션 -->
				<section class="moim-section">
					<div class="section-header">
						<div class="title-with-badge">
							<h2 class="section-title font-bold">응답 현황</h2>
							<button 
								class="avatar-toggle-btn font-regular" 
								on:click={() => showAvatars = !showAvatars}
							>
								{#if showAvatars}
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
										<circle cx="9" cy="7" r="4"></circle>
										<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
										<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
									</svg>
									<span>아바타 숨기기</span>
								{:else}
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
										<circle cx="9" cy="7" r="4"></circle>
										<path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
										<path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
										<line x1="1" y1="1" x2="23" y2="23"></line>
									</svg>
									<span>아바타 표시</span>
								{/if}
							</button>
						</div>
					</div>

					<div class="grid-container">
						<TimeGrid
							startDate={mannam.start_date}
							endDate={mannam.end_date}
							timeRange={mannam.time_range}
							timeSlotMinutes={mannam.time_slot_minutes}
							{heatmapData}
							readOnly={true}
							confirmedSlots={mannam.confirmed_slots || []}
							bind:showAvatars
							responses={responses.map(response => ({
								user: response.user,
								available_slots: Array.isArray(response.available_slots)
									? response.available_slots
									: JSON.parse(response.available_slots || '[]')
							}))}
						/>
					</div>

					{#if responses.length > 0}
						<div class="responses-list">
							{#each responses as response}
								{#if response.comment}
									<div class="response-item">
										<div class="response-header">
											<span class="response-name font-bold">{response.user?.name || '이름없음'}</span>
											<span class="response-comment font-regular">{response.comment}</span>
										</div>
									</div>
								{/if}
							{/each}
						</div>
					{/if}
				</section>
			</main>
		</div>
	</div>

	<!-- 삭제 시트 -->
	<BottomSheet
		show={isDeleteSheetOpen}
		onClose={() => isDeleteSheetOpen = false}
		title="만남 관리"
	>
		<div class="sheet-content">
			{#if mannam.status === 'cancelled'}
				<button class="sheet-button" on:click={() => handleDeleteClick('activate')}>
					<div class="sheet-button-content">
						<div class="sheet-button-title">만남 다시 활성화하기</div>
						<div class="sheet-button-description">취소된 만남을 다시 활성화합니다.
참가자들이 다시 응답할 수 있습니다.</div>
					</div>
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M9 18l6-6-6-6"></path>
					</svg>
				</button>
			{:else}
				<button class="sheet-button" on:click={() => handleDeleteClick('cancel')}>
					<div class="sheet-button-content">
						<div class="sheet-button-title">만남 취소하기</div>
						<div class="sheet-button-description">만남을 취소 상태로 변경합니다.
나중에 다시 활성화할 수 있습니다.</div>
					</div>
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M9 18l6-6-6-6"></path>
					</svg>
				</button>
			{/if}
			<button class="sheet-button delete" on:click={() => handleDeleteClick('delete')}>
				<div class="sheet-button-content">
					<div class="sheet-button-title">만남 삭제하기</div>
					<div class="sheet-button-description">만남을 영구적으로 삭제합니다.
이 작업은 되돌릴 수 없습니다.</div>
				</div>
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 18l6-6-6-6"></path>
				</svg>
			</button>
		</div>
	</BottomSheet>

	<!-- 삭제 확인 시트 -->
	<BottomSheet
		show={isDeleteConfirmSheetOpen}
		onClose={() => isDeleteConfirmSheetOpen = false}
		title={deleteType === 'activate' ? '만남을 다시 활성화하시겠습니까?' : (deleteType === 'cancel' ? '만남을 취소하시겠습니까?' : '만남을 삭제하시겠습니까?')}
	>
		<div class="sheet-content">
			<div class="sheet-description">
				{#if deleteType === 'activate'}
					만남을 다시 활성화하면 참가자들이 다시 응답할 수 있습니다.
				{:else if deleteType === 'cancel'}
					만남을 취소하면 취소 상태로 변경되며,
나중에 다시 활성화할 수 있습니다.
				{:else}
					만남을 삭제하면 모든 데이터가 영구적으로 삭제되며,
이 작업은 되돌릴 수 없습니다.
				{/if}
			</div>
			<div class="sheet-buttons">
				<button class="sheet-button cancel" on:click={() => isDeleteConfirmSheetOpen = false}>
					취소
				</button>
				<button class="sheet-button delete" on:click={handleDelete}>
					{deleteType === 'activate' ? '다시 활성화하기' : (deleteType === 'cancel' ? '만남 취소하기' : '만남 삭제하기')}
				</button>
			</div>
		</div>
	</BottomSheet>
{/if}

<style>
	:global(body) {
		margin: 0;
		background: white;
	}

	.global-spinner {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: rgba(255, 255, 255, 0.8);
		z-index: 9999;
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

	.title-with-badge {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.header-badge {
		padding: 0.25rem 0.5rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		transition: all 0.2s ease;
		background-color: rgba(251, 146, 60, 0.15);
		color: rgb(194, 65, 12);
	}

	.header-badge svg {
		width: 14px;
		height: 14px;
		color: currentColor;
	}

	.header-badge.confirmed {
		background-color: rgba(74, 222, 128, 0.15);
		color: rgb(22, 101, 52);
	}

	.header-badge.cancelled {
		background-color: rgba(248, 113, 113, 0.15);
		color: rgb(153, 27, 27);
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

	.count-badge {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		padding: 0.25rem 0.5rem;
		background-color: rgb(243 244 246);
		border-radius: 9999px;
		font-size: 0.875rem;
	}

	.grid-container {
		margin-bottom: 1.5rem;
	}

	.responses-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.response-item {
		padding: 1rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
	}

	.response-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.response-name {
		font-size: 0.875rem;
		color: #111827;
	}

	.response-comment {
		font-size: 0.875rem;
		color: #6b7280;
	}

	.response-button-section {
		margin-bottom: 2rem;
	}

	.create-btn {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem;
		font-size: 0.875rem;
		background-color: #064b45;
		color: white;
		border: 1px solid #064b45;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.create-btn:hover {
		background-color: #053c37;
		border-color: #053c37;
	}

	.create-btn.responded {
		background-color: white;
		color: #064b45;
		border: 1px solid #064b45;
	}

	.create-btn.responded:hover {
		background-color: #f8fafc;
	}

	.create-btn svg {
		width: 1.25rem;
		height: 1.25rem;
	}

	.participants-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin: -0.25rem;
		padding: 0.25rem;
	}

	.badge-buttons {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}
	
	.badge-button {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.375rem 0.75rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 9999px;
		font-size: 0.75rem;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.badge-button:hover {
		border-color: #064b45;
		color: #064b45;
	}

	.badge-button.delete {
		background: white;
		border-color: #e5e7eb;
		color: #374151;
	}

	.badge-button.delete:hover {
		border-color: #ef4444;
		color: #ef4444;
		background: white;
	}

	.badge-button svg {
		color: currentColor;
	}

	.sheet-content {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.sheet-button {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		padding: 1rem;
		background: none;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		cursor: pointer;
		color: #111827;
		transition: all 0.2s ease;
		outline: 1px solid transparent;
	}

	.sheet-button:hover {
		background-color: #f3f4f6;
		outline: 1px solid #e5e7eb;
	}

	.sheet-button:first-child {
		color: #374151;
		background-color: #f3f4f6;
	}

	.sheet-button:first-child:hover {
		background-color: #e5e7eb;
		outline: 1px solid #d1d5db;
	}

	.sheet-button.delete {
		color: #ef4444;
		background-color: #fef2f2;
	}

	.sheet-button.delete:hover {
		background-color: #fee2e2;
		outline: 1px solid #fca5a5;
	}

	.sheet-button.cancel {
		color: #6b7280;
		background-color: #f3f4f6;
	}

	.sheet-button.cancel:hover {
		background-color: #e5e7eb;
		outline: 1px solid #d1d5db;
	}

	.sheet-button-content {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 0.25rem;
		text-align: left;
	}

	.sheet-button-title {
		font-size: 1rem;
		font-weight: 500;
	}

	.sheet-button-description {
		font-size: 0.875rem;
		color: #6b7280;
		white-space: pre-line;
	}

	.sheet-description {
		padding: 1rem;
		margin-bottom: 1rem;
		background-color: #f8fafc;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.5;
		white-space: pre-line;
	}

	.sheet-buttons {
		display: flex;
		gap: 0.5rem;
	}

	.sheet-buttons .sheet-button {
		flex: 1;
		justify-content: center;
		padding: 0.75rem;
		font-weight: 500;
	}

	.sheet-buttons .sheet-button.delete {
		background-color: #ef4444;
		color: white;
		border: 1px solid #ef4444;
	}

	.sheet-buttons .sheet-button.delete:hover {
		background-color: #dc2626;
		border-color: #dc2626;
	}

	.sheet-buttons .sheet-button.cancel {
		background-color: #f3f4f6;
		color: #6b7280;
		border: 1px solid #e5e7eb;
	}

	.sheet-buttons .sheet-button.cancel:hover {
		background-color: #e5e7eb;
		border-color: #d1d5db;
	}

	.badge-button.confirm {
		background: white;
		border-color: #e5e7eb;
		color: #374151;
	}

	.badge-button.confirm:hover {
		border-color: #064b45;
		color: #064b45;
		background: white;
	}

	.avatar-toggle-btn {
		display: flex;
		align-items: center;
		gap: 0.375rem;
		padding: 0.375rem 0.75rem;
		background: #f3f4f6;
		border: none;
		border-radius: 9999px;
		font-size: 0.75rem;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s ease;
		margin-left: 0.5rem;
	}

	.avatar-toggle-btn:hover {
		background-color: #e5e7eb;
		color: #064b45;
	}

	.avatar-toggle-btn svg {
		color: currentColor;
	}
	
	.info-item.confirmed {
		color: #16a34a;
	}

	.info-item.confirmed .info-icon {
		color: #16a34a;
	}
</style>
