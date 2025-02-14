<script lang="ts">
  export let name: string = '이름없음';
  export let role: string = 'participant';
  export let size: 'sm' | 'md' = 'md';
  export let avatarUrl: string | undefined = undefined;
  export let email: string | undefined = undefined;

  // DiceBear API URL인지 확인하는 함수
  function isDiceBearUrl(url: string | undefined): boolean {
    return url?.includes('api.dicebear.com') ?? false;
  }

  // DiceBear API URL 생성 함수
  function createDiceBearUrl(seed: string): string {
    return `https://api.dicebear.com/7.x/micah/svg?seed=${encodeURIComponent(seed)}&backgroundColor=b6e3d4`;
  }

  // 제공된 avatarUrl을 우선 사용하고, 없는 경우 이메일을 시드로 사용
  $: finalAvatarUrl = avatarUrl || createDiceBearUrl(email?.split('@')[0] || 'default');
</script>

<div class="participant-badge" class:sm={size === 'sm'}>
  <img 
    src={finalAvatarUrl} 
    alt={`${name}의 아바타`} 
    class="avatar"
  />
  <span class="name font-regular">{name}</span>
  {#if role === 'owner'}
    <span class="owner-badge font-bold">방장</span>
  {/if}
</div>

<style>
  .participant-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.375rem;
    padding-right: 0.75rem;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 2rem;
    transition: all 0.2s ease;
  }

  .participant-badge:hover {
    border-color: #064b45;
    box-shadow: 0 0 0 1px rgba(6, 75, 69, 0.1);
  }

  .participant-badge.sm {
    padding: 0.25rem;
    padding-right: 0.5rem;
    gap: 0.375rem;
  }

  .avatar {
    width: 1.75rem;
    height: 1.75rem;
    border-radius: 50%;
    background: #f3f4f6;
  }

  .sm .avatar {
    width: 1.5rem;
    height: 1.5rem;
  }

  .name {
    font-size: 0.875rem;
    color: #374151;
  }

  .sm .name {
    font-size: 0.75rem;
  }

  .owner-badge {
    font-size: 0.688rem;
    padding: 0.125rem 0.375rem;
    background: #064b45;
    color: white;
    border-radius: 1rem;
  }

  .sm .owner-badge {
    font-size: 0.625rem;
    padding: 0.125rem 0.25rem;
  }
</style> 