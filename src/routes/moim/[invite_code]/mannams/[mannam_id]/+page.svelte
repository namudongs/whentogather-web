<script lang="ts">
	import { page } from '$app/stores';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { format } from 'date-fns';
	import { ko } from 'date-fns/locale/ko';
	import { fade, fly } from 'svelte/transition';
	import { goto } from '$app/navigation';
	import TimeGrid from '$lib/components/mannam/TimeGrid.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import Button from '$lib/components/Button.svelte';

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
				.select(`
					*,
					moim_participants!inner (*)
				`)
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
				.select(`
					*,
					moims!inner (*)
				`)
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
				const userIds = responseData.map(response => response.user_id);
				const { data: profileData } = await supabase
					.from('profiles')
					.select('id, full_name, avatar_url')
					.in('id', userIds);

				// 응답 데이터와 프로필 정보 합치기
				responseData = responseData.map(response => ({
					...response,
					profile: profileData?.find(profile => profile.id === response.user_id)
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
				response.available_slots.forEach((slot: { date: string; slot: number }) => {
					const key = `${slot.date}-${slot.slot}`;
					heatmapData[key] = (heatmapData[key] || 0) + 1;
				});
			});

			// 내 응답 찾기
			myResponse = responses.find((response) => response.user_id === $user?.id);
			if (myResponse) {
				selectedSlots = myResponse.available_slots;
				comment = myResponse.comment || '';
			}
		} catch (err) {
			console.error('데이터 로드 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	async function handleSubmitResponse() {
		if (!$user) {
			error = '로그인이 필요합니다.';
			return;
		}

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

			// 데이터 다시 로드
			await loadData();
		} catch (err) {
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		}
	}

	function handleSlotsChange(event: CustomEvent) {
		selectedSlots = event.detail.slots;
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
	<div
		class="moim-container"
		in:fly={{ y: 50, duration: 400, delay: 200 }}
		out:fade={{ duration: 200 }}
	>
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
				<h1 class="moim-title">만남 상세</h1>
			</header>

			<main class="moim-content">
				<!-- 만남 정보 -->
				<div class="info-box">
					<h2 class="section-title">{mannam.title}</h2>
					{#if mannam.description}
						<p class="section-description">{mannam.description}</p>
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

				<!-- 전체 응답 현황 -->
				<div class="info-box">
					<h3 class="section-title">전체 응답 현황</h3>
					<div class="grid-container">
						<TimeGrid
							startDate={mannam.start_date}
							endDate={mannam.end_date}
							timeRange={mannam.time_range}
							timeSlotMinutes={mannam.time_slot_minutes}
							readOnly={true}
							{heatmapData}
						/>
						<p class="mt-2 text-sm text-gray-500">
							* 색상이 진할수록 더 많은 참여자가 가능한 시간입니다.
						</p>
					</div>
				</div>

				<!-- 응답자 목록 -->
				<div class="info-box">
					<h3 class="section-title">응답자 목록 ({responses.length}명)</h3>
					<div class="response-list">
						{#each responses as response (response.id)}
							<div class="response-item">
								<div class="response-user">
									<span class="user-name">{response.profile?.full_name || '이름 없음'}</span>
									{#if response.comment}
										<p class="user-comment">{response.comment}</p>
									{/if}
								</div>
							</div>
						{/each}
					</div>
				</div>

				<!-- 내 응답 -->
				<div class="info-box">
					<h3 class="section-title">내 응답</h3>
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

							<div class="form-group mt-4">
								<label for="comment" class="mb-2 block text-sm font-medium text-gray-700">
									코멘트 (선택사항)
								</label>
								<textarea
									id="comment"
									bind:value={comment}
									class="h-24 w-full rounded-md border border-gray-300 px-3 py-2"
									placeholder="코멘트를 입력하세요..."
								/>
							</div>

							<div class="actions">
								<Button on:click={handleSubmitResponse}>응답 제출</Button>
							</div>
						</div>
					{:else}
						<div class="info-message">이미 확정된 만남은 시간을 조율할 수 없습니다.</div>
					{/if}
				</div>
			</main>
		</div>
	</div>
{/if}

<style>
	.moim-container {
		margin: 0 auto;
		width: 100%;
		max-width: 896px;
		padding: 1.5rem 1rem;
	}

	.moim-content-wrapper {
		overflow: hidden;
		border-radius: 0.5rem;
		background-color: white;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
	}

	.moim-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		border-bottom: 1px solid #e5e7eb;
		padding: 1rem;
	}

	.back-btn {
		border-radius: 9999px;
		padding: 0.5rem;
		transition: background-color 0.2s;
	}

	.back-btn:hover {
		background-color: #f3f4f6;
	}

	.moim-title {
		font-size: 1.25rem;
		font-weight: 700;
	}

	.moim-content {
		padding: 1.5rem;
	}

	.info-box {
		margin-bottom: 2rem;
	}

	.info-box:last-child {
		margin-bottom: 0;
	}

	.section-title {
		margin-bottom: 1rem;
		font-size: 1.125rem;
		font-weight: 700;
	}

	.section-description {
		margin-bottom: 1rem;
		color: #4b5563;
	}

	.meta {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.info-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #4b5563;
	}

	.info-icon {
		height: 1.25rem;
		width: 1.25rem;
	}

	.grid-container {
		width: 100%;
		overflow-x: auto;
		max-width: 100%;
		-webkit-overflow-scrolling: touch;
	}

	.response-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.response-item {
		border-radius: 0.5rem;
		border: 1px solid #e5e7eb;
		padding: 1rem;
	}

	.response-user {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.user-name {
		font-weight: 500;
	}

	.user-comment {
		font-size: 0.875rem;
		color: #4b5563;
	}

	.actions {
		margin-top: 1.5rem;
		display: flex;
		justify-content: flex-end;
	}

	.info-message {
		padding: 1rem 0;
		text-align: center;
		color: #4b5563;
	}

	.form-group {
		margin-top: 1.5rem;
	}

	textarea {
		width: 100%;
		border-radius: 0.375rem;
		border: 1px solid #d1d5db;
		padding: 0.75rem;
		min-height: 100px;
		resize: vertical;
	}

	textarea:focus {
		outline: none;
		border-color: transparent;
		box-shadow: 0 0 0 2px #3b82f6;
	}

	:global(.time-grid) {
		border-radius: 0.5rem;
		border: 1px solid #e5e7eb;
		background-color: white;
		min-width: 600px;
	}

	:global(.time-grid-cell) {
		border: 1px solid #e5e7eb;
		transition: background-color 0.2s;
		width: 30px;
		height: 30px;
	}

	:global(.time-grid-cell.selected) {
		background-color: #3b82f6;
	}

	:global(.time-grid-cell.heatmap-0) {
		background-color: #f9fafb;
	}

	:global(.time-grid-cell.heatmap-1) {
		background-color: #dbeafe;
	}

	:global(.time-grid-cell.heatmap-2) {
		background-color: #bfdbfe;
	}

	:global(.time-grid-cell.heatmap-3) {
		background-color: #93c5fd;
	}

	:global(.time-grid-cell.heatmap-4) {
		background-color: #60a5fa;
	}

	:global(.time-grid-cell.heatmap-5) {
		background-color: #3b82f6;
	}

	:global(.time-grid-header) {
		position: sticky;
		top: 0;
		z-index: 10;
		background-color: white;
		padding: 0.25rem 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	:global(.time-grid-time) {
		position: sticky;
		left: 0;
		z-index: 10;
		background-color: white;
		padding: 0.25rem 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
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
</style>
