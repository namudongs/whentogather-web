<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { fade } from 'svelte/transition';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import Button from '$lib/components/Button.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import DateRangePicker from '$lib/components/DateRangePicker.svelte';
	import TimeRangePicker from '$lib/components/TimeRangePicker.svelte';
	import Spinner from '$lib/components/Spinner.svelte';

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
				await goto(`/${$page.params.invite_code}/invite`);
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
				.select('*, moims!inner(invite_code)')
				.single();

			if (err) throw err;
			
			// sequence_number를 가져오기 위한 추가 쿼리
			const { data: createdMannam, error: seqErr } = await supabase
				.from('mannams')
				.select('sequence_number')
				.eq('id', mannam.id)
				.single();
			
			if (seqErr) throw seqErr;
			
			// 새로운 URL 구조로 리다이렉트
			await goto(`/${$page.params.invite_code}/${createdMannam.sequence_number}`, { replaceState: true });
		} catch (err) {
			mannamError = err instanceof Error ? err.message : '만남을 생성하는 중에 오류가 발생했습니다.';
		}
	}

	// 페이지 로드 시 모임 데이터 불러오기
	loadMoimData();
</script>

<div class="moim-container" in:fade={{duration: 200}}>
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
					<span class="header-badge font-regular">생성</span>
					<h1 class="moim-title font-extrabold">새로운 만남 만들기</h1>
				</div>
			</div>
		</header>

		<main class="moim-content">
			{#if loading}
				<div class="global-spinner">
					<Spinner size="large" />
				</div>
			{:else if errorMessage}
				<div class="error-container">
					<ErrorMessage message={errorMessage} />
					<Button variant="outline" on:click={() => history.back()} class="font-regular">돌아가기</Button>
				</div>
			{:else}
				<form on:submit|preventDefault={handleCreateMannam} class="create-form">
					<div class="form-group">
						<label for="mannamTitle" class="form-label font-bold">만남 제목</label>
						<input
							type="text"
							id="mannamTitle"
							bind:value={mannamTitle}
							required
							class="form-input font-regular"
							placeholder="3월 정기 모임"
						/>
					</div>

					<div class="form-group">
						<label for="mannamDescription" class="form-label font-bold">설명 (선택)</label>
						<textarea
							id="mannamDescription"
							bind:value={mannamDescription}
							rows="4"
							class="form-input font-regular"
							placeholder="이번 모임의 주제나 준비물 등을 적어주세요"
						></textarea>
					</div>

					<div class="form-group">
						<label class="form-label font-bold">날짜 범위</label>
						<DateRangePicker
							bind:startDate={mannamStartDate}
							bind:endDate={mannamEndDate}
							maxRange={7}
						/>
					</div>

					<div class="form-group">
						<label class="form-label font-bold">시간 범위</label>
						<TimeRangePicker
							bind:startTime={mannamTimeRange.start}
							bind:endTime={mannamTimeRange.end}
						/>
					</div>

					<div class="form-actions">
						<Button variant="outline" on:click={() => history.back()} flex={1} class="font-regular">취소</Button>
						<Button 
							variant="primary" 
							type="submit" 
							flex={2} 
							disabled={!mannamTitle.trim()}
							class="font-bold"
						>만남 생성하기</Button>
					</div>
				</form>
			{/if}
		</main>
	</div>
</div>

<style>
	:global(body) {
		margin: 0;
		background: white;
	}

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
		color: #111827;
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

	.form-label {
		font-size: 0.875rem;
		color: #111827;
	}
</style> 