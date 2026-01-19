-- =========================================================
-- [11] Tasks: Soft Delete 추가
-- =========================================================
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  drawer_id UUID NOT NULL REFERENCES drawers (id) ON DELETE CASCADE,
  series_id UUID NOT NULL REFERENCES series (id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  task_type INT NOT NULL,
  parent_type INT,
  parent_id UUID,
  summary TEXT NOT NULL,
  description TEXT,
  default_completion_rule INT NOT NULL DEFAULT 0,
  r_rule TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- 추가됨
);

-- [최적화] Drawer 단위 동기화 (복합 인덱스)
CREATE INDEX idx_tasks_sync ON tasks(drawer_id, updated_at);
CREATE INDEX idx_tasks_series ON tasks(series_id);

  
-- =========================================================
-- [12] Task Instances: Soft Delete 추가
-- =========================================================
CREATE TABLE task_instances (
  id UUID PRIMARY KEY,
  task_id UUID NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
  summary TEXT,
  description TEXT,
  priority INT NOT NULL DEFAULT 0,
  location JSONB,
  is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
  completion_rule INT,
  original_date TIMESTAMPTZ NOT NULL,
  available_from TIMESTAMPTZ,
  end_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ -- 추가됨
);

CREATE INDEX idx_task_inst_task ON task_instances (task_id);
-- 마감일 기준 정렬/조회 최적화
CREATE INDEX idx_task_inst_range ON task_instances (end_date, available_from);
CREATE INDEX idx_task_inst_sync ON task_instances (updated_at);


-- =========================================================
-- [13] Task User: 담당자 해제 동기화
-- =========================================================
CREATE TABLE task_participants (
  instance_id UUID NOT NULL REFERENCES task_instances (id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  state INT NOT NULL DEFAULT 0,
  memo JSONB,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ, -- 추가됨
  PRIMARY KEY (instance_id, user_id)
);