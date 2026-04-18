# mac-bootstrap

Apple Silicon Mac(M1/M2/M3/M4)용 1회성 부트스트랩 스크립트.
Homebrew, 공통 개발 도구, 자주 쓰는 앱, macOS 기본 환경설정까지 한 번에 준비합니다. 재실행 안전(idempotent).

## 설치되는 것

- **CLI 도구**: `git`, `gh`, `jq`, `fzf`, `ripgrep`, `fd`, `bat`, `tree`, `htop`, `coreutils`, `gnu-sed`, `mas`
- **런타임**: `python`, `pipx`, `node`, `pnpm`, `bun`
- **GUI 앱(Cask)**: Chrome, VS Code, iTerm2, Rectangle, AppCleaner, Obsidian, Claude, Claude Code, Ghostty, OrbStack
- **Mac App Store**: KakaoTalk (`mas` 경유)
- **옵션**: Ollama (AI), Redis + PostgreSQL 18 (DB)

동시에 다음이 세팅됩니다:
- Xcode Command Line Tools
- Rosetta 2 (Intel 앱 대비)
- Homebrew (`/opt/homebrew`) + `~/.zprofile` PATH 설정
- SSH 키(ed25519) 생성 + `~/.ssh/config` 작성 (Host github.com)
- `~/Brewfile` 생성 (이후 `brew bundle` 로 재현 가능)

### 적용되는 macOS defaults

| 항목 | 값 |
|---|---|
| 다크 모드 | on |
| 모든 파일 확장자 표시 | on |
| Finder 숨김 파일 표시 | on |
| Finder 기본 보기 | 리스트 뷰 |
| Dock 자동 숨김 | on |
| 키 반복 속도 | 최대 (`KeyRepeat=2`, `InitialKeyRepeat=15`) |
| 트랙패드 tap to click | on |

모두 `defaults write` 로 적용되며 System Settings에서 되돌릴 수 있습니다.

## 요구사항

- **Apple Silicon (arm64) macOS**. Intel Mac에서는 실행 시 종료합니다.
- macOS 13 이상 권장 (Ghostty가 요구).
- App Store 로그인(KakaoTalk 설치 시).

## 사용법

> 원격 실행 스크립트는 시스템에 전반적으로 영향을 줍니다. 돌리기 전에 [bootstrap.sh](bootstrap.sh)를 한 번 훑어보고, 본인에게 불필요한 항목은 환경변수 토글로 끄거나 본인 fork에서 직접 수정해 쓰는 것을 권장합니다.

### 빠른 설치 (원격 실행)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ibank/mac-bootstrap/main/bootstrap.sh)"
```

Git 사용자 정보를 함께 설정:

```bash
GIT_USER_NAME="홍길동" GIT_USER_EMAIL="me@example.com" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ibank/mac-bootstrap/main/bootstrap.sh)"
```

> `curl ... | bash` 대신 `bash -c "$(...)"` 형태인 이유: 파이프 방식은 stdin을 스크립트 본문이 점유해 `sudo` 재인증이 깨질 수 있습니다.

### 로컬 클론 후 실행

```bash
git clone https://github.com/ibank/mac-bootstrap.git
cd mac-bootstrap
./bootstrap.sh
```

### 옵션 (환경변수 토글)

| 변수 | 기본값 | 설명 |
|---|---|---|
| `INSTALL_CASK_APPS` | `1` | GUI 앱(Cask) 설치 여부 |
| `INSTALL_AI_TOOLS` | `0` | Ollama 설치 |
| `INSTALL_DB_TOOLS` | `0` | Redis + PostgreSQL@18 설치 |
| `INSTALL_KAKAOTALK` | `1` | Mac App Store에서 KakaoTalk 설치 |
| `SKIP_BREW_UPDATE` | `0` | `brew update` 건너뛰기 |
| `GIT_USER_NAME` | - | `git config --global user.name` |
| `GIT_USER_EMAIL` | - | `git config --global user.email` |

예:

```bash
INSTALL_AI_TOOLS=1 INSTALL_DB_TOOLS=1 ./bootstrap.sh
```

## 설치 후 해야 할 것

1. 새 터미널 열기 (PATH/zprofile 반영)
2. `gh auth login` — GitHub 로그인
3. `claude` 실행 → Claude Code 로그인
4. VS Code 실행 후 커맨드 팔레트 → *Shell Command: Install 'code' command in PATH*
5. OrbStack 1회 실행하여 초기화
6. KakaoTalk 미설치 시 App Store 로그인 후 스크립트 재실행

## 보안 / 주의사항

- **SSH 키는 passphrase 없이 생성**됩니다(비대화형 실행). 사용 중이라면 passphrase를 설정하고 Keychain에 저장하는 것을 권장합니다:

  ```bash
  ssh-keygen -p -f ~/.ssh/id_ed25519
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  ```

- **`git config --global` 값이 덮여 씁니다.**
  - `credential.helper` → `osxkeychain` 으로 무조건 설정
  - `user.name`, `user.email` → `GIT_USER_NAME` / `GIT_USER_EMAIL` 환경변수를 넘겼을 때만 설정
  - 기존 전역 git 설정을 쓰고 있다면 실행 전 `git config --global --list`로 확인하세요.

- Claude Code Homebrew cask는 auto-update가 없습니다. Anthropic 공식 권장 설치 방식은 native installer입니다:

  ```bash
  curl -fsSL https://claude.ai/install.sh | bash
  ```

## 재현: Brewfile

스크립트 실행 후 `~/Brewfile`이 생성됩니다. 새 환경에서 재현:

```bash
brew bundle --file ~/Brewfile
```

단, 선택 옵션(`INSTALL_AI_TOOLS`, `INSTALL_DB_TOOLS`)은 Brewfile에 포함되지 않습니다. 필요 시 직접 추가하세요.

## License

MIT — [LICENSE](LICENSE) 참고.
