<script lang="ts">
	import { page } from '$app/stores';
	import { supabase } from '$lib/supabaseClient';
	import { user } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { fade } from 'svelte/transition';
	import TimeGrid from '$lib/components/mannam/TimeGrid.svelte';
	import Spinner from '$lib/components/Spinner.svelte';
	import ErrorMessage from '$lib/components/ErrorMessage.svelte';
	import Button from '$lib/components/Button.svelte';

	// State variables
	let moim: any = null;
	let mannam: any = null;
	let loading = true;
	let error = '';
	let isSubmitting = false;

	// 응답 데이터
	interface TimeSlot {
		date: string;
		slot: string;
	}
	let selectedSlots: TimeSlot[] = [];
	let comment = '';
	let myResponse: any = null;

	// 백업용 상태 (취소 시 복원)
	let originalSlots: TimeSlot[] = [];
	let originalComment = '';

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

			// 4. 내 기존 응답 로드
			const { data: responseData, error: responseError } = await supabase
				.from('mannam_responses')
				.select('*')
				.eq('mannam_id', mannam.id)
				.eq('user_id', $user?.id)
				.maybeSingle();

			if (responseError) throw new Error('응답 정보를 불러오는데 실패했습니다.');
			
			if (responseData) {
				myResponse = responseData;
				selectedSlots = Array.isArray(responseData.available_slots)
					? responseData.available_slots
					: JSON.parse(responseData.available_slots || '[]');
				comment = responseData.comment || '';
				
				// 백업
				originalSlots = [...selectedSlots];
				originalComment = comment;
			}
		} catch (err) {
			console.error('데이터 로드 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		} finally {
			loading = false;
		}
	}

	async function handleSubmit() {
		if (!$user) return;
		
		try {
			isSubmitting = true;
			
			// 선택된 시간이 없는 경우
			if (selectedSlots.length === 0) {
				if (myResponse) {
					// 기존 응답이 있다면 삭제
					const { error: deleteError } = await supabase
						.from('mannam_responses')
						.delete()
						.eq('id', myResponse.id);

					if (deleteError) throw deleteError;
				}
			} else {
				const responseData = {
					mannam_id: mannam.id,
					user_id: $user.id,
					available_slots: selectedSlots,
					comment: comment.trim()
				};

				if (myResponse) {
					// 기존 응답 수정
					const { error: updateError } = await supabase
						.from('mannam_responses')
						.update(responseData)
						.eq('id', myResponse.id);

					if (updateError) throw updateError;
				} else {
					// 새 응답 생성
					const { error: insertError } = await supabase
						.from('mannam_responses')
						.insert(responseData);

					if (insertError) throw insertError;
				}
			}

			// 만남 상세 페이지로 이동
			await goto(`/${$page.params.moim_url}/${$page.params.mannam_url}`);
		} catch (err) {
			console.error('응답 제출 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '응답을 제출하는 중에 오류가 발생했습니다.';
		} finally {
			isSubmitting = false;
		}
	}

	function handleCancel() {
		// 기존 응답이 있었다면 원래 상태로 복원
		if (myResponse) {
			selectedSlots = [...originalSlots];
			comment = originalComment;
		} else {
			selectedSlots = [];
			comment = '';
		}
		history.back();
	}

	function handleSlotsChange(event: CustomEvent<{slots: TimeSlot[]}>) {
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
	<div class="moim-container" in:fade={{duration: 200}}>
		<div class="moim-content-wrapper">
			<header class="moim-header">
				<div class="header-content">
					<button class="back-btn font-regular" on:click={handleCancel}>
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
						<span class="header-badge font-regular">응답</span>
						<h1 class="moim-title font-extrabold">{mannam.title}</h1>
					</div>
				</div>
			</header>

			<main class="moim-content">
				<form on:submit|preventDefault={handleSubmit} class="response-form">
					<!-- 시간 선택 섹션 -->
					<section class="moim-section">
						<div class="section-header">
							<h2 class="section-title font-bold">가능한 시간 선택</h2>
						</div>
						<div class="grid-container">
							<TimeGrid
								startDate={mannam.start_date}
								endDate={mannam.end_date}
								timeRange={mannam.time_range}
								timeSlotMinutes={mannam.time_slot_minutes}
								selectedSlots={selectedSlots}
								readOnly={false}
								on:change={handleSlotsChange}
							/>
						</div>
					</section>

					<!-- 코멘트 섹션 -->
					<section class="moim-section">
						<div class="section-header">
							<h2 class="section-title font-bold">코멘트 (선택)</h2>
						</div>
						<div class="form-group">
							<textarea
								bind:value={comment}
								placeholder="추가로 전달하고 싶은 내용이 있다면 작성해주세요."
								class="form-input font-regular"
								rows="4"
							></textarea>
						</div>
					</section>

					<!-- 버튼 섹션 -->
					<section class="form-actions">
						<Button
							variant="outline"
							on:click={handleCancel}
							flex={1}
							class="font-regular"
						>취소</Button>
						<Button
							variant="primary"
							type="submit"
							flex={2}
							disabled={isSubmitting}
							loading={isSubmitting}
							class="font-bold"
						>{selectedSlots.length === 0 ? '응답 삭제하기' : (myResponse ? '응답 수정하기' : '응답 제출하기')}</Button>
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

	.response-form {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.moim-section {
		margin-bottom: 1rem;
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

	.grid-container {
		margin-bottom: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
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
		padding: 1rem 0;
		border-top: 1px solid #e5e7eb;
	}
</style> 