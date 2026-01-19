CREATE TABLE series_messages (
  id UUID PRIMARY KEY,
  series_id UUID NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  parent_id UUID REFERENCES series_messages (id) ON DELETE SET NULL,
  content TEXT,
  mention_everyone BOOLEAN NOT NULL DEFAULT FALSE,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 채팅 로딩: 최신순 또는 과거순 페이징 (UUID v7이라 id 정렬도 가능하지만 created_at 명시 추천)
CREATE INDEX idx_messages_pagination ON series_messages (series_id, created_at DESC);
-- 변경사항 동기화: "마지막 동기화 시점 이후에 변경/삭제된 메시지 내놔"
CREATE INDEX idx_messages_sync ON series_messages (series_id, updated_at);

CREATE TABLE message_attachments (
  id UUID PRIMARY KEY,
  message_id UUID NOT NULL REFERENCES series_messages (id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  thumbnail_url TEXT,
  filename TEXT,
  file_size BIGINT,
  content_type TEXT, -- 'image/jpeg', 'video/mp4'
  duration_secs REAL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_attachments_message ON message_attachments(message_id) WHERE deleted_at IS NULL;

-- ======================================================================================
-- [5] Message Embeds (링크 미리보기 - 경량화 버전)
-- - 메시지와 1:N 관계
-- - 카카오톡/라인 스타일: URL + 제목 + 설명 + 썸네일 + 사이트명
-- ======================================================================================
CREATE TABLE message_embeds (
  id UUID PRIMARY KEY, -- Client Generated UUID v7
  message_id UUID NOT NULL REFERENCES series_messages (id) ON DELETE CASCADE,
  
  url TEXT NOT NULL,       -- 원본 링크
  title TEXT,              -- og:title
  description TEXT,        -- og:description
  image_url TEXT,          -- og:image (썸네일)
  site_name TEXT,          -- og:site_name (예: YouTube, Naver Blog - 출처 표기용)
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ -- ★ 개별 임베드(미리보기 박스) 삭제용
);

CREATE INDEX idx_embeds_message ON message_embeds(message_id) WHERE deleted_at IS NULL;

-- ======================================================================================
-- [6] Message Reactions (이모지 반응)
-- - 단순 토글 기능. 수정(Update) 개념보다는 생성(Insert)/삭제(Delete)가 주된 액션
-- - 하드 딜리트(DELETE FROM)를 할지, 소프트 딜리트(UPDATE deleted_at)를 할지 결정 필요
-- - *성능상* 리액션 취소는 하드 딜리트가 깔끔할 수 있으나, 동기화를 위해 소프트 딜리트 채택
-- ======================================================================================
CREATE TABLE message_reactions (
  id UUID PRIMARY KEY,
  message_id UUID NOT NULL REFERENCES series_messages (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  
  emoji TEXT NOT NULL, -- 유니코드 이모지 or 커스텀 ID
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ, -- 반응 취소 동기화용
  
  CONSTRAINT unique_reaction_active UNIQUE (message_id, user_id, emoji)
);

-- 부분 인덱스: 삭제되지 않은 리액션만 빠르게 집계
CREATE INDEX idx_reactions_active ON message_reactions(message_id, emoji) WHERE deleted_at IS NULL;
-- 동기화용: 특정 메시지의 리액션 변경사항 조회
CREATE INDEX idx_reactions_sync ON message_reactions(message_id, created_at);


-- ======================================================================================
-- [7] Message Mentions (멘션)
-- - 메시지 내에서 언급된 유저 목록 저장
-- - "나를 언급한 메시지" 필터링 및 푸시 알림 타겟팅용
-- ======================================================================================
CREATE TABLE message_mentions (
  id UUID PRIMARY KEY, 
  message_id UUID NOT NULL REFERENCES series_messages (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE, -- 언급된 사용자
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ, -- 멘션이 포함된 메시지 수정으로 멘션이 사라질 경우 대비
  
  CONSTRAINT unique_message_mention UNIQUE (message_id, user_id)
);

-- "나를 언급한 메시지"만 빠르게 조회 (알림 탭 등)
CREATE INDEX idx_mentions_user ON message_mentions(user_id) WHERE deleted_at IS NULL;
-- 특정 메시지에 언급된 사람 목록 조회 (UI 표시용)
CREATE INDEX idx_mentions_message ON message_mentions(message_id) WHERE deleted_at IS NULL;
