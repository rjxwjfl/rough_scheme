-- 시스템 로그 전용
CREATE TABLE user_activities (
  id BIGSERIAL NOT NULL,
  drawer_id UUID,
  actor_id UUID,
  action_type INT NOT NULL,
  target_type INT NOT NULL,
  target_id UUID NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-----------------------------------------
-- 3. 활동 피드 (activity_feeds)
-- [역할] Drawer 내의 타임라인 (Facebook 담벼락, Slack 채널 로그)
-- [특징] Broadcast 성격 (구독자 모두에게 보임), 휘발되지 않음
-----------------------------------------
CREATE TABLE activity_feeds (
  id BIGSERIAL NOT NULL,
  origin_uuid UUID NOT NULL, 
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  action_type VARCHAR(20) NOT NULL, 
  target_type VARCHAR(20) NOT NULL,
  target_id UUID NOT NULL, 
  meta_data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- 인덱스: Drawer별 조회 최적화
CREATE INDEX idx_feed_drawer_cursor ON activity_feeds (drawer_id, created_at DESC, id DESC);
CREATE UNIQUE INDEX uq_activity_feeds_origin ON activity_feeds(origin_uuid, created_at);

-----------------------------------------
-- 3-1. 피드 읽음 커서 (activity_feed_cursors)
-- [핵심 수정 2] ID와 시간을 동시에 기록하여 정렬 안정성 확보
-----------------------------------------
CREATE TABLE activity_feed_cursors (
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  
  -- 어디까지 읽었는지 (Checkpoint)
  last_read_feed_id BIGINT NOT NULL DEFAULT 0,
  last_read_feed_at TIMESTAMPTZ NOT NULL DEFAULT '-infinity',
  
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  PRIMARY KEY (user_id, drawer_id)
);

CREATE TABLE reminders (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  parent_type INT NOT NULL, -- 0 = event, 1 = task
  parent_id UUID NOT NULL,
  base_time TIMESTAMPTZ NOT NULL,
  trigger_at TIMESTAMPTZ NOT NULL, -- 절대 시간 (trigger_offset 대신 직접 지정)
  trigger_offset INTERVAL, -- 시작 기준 offset (-PT10M, -P1D 같은 ISO8601 형태 가능)
  method INT NOT NULL DEFAULT 0, -- 0=푸시, 1=이메일, 2=SMS 등 확장
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rem_user ON reminders(user_id);

-----------------------------------------
-- Notifications (User Inbox / Push)
-----------------------------------------
  -- ===============================
  -- Routing (핵심)
  -- ===============================
  -- 1 = Drawer
  -- 2 = CalendarEvent
  -- 3 = CalendarTask
  -- 4 = Post
  -- 5 = MessageThread
  -- 6 = System
  -- [알림 성격]
  -- 예:
  -- 1 = DrawerInvite
  -- 2 = DrawerJoinApproved
  -- 3 = CalendarEventAdded
  -- 4 = Mention

CREATE TABLE notifications (
  id UUID NOT NULL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  recipient_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users (id) ON DELETE SET NULL,
  notification_type INT NOT NULL,
  route_type INT NOT NULL,
  route_id UUID,
  drawer_id UUID REFERENCES drawers (id) ON DELETE CASCADE,
  title TEXT,
  body TEXT,
  payload JSONB,
  is_read BOOLEAN NOT NULL DEFAULT FALSE
) PARTITION BY RANGE (created_at);

CREATE INDEX idx_noti_recipient_cursor
  ON notifications (recipient_id, created_at DESC);

CREATE INDEX idx_noti_route
  ON notifications (route_type, route_id);