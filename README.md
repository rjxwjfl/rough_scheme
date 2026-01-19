# Database Schema

본 데이터베이스 스키마는 **협업 캘린더 + 태스크 관리 + 채팅**을  
하나의 일관된 컨텍스트로 통합하기 위한 구조이다.

Slack(채팅), Google Calendar(일정), Notion/Asana(태스크)의 핵심 개념을  
**Drawer → Series → Event/Task/Message** 계층으로 재구성하였다.

본 문서는 DB 구조의 **Source of Truth**이며,  
모든 스키마 변경은 GitHub PR 및 Migration을 통해 관리된다.

---

## 1. 설계 목표 (Design Goals)

- 모바일 환경에서의 **오프라인/온라인 동기화 최적화**
- 실시간 푸시 알림 타겟팅을 고려한 데이터 분리
- Soft Delete 기반 데이터 보존 및 복구 가능성 확보
- 대규모 JOIN 최소화를 위한 선택적 비정규화
- 협업 컨텍스트 단위 권한 모델 제공

---

## 2. 핵심 개념 (Core Concepts)

### Drawer
- 최상위 협업 단위
- 팀 / 프로젝트 / 그룹을 의미
- 모든 Event, Task, Message는 Drawer에 귀속됨

### Series
- Drawer 내부의 **주제 / 권한 / 채널** 개념
- 채팅, 이벤트, 태스크의 논리적 묶음 단위
- 공개/비공개 및 화이트리스트 기반 접근 제어 지원

### Event / Task
- Event: 시간 기반 일정 (반복, 분기, 인스턴스 지원)
- Task: 수행 단위 작업 (반복, 우선순위, 담당자 지원)
- 둘 다 Instance 테이블을 통해 개별 실행 단위 관리

### Message
- Series 단위 채팅
- 멘션, 리액션, 첨부파일, 링크 미리보기 지원
- 동기화 및 푸시 최적화를 위한 구조 분리

---

## 3. 사용자(User) 설계 원칙

### Soft Delete
- `deleted_at` 컬럼을 통한 논리 삭제
- 탈퇴 유저의 데이터는 보존
- 완전 파기 시 기존 작성 데이터는 **유령 유저(Ghost User)** 로 전환

### 디바이스 관리
- 사용자당 복수 디바이스 허용
- 푸시 토큰(device_token) 관리
- 마지막 사용 시각 기반 활성 디바이스 판별

---

## 4. 권한 모델

### Drawer Members
- Drawer 단위 멤버십 및 권한 관리
- 역할(Role)
  - 0: Owner
  - 1: Admin
  - 2: Editor
  - 3: Participant

### Series Access
- Series 단위 접근 범위 설정
- 화이트리스트 기반 사용자 제한 가능
- 권한 변경 역시 Soft Delete + updated_at 기반 동기화

---

## 5. Soft Delete 전략

### 적용 대상
- users
- drawers
- drawer_members
- series
- messages
- events / event_instances
- tasks / task_instances
- participants (event / task)

### 목적
- 모바일 클라이언트 동기화 시
  - "삭제된 데이터"를 명확히 전달
- 실수 삭제 복구 가능성 확보
- 히스토리 추적

> **주의:**  
> Soft Delete된 레코드는 기본 조회 쿼리에서 반드시 제외해야 한다.

---

## 6. 동기화(Sync) 설계

### 기본 원칙
- 모든 주요 테이블은 `updated_at`을 기준으로 증분 동기화
- 클라이언트는 마지막 동기화 시각 이후 변경 사항만 요청

### 인덱스 전략
- `(drawer_id, updated_at)`
- `(series_id, updated_at)`
- `(user_id, updated_at)`

이를 통해:
- Drawer 단위 동기화
- 사용자 기준 변경 사항 조회
- 대규모 데이터에서도 선형 확장 가능

---

## 7. 메시징(Message) 구조

### 분리된 테이블
- messages
- message_attachments
- message_embeds
- message_reactions
- message_mentions

### 분리 이유
- 채팅 로딩 성능 최적화
- 푸시 알림 타겟팅 (멘션, @everyone)
- 리액션/첨부파일의 독립적 동기화

---

## 8. 이벤트(Event) 구조

- Event: 논리적 일정 정의
- Event Instance: 실제 발생 단위
- 반복 일정(RRULE) 및 분기(Fork) 지원
- 참가자(Event Participants) 별도 관리

---

## 9. 태스크(Task) 구조

- Task: 논리적 작업 정의
- Task Instance: 실제 수행 단위
- 반복 규칙 및 완료 조건 분리
- 담당자(Task Participants) 상태 관리

---

## 10. 디렉터리 구조

```text
database/
├─ schema/        # 사람이 읽는 기준 설계
├─ migrations/    # 실행 순서 보장되는 변경 이력
├─ seeds/         # 개발/테스트용 초기 데이터
└─ README.md      # 본 문서

## 11. 변경 규칙 (IMPORTANT)
schema/ 파일은 현재 설계의 정답

운영 DB 변경은 반드시 migrations/를 통해서만 수행

기존 Migration 파일은 절대 수정하지 않는다

모든 변경은 PR 리뷰를 거친다

12. 비고
본 스키마는 초기 MVP부터
중대형 서비스 확장을 모두 고려하여 설계되었다.

필요 시:

파티셔닝

읽기 전용 Replica

이벤트/메시지 아카이빙

으로 확장 가능하다.

yaml
코드 복사
