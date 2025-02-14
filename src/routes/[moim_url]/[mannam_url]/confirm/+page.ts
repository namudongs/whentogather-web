import type { PageLoad } from './$types';
import { supabase } from '$lib/supabaseClient';

export const load: PageLoad = async ({ params }) => {
  const { data: mannam } = await supabase
    .from('mannams')
    .select('title')
    .eq('mannam_url', params.mannam_url)
    .single();

  return {
    title: `${mannam?.title || '만남'} 확정하기`
  };
}; 