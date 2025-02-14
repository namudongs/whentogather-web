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
	import BottomSheet from '$lib/components/BottomSheet.svelte';

	// State variables
	let moim: any = null;
	let mannam: any = null;
	let responses: any[] = [];
	let loading = true;
	let error = '';
	let heatmapData: { [key: string]: number } = {};
	let selectedSlots: { date: string; slot: string }[] = [];
	let isConfirmSheetOpen = false;

	interface Profile {
		id: string;
		name: string;
	}

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
					.select('id, name')
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
				user: profilesData.find(p => p.id === response.user_id) || { id: response.user_id, name: '이름없음' }
			}));

			// 5. 히트맵 데이터 생성
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

	async function handleConfirm() {
		try {
			if (selectedSlots.length === 0) {
				error = '확정할 시간대를 선택해주세요.';
				return;
			}

			const updateData = {
				confirmed_slots: selectedSlots,
				status: 'confirmed'
			};

			const { data, error: updateError } = await supabase
				.from('mannams')
				.update(updateData)
				.eq('mannam_url', $page.params.mannam_url)
				.eq('moim_id', moim.id)
				.select();

			if (updateError) {
				console.error('업데이트 에러:', updateError);
				throw new Error('시간 확정에 실패했습니다: ' + updateError.message);
			}

			if (!data || data.length === 0) {
				throw new Error('업데이트할 만남을 찾을 수 없습니다.');
			}

			await goto(`/${$page.params.moim_url}/${$page.params.mannam_url}`);
		} catch (err) {
			console.error('시간 확정 중 에러 발생:', err);
			error = err instanceof Error ? err.message : '알 수 없는 오류가 발생했습니다.';
		}
	}

	function handleSlotsChange(event: CustomEvent<{ slots: { date: string; slot: string }[] }>) {
		selectedSlots = event.detail.slots;
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
						<span class="header-badge font-regular">확정</span>
						<h1 class="moim-title font-extrabold">{mannam.title}</h1>
					</div>
				</div>
			</header>

			<main class="moim-content">
				<section class="moim-section">
					<div class="section-header">
						<div class="title-with-badge">
							<h2 class="section-title font-bold">시간 확정하기</h2>
						</div>
					</div>

					<div class="grid-container">
						<TimeGrid
							startDate={mannam.start_date}
							endDate={mannam.end_date}
							timeRange={mannam.time_range}
							timeSlotMinutes={mannam.time_slot_minutes}
							{heatmapData}
							readOnly={false}
							on:change={handleSlotsChange}
							{selectedSlots}
							confirmedSlots={mannam.confirmed_date && mannam.confirmed_time ? [{ date: mannam.confirmed_date, slot: mannam.confirmed_time }] : []}
							responses={responses.map(response => ({
								user: response.user,
								available_slots: Array.isArray(response.available_slots)
									? response.available_slots
									: JSON.parse(response.available_slots || '[]')
							}))}
						/>
					</div>

					<div class="confirm-button-section">
						<button
							type="button"
							class="confirm-btn font-bold"
							on:click={() => isConfirmSheetOpen = true}
							disabled={selectedSlots.length === 0}
						>
							<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M20 6L9 17l-5-5"></path>
							</svg>
							시간 확정하기
						</button>
					</div>
				</section>
			</main>
		</div>
	</div>

	<!-- 확정 확인 시트 -->
	<BottomSheet
		show={isConfirmSheetOpen}
		onClose={() => isConfirmSheetOpen = false}
		title="시간을 확정하시겠습니까?"
	>
		<div class="sheet-content">
			<div class="sheet-description">
				선택한 시간대로 만남 시간이 확정됩니다.
			</div>
			<div class="sheet-buttons">
				<button class="sheet-button cancel" on:click={() => isConfirmSheetOpen = false}>
					취소
				</button>
				<button class="sheet-button confirm" on:click={handleConfirm}>
					확정하기
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

	.confirm-button-section {
		margin-bottom: 2rem;
	}

	.confirm-btn {
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

	.confirm-btn:hover {
		background-color: #053c37;
		border-color: #053c37;
	}

	.confirm-btn:disabled {
		background-color: #9ca3af;
		border-color: #9ca3af;
		cursor: not-allowed;
	}

	.sheet-content {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.sheet-description {
		padding: 1rem;
		margin-bottom: 1rem;
		background-color: #f8fafc;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.5;
	}

	.sheet-buttons {
		display: flex;
		gap: 0.5rem;
	}

	.sheet-buttons .sheet-button {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
		font-size: 1rem;
		font-weight: 500;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.sheet-buttons .sheet-button.confirm {
		background-color: #064b45;
		color: white;
		border: 1px solid #064b45;
	}

	.sheet-buttons .sheet-button.confirm:hover {
		background-color: #053c37;
		border-color: #053c37;
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
</style> 