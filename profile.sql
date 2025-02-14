-- 0. 관련 테이블 데이터 삭제 (의존성 순서대로)
DELETE FROM public.mannam_responses;  -- 만남 응답 삭제
DELETE FROM public.mannams;          -- 만남 삭제
DELETE FROM public.moim_participants; -- 모임 참가자 삭제
DELETE FROM public.moims;            -- 모임 삭제
DELETE FROM public.profiles;         -- 프로필 삭제
DELETE FROM auth.users;              -- 사용자 삭제

-- 1. 트리거 삭제
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. 함수 삭제
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 3. 테이블 및 관련 객체 삭제
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 4. profiles 테이블 생성
CREATE TABLE public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  name text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. profiles에 RLS 정책 설정
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone."
  ON profiles FOR SELECT
  USING ( true );

CREATE POLICY "Users can insert their own profile."
  ON profiles FOR INSERT
  WITH CHECK ( auth.uid() = id );

CREATE POLICY "Users can update own profile."
  ON profiles FOR UPDATE
  USING ( auth.uid() = id );

-- 6. 사용자가 생성될 때 자동으로 profile을 생성하는 함수
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, avatar_url)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    COALESCE(new.raw_user_meta_data->>'avatar_url', 'https://api.dicebear.com/7.x/micah/svg?seed=' || url_encode(COALESCE(new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))) || '&backgroundColor=b6e3d4')
  );
  RETURN new;
END;
$$;

-- 7. auth.users에 트리거 생성
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();