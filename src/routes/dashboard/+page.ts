import type { PageLoad } from './$types';

export const load: PageLoad = async () => {
  return {
    title: '대시보드'
  };
}; 