<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import Button from '$lib/components/Button.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import DateRangePicker from '$lib/components/DateRangePicker.svelte';
	import TimeRangePicker from '$lib/components/TimeRangePicker.svelte';

	let moim: any = null;
	let loading = true;
	let errorMessage = '';

	// 만남 생성 폼 데이터
	let mannamTitle = '';
	let mannamDescription = '';
	let mannamStartDate = '';
	let mannamEndDate = '';
	let mannamTimeRange = { start: '00:00', end: '23:00' };
	let mannamTimeSlotMinutes = 60;
	let mannamError = '';

	async function loadMoimData() {
		try {
			loading = true;
			// 1) 로그인 상태 확인
			const { data: sessionData } = await supabase.auth.getSession();
			if (!sessionData?.session) {
				await goto(`/moim/${$page.params.invite_code}/invite`);
				return;
			}

			// 2) 모임 정보 조회
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

			if (moimError) throw moimError;
			if (!moimData) throw new Error('모임을 찾을 수 없습니다.');
			moim = moimData;
		} catch (err) {
			errorMessage = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	async function handleCreateMannam(event: Event) {
		event.preventDefault();
		if (!moim || !$user) return;

		// 필수 입력값 검증
		if (!mannamTitle.trim()) {
			mannamError = '만남 제목을 입력해주세요.';
			return;
		}
		if (!mannamStartDate || !mannamEndDate) {
			mannamError = '만남 날짜를 선택해주세요.';
			return;
		}
		if (!mannamTimeRange.start || !mannamTimeRange.end) {
			mannamError = '만남 시간을 선택해주세요.';
			return;
		}

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
			await goto(`/moim/${$page.params.invite_code}/mannams/${mannam.id}`, { replaceState: true });
		} catch (err) {
			mannamError = err instanceof Error ? err.message : '만남을 생성하는 중에 오류가 발생했습니다.';
		}
	}

	// 페이지 로드 시 모임 데이터 불러오기
	loadMoimData();
</script>

<div class="create-mannam-container">
	<header class="create-mannam-header">
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
		<h1 class="page-title">새로운 만남 만들기</h1>
	</header>

	{#if loading}
		<div class="loading-container">
			<div class="spinner" />
		</div>
	{:else if errorMessage}
		<ErrorMessage message={errorMessage} />
	{:else}
		<div class="create-mannam-content">
			{#if mannamError}
				<div class="error-message">{mannamError}</div>
			{/if}
			<form on:submit|preventDefault={handleCreateMannam} class="create-mannam-form">
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

				<div class="form-group">
					<label class="form-label">날짜 범위</label>
					<DateRangePicker
						bind:startDate={mannamStartDate}
						bind:endDate={mannamEndDate}
						maxRange={7}
					/>
				</div>

				<div class="form-group">
					<TimeRangePicker
						bind:startTime={mannamTimeRange.start}
						bind:endTime={mannamTimeRange.end}
					/>
				</div>

				<div class="form-actions">
					<Button variant="outline" on:click={() => history.back()} flex={1}>취소</Button>
					<Button 
						variant="primary" 
						type="submit" 
						flex={2} 
						disabled={!mannamTitle.trim()}
					>
						만남 생성하기
					</Button>
				</div>
			</form>
		</div>
	{/if}
</div>

<style>
	.create-mannam-container {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
		padding: 1rem;
		background: white;
	}

	.create-mannam-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 0;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 2rem;
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

	.page-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0;
		color: #111827;
	}

	.loading-container {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 200px;
	}

	.spinner {
		border: 3px solid #f3f3f3;
		border-top: 3px solid #064b45;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.create-mannam-content {
		padding: 0 0.5rem;
	}

	.error-message {
		padding: 0.75rem;
		margin-bottom: 1.5rem;
		background-color: #fee2e2;
		border: 1px solid #f87171;
		border-radius: 0.5rem;
		color: #991b1b;
		font-size: 0.875rem;
	}

	.create-mannam-form {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-label {
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
</style> 