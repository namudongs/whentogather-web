/*****************************************************************************
 * 1) 기존 객체 삭제
 *****************************************************************************/
/* (1) 관련 트리거 삭제 */
DROP TRIGGER IF EXISTS handle_moims_updated_at ON public.moims;
DROP TRIGGER IF EXISTS handle_mannams_updated_at ON public.mannams;
DROP TRIGGER IF EXISTS handle_mannam_responses_updated_at ON public.mannam_responses;

/* (2) 테이블 삭제 (CASCADE 옵션으로 관련 정책 등도 함께 삭제) */
DROP TABLE IF EXISTS public.mannam_responses CASCADE;
DROP TABLE IF EXISTS public.mannams CASCADE;
DROP TABLE IF EXISTS public.moim_participants CASCADE;
DROP TABLE IF EXISTS public.moims CASCADE;

/* (3) 함수 삭제 (테이블/정책이 삭제된 후이므로 종속성 문제 없음) */
DROP FUNCTION IF EXISTS public.handle_updated_at;
DROP FUNCTION IF EXISTS public.is_moim_member;
DROP FUNCTION IF EXISTS public.is_mannam_member;

/*****************************************************************************
 * 2) 새 테이블 생성
 *****************************************************************************/
/* 모임(Moim) 테이블 */
CREATE TABLE public.moims (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  creator_id uuid REFERENCES auth.users NOT NULL,
  invite_code TEXT UNIQUE,  -- 초대 코드 (URL의 일부로 사용)
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

/* 모임 참가자 테이블 */
CREATE TABLE public.moim_participants (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  moim_id uuid REFERENCES public.moims ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  role TEXT DEFAULT 'participant' CHECK (role IN ('creator','participant')),
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE (moim_id, user_id)
);

/* 만남(Mannams) 테이블 */
CREATE TABLE public.mannams (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  moim_id uuid REFERENCES public.moims ON DELETE CASCADE NOT NULL,
  creator_id uuid REFERENCES auth.users NOT NULL,
  sequence_number INTEGER NOT NULL,  -- 모임 내 순차 번호
  title TEXT NOT NULL,
  description TEXT,
  start_date DATE NOT NULL,  -- 만남 후보 기간 시작일
  end_date DATE NOT NULL,    -- 만남 후보 기간 종료일
  time_range JSONB NOT NULL DEFAULT '{"start": "09:00", "end": "21:00"}'::jsonb,  -- 시간 범위 (기본값: 오전 9시 ~ 오후 9시)
  time_slot_minutes INTEGER NOT NULL DEFAULT 30,  -- 시간 슬롯 단위 (기본값: 30분)
  confirmed_slots JSONB DEFAULT '[]'::jsonb,  -- 확정된 시간 슬롯들 (예: [{"date": "2024-03-01", "slot": "18:00"}])
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','cancelled')),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT valid_date_range CHECK (start_date <= end_date),
  CONSTRAINT valid_confirmation CHECK (
    (status = 'confirmed' AND jsonb_array_length(confirmed_slots) > 0) OR
    (status != 'confirmed' AND jsonb_array_length(confirmed_slots) = 0)
  ),
  UNIQUE(moim_id, sequence_number)  -- 모임 내에서 순차 번호는 유일해야 함
);

-- 만남 순차 번호 자동 생성 함수
CREATE OR REPLACE FUNCTION public.generate_mannam_sequence_number()
RETURNS TRIGGER AS $$
BEGIN
  -- 해당 모임의 가장 큰 sequence_number를 찾아서 +1
  SELECT COALESCE(MAX(sequence_number), 0) + 1
  INTO NEW.sequence_number
  FROM public.mannams
  WHERE moim_id = NEW.moim_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 만남 생성 시 순차 번호 자동 생성 트리거
DROP TRIGGER IF EXISTS set_mannam_sequence_number ON public.mannams;
CREATE TRIGGER set_mannam_sequence_number
  BEFORE INSERT ON public.mannams
  FOR EACH ROW
  EXECUTE FUNCTION public.generate_mannam_sequence_number();

/* 만남 응답(Mannam Responses) 테이블 */
CREATE TABLE public.mannam_responses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  mannam_id uuid REFERENCES public.mannams ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  available_slots JSONB NOT NULL DEFAULT '[]'::jsonb,  -- 가능한 시간 슬롯 (예: [{"date": "2024-03-01", "slot": 18}] - slot은 해당 날짜의 n번째 시간 슬롯)
  comment TEXT,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE (mannam_id, user_id)
);


/*****************************************************************************
 * 3) ROW LEVEL SECURITY (RLS) 활성화
 *****************************************************************************/
ALTER TABLE public.moims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moim_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mannams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mannam_responses ENABLE ROW LEVEL SECURITY;


/*****************************************************************************
 * 4) 보안 관련 함수 생성 (SECURITY DEFINER)
 *****************************************************************************/
/* 모임에 사용자가 속해있는지 확인 */
CREATE OR REPLACE FUNCTION public.is_moim_member(_moim_id uuid, _user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.moim_participants
    WHERE moim_id = _moim_id
      AND user_id = _user_id
  );
$$;

/* 만남의 모임에 사용자가 속해있는지 확인 */
CREATE OR REPLACE FUNCTION public.is_mannam_member(_mannam_id uuid, _user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.moim_participants mp
    JOIN public.mannams m ON mp.moim_id = m.moim_id
    WHERE m.id = _mannam_id
      AND mp.user_id = _user_id
  );
$$;


/*****************************************************************************
 * 5) RLS 정책 생성
 *****************************************************************************/

/* ---------- (A) moims 테이블 ---------- */
/* (A-1) 모임 조회: 모임 생성자 또는 해당 모임의 참가자이면 조회 가능 */
DROP POLICY IF EXISTS "moims_select_policy" ON public.moims;
CREATE POLICY "moims_select_policy"
  ON public.moims
  FOR SELECT
  USING (
    auth.uid()::uuid = creator_id OR public.is_moim_member(id, auth.uid()::uuid)
  );

/* (A-2) 초대코드로 모임 조회: 로그인한 사용자라면 조회 가능 */
DROP POLICY IF EXISTS "moims_select_by_invite_policy" ON public.moims;
CREATE POLICY "moims_select_by_invite_policy"
  ON public.moims
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

/* (A-3) 모임 생성: 행의 creator_id가 현재 사용자여야 함 */
DROP POLICY IF EXISTS "moims_insert_policy" ON public.moims;
CREATE POLICY "moims_insert_policy"
  ON public.moims
  FOR INSERT
  WITH CHECK (auth.uid()::uuid = creator_id);

/* (A-4) 모임 수정/삭제: 오직 생성자만 가능 */
DROP POLICY IF EXISTS "moims_update_policy" ON public.moims;
CREATE POLICY "moims_update_policy"
  ON public.moims
  FOR UPDATE
  USING (auth.uid()::uuid = creator_id);

DROP POLICY IF EXISTS "moims_delete_policy" ON public.moims;
CREATE POLICY "moims_delete_policy"
  ON public.moims
  FOR DELETE
  USING (auth.uid()::uuid = creator_id);


/* ---------- (B) moim_participants 테이블 ---------- */
/* (B-1) 참가자 조회: 모임 참가자이거나 본인인 경우 조회 가능 */
DROP POLICY IF EXISTS "moim_participants_select_policy" ON public.moim_participants;
CREATE POLICY "moim_participants_select_policy"
  ON public.moim_participants
  FOR SELECT
  USING (
    public.is_moim_member(moim_id, auth.uid()::uuid) OR user_id = auth.uid()::uuid
  );

/* (B-2) 참가자 추가: 사용자는 자기 자신만 추가할 수 있음 */
DROP POLICY IF EXISTS "moim_participants_insert_policy" ON public.moim_participants;
CREATE POLICY "moim_participants_insert_policy"
  ON public.moim_participants
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()::uuid AND (
      (role = 'participant') OR
      (role = 'creator' AND EXISTS (
        SELECT 1 FROM public.moims
        WHERE id = moim_participants.moim_id
        AND creator_id = auth.uid()::uuid
      ))
    )
  );

/* (B-3) 참가자 수정/삭제: 오직 모임 생성자만 가능 */
DROP POLICY IF EXISTS "moim_participants_update_policy" ON public.moim_participants;
CREATE POLICY "moim_participants_update_policy"
  ON public.moim_participants
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.moims
      WHERE id = moim_participants.moim_id
      AND creator_id = auth.uid()::uuid
    )
  );

DROP POLICY IF EXISTS "moim_participants_delete_policy" ON public.moim_participants;
CREATE POLICY "moim_participants_delete_policy"
  ON public.moim_participants
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.moims
      WHERE id = moim_participants.moim_id
      AND creator_id = auth.uid()::uuid
    )
  );


/* ---------- (C) mannams 테이블 ---------- */
/* (C-1) 만남 조회: 만남이 속한 모임의 참가자이면 조회 가능 */
DROP POLICY IF EXISTS "mannams_select_policy" ON public.mannams;
CREATE POLICY "mannams_select_policy"
  ON public.mannams
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.moim_participants mp
      WHERE mp.moim_id = mannams.moim_id
      AND mp.user_id = auth.uid()::uuid
    )
  );

/* (C-2) 만남 생성: 모임의 참여자면 누구나 가능 */
DROP POLICY IF EXISTS "mannams_insert_policy" ON public.mannams;
CREATE POLICY "mannams_insert_policy"
  ON public.mannams
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.moim_participants mp
      WHERE mp.moim_id = mannams.moim_id
      AND mp.user_id = auth.uid()::uuid
    )
  );

/* (C-3) 만남 수정/삭제: 모임의 creator인 경우에만 가능 */
DROP POLICY IF EXISTS "mannams_update_policy" ON public.mannams;
CREATE POLICY "mannams_update_policy"
  ON public.mannams
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.moim_participants mp
      WHERE mp.moim_id = mannams.moim_id
      AND mp.user_id = auth.uid()::uuid
      AND mp.role = 'creator'
    )
  );

DROP POLICY IF EXISTS "mannams_delete_policy" ON public.mannams;
CREATE POLICY "mannams_delete_policy"
  ON public.mannams
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.moim_participants mp
      WHERE mp.moim_id = mannams.moim_id
      AND mp.user_id = auth.uid()::uuid
      AND mp.role = 'creator'
    )
  );


/* ---------- (D) mannam_responses 테이블 ---------- */
/* (D-1) 응답 조회: 만남이 속한 모임의 참가자이면 조회 가능 */
DROP POLICY IF EXISTS "mannam_responses_select_policy" ON public.mannam_responses;
CREATE POLICY "mannam_responses_select_policy"
  ON public.mannam_responses
  FOR SELECT
  USING (
    public.is_mannam_member(mannam_id, auth.uid()::uuid)
  );

/* (D-2) 응답 생성: 본인이면서 해당 만남의 모임 참가자인 경우만 가능 */
DROP POLICY IF EXISTS "mannam_responses_insert_policy" ON public.mannam_responses;
CREATE POLICY "mannam_responses_insert_policy"
  ON public.mannam_responses
  FOR INSERT
  WITH CHECK (
    auth.uid()::uuid = user_id
    AND EXISTS (
      SELECT 1
      FROM public.moim_participants mp
      JOIN public.mannams m ON m.moim_id = mp.moim_id
      WHERE m.id = mannam_responses.mannam_id
      AND mp.user_id = auth.uid()::uuid
    )
  );

/* (D-3) 응답 수정/삭제: 오직 본인만 가능 */
DROP POLICY IF EXISTS "mannam_responses_update_policy" ON public.mannam_responses;
CREATE POLICY "mannam_responses_update_policy"
  ON public.mannam_responses
  FOR UPDATE
  USING (auth.uid()::uuid = user_id);

DROP POLICY IF EXISTS "mannam_responses_delete_policy" ON public.mannam_responses;
CREATE POLICY "mannam_responses_delete_policy"
  ON public.mannam_responses
  FOR DELETE
  USING (auth.uid()::uuid = user_id);


/*****************************************************************************
 * 6) 업데이트 시간 자동 변경 트리거 생성
 *****************************************************************************/
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER handle_moims_updated_at
  BEFORE UPDATE ON public.moims
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_mannams_updated_at
  BEFORE UPDATE ON public.mannams
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_mannam_responses_updated_at
  BEFORE UPDATE ON public.mannam_responses
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
