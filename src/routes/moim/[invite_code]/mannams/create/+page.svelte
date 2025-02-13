<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import Button from '$lib/components/Button.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';

	let moim: any = null;
	let loading = true;
	let errorMessage = '';

	// 만남 생성 폼 데이터
	let mannamTitle = '';
	let mannamDescription = '';
	let mannamStartDate = '';
	let mannamEndDate = '';
	let mannamTimeRange = { start: '09:00', end: '21:00' };
	let mannamTimeSlotMinutes = 30;
	let mannamError = '';

	// 도움말(툴팁) 상태
	let showStartDateHelp = false;
	let startDateHelpPosition = { x: 0, y: 0 };
	let showEndDateHelp = false;
	let endDateHelpPosition = { x: 0, y: 0 };
	let showTimeRangeHelp = false;
	let timeRangeHelpPosition = { x: 0, y: 0 };
	let showSlotHelp = false;
	let slotHelpPosition = { x: 0, y: 0 };

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
							<button
								type="button"
								class="help-icon"
								aria-label="종료 날짜에 대한 도움말"
								on:mouseenter={(e) => {
									const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
									endDateHelpPosition = { x: rect.left, y: rect.top };
									showEndDateHelp = true;
								}}
								on:mouseleave={() => (showEndDateHelp = false)}
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
							{#if showEndDateHelp}
								<div
									class="help-tooltip"
									style="left: {endDateHelpPosition.x}px; top: {endDateHelpPosition.y + 20}px"
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
						class="info-icon"
					>
						<circle cx="12" cy="12" r="10"></circle>
						<line x1="12" y1="16" x2="12" y2="12"></line>
						<line x1="12" y1="8" x2="12.01" y2="8"></line>
					</svg>
					<span>날짜 범위는 최대 7일까지 선택할 수 있습니다.</span>
				</div>

				<!-- 시간 범위 -->
				<div class="form-group">
					<div class="label-with-help">
						<label class="form-label">시간 범위</label>
						<button
							type="button"
							class="help-icon"
							aria-label="시간 범위에 대한 도움말"
							on:mouseenter={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								timeRangeHelpPosition = { x: rect.left, y: rect.top };
								showTimeRangeHelp = true;
							}}
							on:mouseleave={() => (showTimeRangeHelp = false)}
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
						{#if showTimeRangeHelp}
							<div
								class="help-tooltip"
								style="left: {timeRangeHelpPosition.x}px; top: {timeRangeHelpPosition.y + 20}px"
							>
								하루 중 만남이 가능한 시간대를 설정합니다. 예를 들어, 오전 9시부터 오후 6시까지로 설정하면
								해당 시간대 내에서만 선택이 가능합니다.
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
						<button
							type="button"
							class="help-icon"
							aria-label="시간 슬롯에 대한 도움말"
							on:mouseenter={(e) => {
								const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
								slotHelpPosition = { x: rect.left, y: rect.top };
								showSlotHelp = true;
							}}
							on:mouseleave={() => (showSlotHelp = false)}
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
						{#if showSlotHelp}
							<div
								class="help-tooltip"
								style="left: {slotHelpPosition.x}px; top: {slotHelpPosition.y + 20}px"
							>
								시간을 선택할 수 있는 최소 단위입니다. 예를 들어, 30분으로 설정하면 30분 단위로 시간을 선택할
								수 있습니다.
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
					<Button variant="outline" on:click={() => history.back()} flex={1}>취소</Button>
					<Button variant="primary" type="submit" flex={2}>만남 생성하기</Button>
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
	}

	.create-mannam-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 0;
		border-bottom: 1px solid #f0f0f0;
		margin-bottom: 1.5rem;
	}

	.back-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		color: #064b45;
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
		0% {
			transform: rotate(0deg);
		}
		100% {
			transform: rotate(360deg);
		}
	}

	.create-mannam-content {
		padding: 0 0.5rem;
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

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-row {
		display: flex;
		gap: 1rem;
	}

	.flex-1 {
		flex: 1;
	}

	.form-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.form-sublabel {
		display: block;
		font-size: 0.813rem;
		color: #6b7280;
		margin-bottom: 0.5rem;
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

	.label-with-help {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.help-icon {
		cursor: pointer;
		color: #6b7280;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: color 0.2s;
		background: none;
		border: none;
		padding: 0;
	}

	.help-icon:hover {
		color: #374151;
	}

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

	.date-range-info {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		color: #4b5563;
		font-size: 0.775rem;
		margin: -0.75rem 0 1.5rem 0;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
		margin-top: 2rem;
	}
</style> 