-- =========================================================
-- Drawer / Series / Event / Task 전체 스키마
-- 목적: 협업 캘린더 + 태스크 + 채팅을 하나의 컨텍스트로 묶는 구조
-- =========================================================


------------------------------------------------------------
-- 1. Drawers : 최상위 그룹 단위 (권한 / 멤버십 / 공개 범위)
------------------------------------------------------------
CREATE TABLE drawers (
  id UUID PRIMARY KEY, -- Client에서 생성하는 v7 UUID
  name TEXT NOT NULL, -- Drawer 이름 (팀/그룹/프로젝트 등)
  description TEXT,
  image_url TEXT,
  thumbnail_url TEXT, -- 비정규화 컬럼: 대규모 서비스에서 JOIN/COUNT 최소화 목적
  member_count INT NOT NULL DEFAULT 1, -- 현재 활성 멤버 수 캐싱
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 정렬용 (최근 활동 Drawer 우선 노출)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- Soft delete (복구/동기화 대비)
);

------------------------------------------------------------
-- 2. Drawer Settings : Drawer의 공개/검색/입장 정책
------------------------------------------------------------
CREATE TABLE drawer_settings (
  drawer_id UUID PRIMARY KEY REFERENCES drawers (id) ON DELETE CASCADE,
  is_public BOOLEAN NOT NULL DEFAULT FALSE, -- 외부 공개 여부
  is_searchable BOOLEAN NOT NULL DEFAULT FALSE, -- 검색 노출 여부
  require_approval BOOLEAN NOT NULL DEFAULT FALSE, -- 가입 승인 필요 여부
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

------------------------------------------------------------
-- 3. Drawer Users : Drawer 멤버십 + 권한
-- role
-- 0: 소유자, 1: 관리자, 2: 편집자, 3: 참가자
------------------------------------------------------------

-- notification_level
-- 0: (기본값) 노드의 모든 활동에 대해 실시간 푸시
-- 1: 내가 참석/할당된 이벤트, 태스크 등 직접 관련된 활동만 푸시
-- 2: 채팅 등에서 나를 @언급했을 때만 푸시
-- 3: 실시간 푸시 알림을 받지 않음

CREATE TABLE drawer_members (
  drawer_id UUID REFERENCES drawers (id) ON DELETE CASCADE,
  user_id UUID REFERENCES users (id) ON DELETE CASCADE,
  role INT NOT NULL, -- 멤버 권한 (ENUM 또는 CHECK 권장)
  notification_level INT NOT NULL DEFAULT 0, -- user 개인 알림 세팅
  nickname_in_drawer TEXT, -- Drawer 내부 별명
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ, -- 탈퇴/추방 상태 동기화를 위한 Soft delete
  PRIMARY KEY (drawer_id, user_id)
);

-- 1. 내 서랍 목록 동기화용 (User 기준)
-- "내가 속한 정보 중 최근 변한 것"
CREATE INDEX idx_drawer_users_my_sync ON drawer_members (user_id, updated_at);

-- 2. 서랍 멤버 목록 동기화용 (Drawer 기준)
-- "이 서랍의 멤버 중 최근 변한 사람(가입/탈퇴/권한변경)"
CREATE INDEX idx_drawer_users_member_sync ON drawer_members (drawer_id, updated_at);

------------------------------------------------------------
-- 5. Invitations : Drawer 초대 링크
------------------------------------------------------------
CREATE TABLE drawer_invitations (
  id UUID PRIMARY KEY,
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token TEXT UNIQUE NOT NULL, -- 초대 토큰
  max_uses INT DEFAULT 1, -- NULL이면 무제한
  uses_count INT DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE INDEX idx_inv_drawer ON drawer_invitations(drawer_id);
CREATE INDEX idx_inv_token ON drawer_invitations(token);
CREATE INDEX idx_inv_valid ON drawer_invitations (token)
WHERE (max_uses IS NULL OR uses_count < max_uses);


