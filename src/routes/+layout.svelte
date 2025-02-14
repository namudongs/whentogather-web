<script>
    import '../app.css';
    import { page } from '$app/stores';
</script>

<svelte:head>
  <title>{$page.data.title ? `${$page.data.title} - 언제모여` : '언제모여'}</title>
  <meta name="description" content="모임 시간을 쉽게 정하세요" />
</svelte:head>

<slot />