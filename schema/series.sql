-- =========================================================
-- [6] Series: 삭제 동기화를 위해 deleted_at 추가
-- =========================================================
CREATE TABLE series (
  id UUID PRIMARY KEY,
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  access_scope INT NOT NULL DEFAULT 0,
  required_grade INT DEFAULT 3,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- 추가됨
);

-- [최적화] 동기화 시 "이 Drawer의 Series 중 변경된 것"을 빨리 찾기 위함
CREATE INDEX idx_series_sync ON series(drawer_id, updated_at);


-- =========================================================
-- [7] Series Comments: 대댓글 구조 & 삭제 지원
-- =========================================================
CREATE TABLE series_comments (
  id UUID PRIMARY KEY,
  series_id UUID NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  parent_id UUID REFERENCES series_comments (id) ON DELETE SET NULL, -- 대댓글용 (추가됨)
  comment_type INT NOT NULL,
  payload JSONB NOT NULL,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 내용 수정 지원
  deleted_at TIMESTAMPTZ -- 메시지 삭제 지원 (추가됨)
);

-- [최적화] 채팅 로딩 및 동기화 최적화
CREATE INDEX idx_series_cmt_sync ON series_comments (series_id, created_at DESC);

CREATE TABLE comment_reactions (
  id UUID PRIMARY KEY,
  comment_id UUID NOT NULL REFERENCES series_comments (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  emoji TEXT NOT NULL
);

-- =========================================================
-- [8] Series Whitelists: 동기화 지원 (Upsert용)
-- =========================================================
CREATE TABLE series_whitelists ( -- 복수형으로 변경
  series_id UUID NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 추가됨 (동기화 기준)
  deleted_at TIMESTAMPTZ, -- 추가됨 (권한 해제 동기화)
  PRIMARY KEY (series_id, user_id)
);
-- 유저별 권한 목록 조회 최적화
CREATE INDEX idx_sw_user_lookup ON series_whitelists(user_id);
-- 변경사항 동기화용 (Series 기준)
CREATE INDEX idx_sw_sync ON series_whitelists(series_id, updated_at);