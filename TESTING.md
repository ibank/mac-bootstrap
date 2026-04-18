# Testing

두 가지 레이어로 검증합니다:

- **CI 스모크 (자동)** — GitHub Actions `macos-15` 러너에서 매 push/PR/주간 스케줄에 자동 실행. 상류 Homebrew formula/cask rename 같은 breakage를 조기 탐지.
- **tart (수동)** — 로컬 Apple Silicon Mac에서 깨끗한 macOS VM을 반복 기동해 full-stack 검증 (defaults, GUI 앱 설치 포함).

---

## CI 스모크 테스트

[.github/workflows/smoke.yml](.github/workflows/smoke.yml) 이 다음을 자동화합니다:

| Job | Runner | 내용 |
|---|---|---|
| `lint` | `ubuntu-latest` | `shellcheck bootstrap.sh` |
| `smoke` | `macos-15` (Apple Silicon) | `./bootstrap.sh` 실제 실행 |

트리거: push to `main`, PR, 매주 월요일 05:00 UTC, manual dispatch.

### CI 러너 한계

Runner에선 다음이 완전 검증되지 않습니다:

- `softwareupdate --install-rosetta` — CI에선 지원 안 됨 (스크립트는 `|| true`로 무시)
- `defaults write` 결과 — GUI 세션 없음. write는 성공하지만 사용자 경험은 검증 못 함.
- Cask 앱의 실제 실행 — 설치까지만 검증.
- `INSTALL_KAKAOTALK=1` — App Store 로그인 불가능하므로 항상 `0` 강제.

→ 실사용 흐름 검증은 아래 tart 로컬 테스트로 보완.

---

## tart 로컬 VM 테스트

tart로 깨끗한 macOS VM을 띄워 `bootstrap.sh`를 반복 검증하는 방법.

## 요구사항

- Apple Silicon Mac (tart는 Apple Silicon 전용)
- Homebrew
- Apple EULA: 같은 호스트에서 macOS VM은 동시에 2개까지

## 설치

```bash
brew install cirruslabs/cli/tart
```

## Base 이미지 준비 (1회)

공식 cirruslabs 이미지를 `base` 라는 이름으로 로컬에 받아둡니다. 이후 테스트마다 이 `base`를 복제해 씁니다 (네트워크에서 재다운로드 안 해도 되므로 빠름).

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest base
```

## 테스트 사이클

### 1. 새 VM 복제 + 기동

```bash
tart clone base test-run
tart run test-run
```

VM 창이 열립니다. 잠시 뒤 로그인 화면이 뜨면:

- **사용자명**: `admin`
- **비밀번호**: `admin`
- **sudo 비밀번호**: `admin` (같은 계정)

### 2. 스크립트 실행

VM 내부 터미널에서:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ibank/mac-bootstrap/main/bootstrap.sh)"
```

로컬 수정본을 테스트하려면 repo 루트에서 파일을 VM으로 전송해 실행:

```bash
# 호스트에서
scp bootstrap.sh admin@$(tart ip test-run):~/bootstrap.sh

# VM에서
chmod +x ~/bootstrap.sh && ~/bootstrap.sh
```

### 3. SSH 접속 (복붙 편의)

VM 창 안에서 타이핑하기 불편하면 호스트에서 SSH로:

```bash
tart ip test-run                       # IP 확인
ssh admin@$(tart ip test-run)          # 비밀번호: admin
```

### 4. 정리 후 다음 테스트

VM은 한 번 돌리면 상태가 오염되므로, 다음 테스트 전에 폐기하고 `base` 에서 새로 복제:

```bash
tart stop test-run
tart delete test-run

tart clone base test-run
tart run test-run
```

## 참고

- tart 공식: https://tart.run
- cirruslabs base 이미지 (버전별): https://github.com/cirruslabs/macos-image-templates
- macOS Sequoia 외 (Sonoma 등) 이미지를 쓰려면 `ghcr.io/cirruslabs/macos-sonoma-base:latest` 등으로 교체.
