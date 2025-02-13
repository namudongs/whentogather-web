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
	import BottomSheet from '$lib/components/BottomSheet.svelte';
	import { goto } from '$app/navigation';

	// State variables
	let moim: any = null;
	let mannam: any = null;
	let responses: any[] = [];
	let loading = true;
	let error = '';
	let heatmapData: { [key: string]: number } = {};
	let myResponse: any = null;
	let selectedSlots: { date: string; slot: number }[] = [];
	let comment = '';

	// 바텀 시트 제어 변수 (응답 제출용)
	let showSubmitSheet = false;

	// 응답 제출 중임을 나타내는 변수 (스피너 표시용)
	let isSubmitting = false;

	// 응답자 배지(해시태그) 색상 배열 (인덱스 mod 연산으로 사용)
	const badgeColors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899'];

	// 백업용 변수: 바텀 시트 열기 전에 현재 상태를 백업
	let originalSlots: { date: string; slot: number }[] = [];
	let originalComment = '';

	// Computed properties
	$: isCreator = moim?.creator_id === $user?.id;
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
				await goto(`/moim/${$page.params.invite_code}/invite`);
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
				.eq('invite_code', $page.params.invite_code)
				.single();
			if (moimError) {
				console.error('모임 데이터 로드 에러:', moimError);
				throw new Error('모임 정보를 불러오는데 실패했습니다.');
			}
			if (!moimData) {
				throw new Error('모임을 찾을 수 없습니다.');
			}
			moim = moimData;

			// 3. 만남 데이터 로드
			const { data: mannamData, error: mannamError } = await supabase
				.from('mannams')
				.select(
					`
			*,
			moims!inner (*)
		  `
				)
				.eq('id', $page.params.mannam_id)
				.eq('moim_id', moim.id)
				.single();
			if (mannamError) {
				console.error('만남 데이터 로드 에러:', mannamError);
				throw new Error('만남 정보를 불러오는데 실패했습니다.');
			}
			if (!mannamData) {
				throw new Error('만남을 찾을 수 없습니다.');
			}
			mannam = mannamData;

			// 4. 응답 데이터 로드
			const { data: rawResponseData, error: responseError } = await supabase
				.from('mannam_responses')
				.select('*')
				.eq('mannam_id', mannam.id);
			let responseData = rawResponseData;
			if (responseData) {
				// 프로필 정보 가져오기
				const userIds = responseData.map((response) => response.user_id);
				const { data: profileData } = await supabase
					.from('profiles')
					.select('id, full_name, avatar_url')
					.in('id', userIds);
				// 응답 데이터와 프로필 정보 합치기
				responseData = responseData.map((response) => ({
					...response,
					profile: profileData?.find((profile) => profile.id === response.user_id)
				}));
			}
			if (responseError) {
				console.error('응답 데이터 로드 에러:', responseError);
				throw new Error('응답 정보를 불러오는데 실패했습니다.');
			}
			responses = responseData || [];

			// 히트맵 데이터 계산
			heatmapData = {};
			responses.forEach((response) => {
				const slots =
					typeof response.available_slots === 'string'
						? JSON.parse(response.available_slots)
						: response.available_slots;
				if (Array.isArray(slots)) {
					slots.forEach((slot: { date: string; slot: number }) => {
						const key = `${slot.date}-${slot.slot}`;
						heatmapData[key] = (heatmapData[key] || 0) + 1;
					});
				}
			});

			// 내 응답 찾기
			myResponse = responses.find((response) => response.user_id === $user?.id);
			if (myResponse) {
				selectedSlots =
					typeof myResponse.available_slots === 'string'
						? JSON.parse(myResponse.available_slots)
						: myResponse.available_slots;
				comment = myResponse.comment || '';
			}
		} catch (err) {
			console.error('데이터 로드 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	// 응답 제출 함수 (버튼 클릭 시 스피너 표시)
	async function handleSubmitResponse() {
		if (!$user) {
			error = '로그인이 필요합니다.';
			return;
		}
		isSubmitting = true;
		try {
			const responseData = {
				mannam_id: mannam.id,
				user_id: $user.id,
				available_slots: selectedSlots,
				comment
			};
			let result;
			if (myResponse) {
				result = await supabase
					.from('mannam_responses')
					.update(responseData)
					.eq('id', myResponse.id);
			} else {
				result = await supabase.from('mannam_responses').insert(responseData);
			}
			if (result.error) throw result.error;
			showSubmitSheet = false;
			// 응답 제출 후 데이터 다시 로드
			await loadData();
		} catch (err) {
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			isSubmitting = false;
		}
	}

	// TimeGrid의 슬롯 선택 변경 핸들러
	function handleSlotsChange(event: CustomEvent) {
		selectedSlots = event.detail.slots;
	}

	// 응답 제출 바텀 시트를 열기 전에 현재 상태 백업
	function openSubmitSheet() {
		originalSlots = JSON.parse(JSON.stringify(selectedSlots));
		originalComment = comment;
		showSubmitSheet = true;
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
	<div class="moim-container">
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<button class="back-btn" on:click={() => history.back()} aria-label="뒤로가기">
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
				<h1 class="moim-title">{mannam.title}</h1>
			</header>

			<main class="moim-content">
				<!-- 만남 정보 섹션 -->
				<div class="info-box">
					{#if mannam.description}
						<p class="section-description">{mannam.description}</p>
					{:else}
						<p class="no-description">설명 없음</p>
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
					</div>
				</div>

				<!-- 전체 응답 현황 섹션 -->
				<div class="info-box response-status">
					<h2 class="section-title">전체 응답 현황</h2>
					<TimeGrid
						startDate={mannam.start_date}
						endDate={mannam.end_date}
						timeRange={mannam.time_range}
						timeSlotMinutes={mannam.time_slot_minutes}
						readOnly={true}
						{heatmapData}
					/>
					<p class="grid-caption">* 색상이 진할수록 더 많은 참여자가 가능한 시간입니다.</p>
					
					<!-- 응답자 해시태그 -->
					<div class="badge-container">
						{#each responses as response, index}
							<span
								class="response-badge"
								style="background-color: {badgeColors[index % badgeColors.length]};"
							>
								#{response.profile?.full_name || '이름 없음'}
							</span>
						{/each}
					</div>
				</div>
			</main>

			<!-- 하단 커스텀 버튼 (응답 제출하기 버튼) -->
			<div class="button-row">
				<button class="custom-btn submit-btn" on:click={openSubmitSheet}> 응답 제출하기 </button>
			</div>
		</div>
	</div>
{/if}

<!-- 응답 제출 바텀 시트 -->
<BottomSheet
	show={showSubmitSheet}
	onClose={() => {
		// 취소 시 백업된 상태로 복원
		selectedSlots = JSON.parse(JSON.stringify(originalSlots));
		comment = originalComment;
		showSubmitSheet = false;
	}}
	title="응답 제출"
	blurBackground={true}
>
	<div class="submit-sheet-content">
		{#if mannam.status === 'pending'}
			<div class="grid-container">
				<TimeGrid
					startDate={mannam.start_date}
					endDate={mannam.end_date}
					timeRange={mannam.time_range}
					timeSlotMinutes={mannam.time_slot_minutes}
					{selectedSlots}
					on:change={handleSlotsChange}
				/>
			</div>
			<div class="form-group">
				<label for="comment" class="form-label">코멘트 (선택사항)</label>
				<!-- svelte-ignore element_invalid_self_closing_tag -->
				<textarea
					id="comment"
					bind:value={comment}
					class="form-input"
					placeholder="코멘트를 입력하세요..."
				/>
			</div>
			<div class="sheet-actions">
				<button
					class="sheet-btn cancel-btn"
					on:click={() => {
						// 취소 시 백업된 값으로 복원
						selectedSlots = JSON.parse(JSON.stringify(originalSlots));
						comment = originalComment;
						showSubmitSheet = false;
					}}>취소</button
				>
				<button class="sheet-btn submit-btn" on:click={handleSubmitResponse}>
					{#if isSubmitting}
						<Spinner size="small" />
						<span class="submit-text">제출 중</span>
					{:else}
						응답 제출
					{/if}
				</button>
			</div>
		{:else}
			<div class="info-message">이미 확정된 만남은 응답을 제출할 수 없습니다.</div>
		{/if}
	</div>
</BottomSheet>

<style>
	:global(body) {
		background-color: white;
		margin: 0;
		font-family: 'Pretendard Variable', -apple-system, BlinkMacSystemFont, system-ui, Roboto, sans-serif;
	}
	.moim-container {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
	}
	.moim-content-wrapper {
		background: white;
	}
	.moim-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		border-bottom: 1px solid #f0f0f0;
	}
	.back-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		color: #064b45;
		display: flex;
		align-items: center;
	}
	.moim-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0;
		color: #111827;
	}
	.moim-content {
		padding: 1rem;
	}
	.info-box {
		background: #f9fafb;
		padding: 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
	}
	.section-title {
		font-size: 1.125rem;
		font-weight: 600;
		margin: 0 0 1rem 0;
		color: #111827;
	}
	.section-description,
	.no-description {
		margin: 0 0 1rem 0;
		color: #4b5563;
		font-size: 0.875rem;
		line-height: 1.5;
	}
	.meta {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 2rem;
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
	.grid-container {
		display: flex;
		justify-content: center;
		margin: 1rem 0;
	}
	.badge-container {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}
	.response-badge {
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
		font-weight: 500;
		color: white;
	}
	.button-row {
		padding: 1rem;
		background: white;
		position: sticky;
		bottom: 0;
	}
	.custom-btn.submit-btn {
		width: 100%;
		padding: 0.875rem;
		border: none;
		border-radius: 4px;
		background-color: #064b45;
		color: white;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
	}
	.global-spinner {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: rgba(255, 255, 255, 0.75);
	}
	.error-container {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		background-color: rgba(255, 255, 255, 0.75);
	}
	/* BottomSheet 내부 스타일 */
	.submit-sheet-content {
		padding: 1rem;
	}
	.submit-sheet-content .grid-container {
		margin-bottom: 1rem;
	}
	.form-group {
		margin-top: 1.5rem;
	}
	.form-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
	}
	.form-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		resize: vertical;
	}
	.form-input:focus {
		outline: none;
		border-color: #064b45;
		box-shadow: 0 0 0 2px rgba(6, 75, 69, 0.1);
	}
	.sheet-actions {
		display: flex;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}
	.sheet-btn {
		flex: 1;
		padding: 0.875rem;
		border: none;
		border-radius: 4px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
	}
	.sheet-btn.cancel-btn {
		background-color: #f3f4f6;
		color: #374151;
	}
	.sheet-btn.submit-btn {
		background-color: #064b45;
		color: white;
	}
	.submit-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		white-space: nowrap;
		gap: 0.5rem;
		padding: 0.75rem;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
		background-color: #064b45;
		color: white;
	}
	.response-status {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.grid-caption {
		font-size: 0.75rem;
		color: #6b7280;
		margin: 0.5rem 0 0 0;
		text-align: center;
	}
</style>
