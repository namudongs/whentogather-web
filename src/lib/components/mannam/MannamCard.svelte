<!-- MannamCard.svelte -->
<script lang="ts">
  import { format } from 'date-fns';
  import ko from 'date-fns/locale/ko';

  export let mannam: {
    id: string;
    title: string;
    description: string;
    start_date: string;
    end_date: string;
    duration: number;
    status: 'pending' | 'confirmed' | 'cancelled';
  };

  $: formattedStartDate = mannam.start_date ? format(new Date(mannam.start_date), 'PPP', { locale: ko }) : '';
  $: formattedEndDate = mannam.end_date ? format(new Date(mannam.end_date), 'PPP', { locale: ko }) : '';

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'confirmed':
        return 'bg-green-100 text-green-800';
      case 'cancelled':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'confirmed':
        return '확정됨';
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  };
</script>

<div class="bg-white rounded-lg shadow-md p-6 mb-4">
  <div class="flex justify-between items-start mb-4">
    <div>
      <h3 class="text-xl font-semibold text-gray-900">{mannam.title}</h3>
      {#if mannam.description}
        <p class="text-gray-600 mt-1">{mannam.description}</p>
      {/if}
    </div>
    <span class={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(mannam.status)}`}>
      {getStatusText(mannam.status)}
    </span>
  </div>

  <div class="space-y-2">
    <div class="flex items-center text-gray-600">
      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
      <span>
        {formattedStartDate} ~ {formattedEndDate}
      </span>
    </div>
    <div class="flex items-center text-gray-600">
      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span>소요 시간: {mannam.duration}시간</span>
    </div>
  </div>

  <div class="mt-4 flex space-x-2">
    <button class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition-colors">
      응답하기
    </button>
    <button class="bg-gray-100 text-gray-700 px-4 py-2 rounded hover:bg-gray-200 transition-colors">
      응답 현황
    </button>
  </div>
</div>
