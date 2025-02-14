<script lang="ts">
	import { page } from '$app/stores';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { fade } from 'svelte/transition';
	import DateRangePicker from '$lib/components/DateRangePicker.svelte';
	import TimeRangePicker from '$lib/components/TimeRangePicker.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';

	// State variables
	let moim: any = null;
	let mannam: any = null;
	let loading = true;
	let error = '';
	let saving = false;

	// Form data
	let title = '';
	let description = '';
	let startDate: string | undefined;
	let endDate: string | undefined;
	let timeRange = {
		start: '09:00',
		end: '21:00'
	};
	let timeSlotMinutes = 30;

	onMount(loadData);

	async function loadData() {
		try {
			loading = true;
			error = '';

			// 1. 로그인 상태 확인
			const { data: sessionData } = await supabase.auth.getSession();
			if (!sessionData?.session) {
				await goto(`/${$page.params.invite_code}/invite`);
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
			if (moimError) throw new Error('모임 정보를 불러오는데 실패했습니다.');
			if (!moimData) throw new Error('모임을 찾을 수 없습니다.');
			moim = moimData;

			// 3. 만남 데이터 로드
			const { data: mannamData, error: mannamError } = await supabase
				.from('mannams')
				.select('*')
				.eq('sequence_number', $page.params.sequence_number)
				.eq('moim_id', moim.id)
				.single();
			if (mannamError) throw new Error('만남 정보를 불러오는데 실패했습니다.');
			if (!mannamData) throw new Error('만남을 찾을 수 없습니다.');
			mannam = mannamData;

			// 4. 권한 체크
			if (moim.creator_id !== $user?.id && mannam.creator_id !== $user?.id) {
				throw new Error('만남을 수정할 권한이 없습니다.');
			}

			// 5. 폼 데이터 초기화
			title = mannam.title;
			description = mannam.description || '';
			startDate = mannam.start_date;
			endDate = mannam.end_date;
			timeRange = mannam.time_range || {
				start: '09:00',
				end: '21:00'
			};
			timeSlotMinutes = mannam.time_slot_minutes || 30;
		} catch (err) {
			console.error('데이터 로드 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	async function handleSubmit() {
		try {
			saving = true;
			error = '';

			// 1. 입력값 검증
			if (!title) throw new Error('만남 제목을 입력해주세요.');
			if (!startDate || !endDate) throw new Error('만남 기간을 선택해주세요.');
			if (!timeRange.start || !timeRange.end) throw new Error('시간 범위를 선택해주세요.');

			// 2. 만남 정보 업데이트
			const updateData = {
				title,
				description,
				start_date: startDate,
				end_date: endDate,
				time_range: timeRange,
				time_slot_minutes: timeSlotMinutes,
				updated_at: new Date().toISOString()
			};
			const { error: updateError } = await supabase
				.from('mannams')
				.update(updateData)
				.eq('sequence_number', $page.params.sequence_number)
				.eq('moim_id', moim.id);

			if (updateError) throw new Error('만남 정보를 수정하는데 실패했습니다.');

			// 3. 만남 상세 페이지로 이동
			await goto(`/${$page.params.invite_code}/${$page.params.sequence_number}`);
		} catch (err) {
			console.error('만남 수정 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
			saving = false;
		}
	}
</script>

{#if loading}
	<div class="flex justify-center items-center h-32">
		<Spinner />
	</div>
{:else if error}
	<div class="error-container">
		<ErrorMessage message={error} />
	</div>
{:else}
	<div class="moim-container" in:fade={{ duration: 200 }}>
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<div class="header-content">
					<button class="back-btn font-regular" on:click={() => history.back()}>
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
						<span class="header-badge font-regular">수정</span>
						<h1 class="moim-title font-extrabold">만남 정보 수정</h1>
					</div>
				</div>
			</header>

			<main class="moim-content">
				<form on:submit|preventDefault={handleSubmit}>
					<!-- 만남 정보 입력 섹션 -->
					<section class="moim-section">
						<div class="form-group">
							<label for="title" class="form-label font-bold">만남 제목</label>
							<input
								type="text"
								id="title"
								class="form-input"
								placeholder="만남 제목을 입력해주세요"
								bind:value={title}
								required
							/>
						</div>

						<div class="form-group">
							<label for="description" class="form-label font-bold">만남 설명 (선택)</label>
							<textarea
								id="description"
								class="form-input"
								placeholder="만남에 대한 설명을 입력해주세요"
								bind:value={description}
								rows="3"
							/>
						</div>
					</section>

					<!-- 만남 기간 섹션 -->
					<section class="moim-section">
						<div class="form-group">
							<label class="form-label font-bold">만남 기간</label>
							<DateRangePicker
								bind:startDate
								bind:endDate
							/>
						</div>
					</section>

					<!-- 시간 범위 섹션 -->
					<section class="moim-section">
						<div class="form-group">
							<label class="form-label font-bold">시간 범위</label>
							<TimeRangePicker
								startTime={timeRange.start}
								endTime={timeRange.end}
								on:change={(e) => {
									timeRange = {
										start: e.detail.startTime,
										end: e.detail.endTime
									};
								}}
							/>
						</div>
					</section>

					<!-- 저장 버튼 -->
					<section class="submit-section">
						<button type="submit" class="submit-btn font-bold" disabled={saving}>
							{#if saving}
								<Spinner size="sm" />
								저장 중...
							{:else}
								저장하기
							{/if}
						</button>
					</section>
				</form>
			</main>
		</div>
	</div>
{/if}

<style>
	:global(body) {
		margin: 0;
		background: white;
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
		border-bottom: 1px solid #e5e7eb;
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
		background-color: #064b45;
		color: white;
		border-radius: 9999px;
		font-size: 0.75rem;
	}

	.moim-section {
		margin-bottom: 2rem;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-label {
		display: block;
		margin-bottom: 0.5rem;
		font-size: 0.875rem;
		color: #111827;
	}

	.form-input {
		width: 100%;
		padding: 0.75rem;
		font-size: 0.875rem;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		background-color: white;
		color: #111827;
	}

	.form-input::placeholder {
		color: #9ca3af;
	}

	.form-input:focus {
		outline: none;
		border-color: #064b45;
		box-shadow: 0 0 0 1px #064b45;
	}

	textarea.form-input {
		resize: vertical;
		min-height: 6rem;
	}

	.submit-section {
		margin-top: 3rem;
		margin-bottom: 2rem;
	}

	.submit-btn {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem;
		font-size: 0.875rem;
		background-color: #064b45;
		color: white;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.submit-btn:hover {
		background-color: #053c37;
	}

	.submit-btn:disabled {
		background-color: #9ca3af;
		cursor: not-allowed;
	}
</style> 