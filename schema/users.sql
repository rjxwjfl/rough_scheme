-----------------------------------------
-- 사용자 정보 테이블
-- Soft delete
-- 유저 탈퇴 시 데이터 보관
-- 파기 시 기존 유저의 작성 데이터 등은 유령유저로 변경
-----------------------------------------
CREATE TABLE users (
  id UUID PRIMARY KEY,
  firebase_uid VARCHAR(128) UNIQUE,
  email VARCHAR(255) UNIQUE NOT NULL,
  provider VARCHAR(20),
  display_name VARCHAR(100) NOT NULL,
  user_code VARCHAR(8) UNIQUE NOT NULL,
  bio TEXT,
  image_url TEXT,
  thumbnail_url TEXT,
  status INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  latest_activity_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_user_usercode ON users(user_code);

CREATE TABLE user_devices (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  device_uuid UUID NOT NULL, -- 디바이스에서 생성하여 secure storage에 저장
  device_token TEXT,
  platform VARCHAR(20) NOT NULL,
  device_name TEXT, -- 디바이스 이름. 기종명. 
  app_version TEXT,
  os_version TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  last_used_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, device_uuid)
);

CREATE INDEX idx_user_devices_token ON user_devices (device_token);