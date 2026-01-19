-- =========================================================
-- [8] Events: Soft Delete 및 동기화 인덱스
-- =========================================================
CREATE TABLE events (
  id UUID PRIMARY KEY,
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  series_id UUID NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  summary TEXT NOT NULL,
  description TEXT,
  color INT NOT NULL,
  r_rule TEXT,
  forked_from UUID REFERENCES events (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- 추가됨
);

-- [최적화] Drawer 단위 동기화 속도 향상 (복합 인덱스)
CREATE INDEX idx_events_sync ON events(drawer_id, updated_at);
CREATE INDEX idx_events_series_id ON events(series_id);


-- =========================================================
-- [9] Event Instances: Soft Delete 필수
-- =========================================================
CREATE TABLE event_instances (
  id UUID PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES events (id) ON DELETE CASCADE,
  summary TEXT,
  description TEXT,
  color INT,
  location JSONB,
  is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
  original_date TIMESTAMPTZ NOT NULL,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- 추가됨
);

CREATE INDEX idx_event_inst_event ON event_instances (event_id);
-- 날짜 범위 조회용 (캘린더 뷰)
CREATE INDEX idx_event_inst_range ON event_instances (start_date, end_date);
-- [최적화] 동기화용: 인스턴스는 보통 EventID나 날짜 범위로 좁혀지므로 updated_at 단독도 괜찮음
CREATE INDEX idx_event_inst_sync ON event_instances (updated_at);


-- =========================================================
-- [10] Event Participants: 참가 취소 동기화
-- =========================================================
CREATE TABLE event_participants (
  instance_id UUID NOT NULL REFERENCES event_instances (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  state INT NOT NULL DEFAULT 0,
  memo JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ, -- 추가됨 (참가자 목록에서 제거된 경우)
  PRIMARY KEY (instance_id, user_id)
);

CREATE INDEX idx_event_participant_sync ON event_participants (updated_at);