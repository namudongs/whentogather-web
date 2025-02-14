import type { PageLoad } from './$types';
import { supabase } from '$lib/supabaseClient';

export const load: PageLoad = async ({ params }) => {
  const { data: moim } = await supabase
    .from('moims')
    .select('title')
    .eq('moim_url', params.moim_url)
    .single();

  return {
    title: `${moim?.title || '모임'} 초대`
  };
}; 