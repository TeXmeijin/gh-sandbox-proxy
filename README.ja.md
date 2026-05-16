# gh-sandbox-proxy

日本語 | [English](README.md)

`gh-sandbox-proxy` は、公式 GitHub CLI (`gh`) を使い捨ての Docker
コンテナ内で実行する、`gh` 互換寄りの wrapper です。

## なぜ作るか

近年のパッケージ supply-chain incident により、開発端末に置かれた CLI
認証情報の扱いは、より現実的なリスクとして見直す必要が出てきました。
GitHub CLI の認証情報がホスト OS 内の予測しやすい場所に永続化され、
さらに単一のコマンドで利用可能な token を表示できる状態は、攻撃者にとって
価値の高い足場になりえます。

このプロジェクトは、端末侵害そのものを完全に防ぐことを主張しません。狙いは
もっと限定的です。ホスト OS を GitHub CLI credential の回収場所として
使いにくくしつつ、普段の `gh` の利便性をできるだけ落とさないことです。
これは保証ではなく、攻撃者に追加の摩擦を課すための実用的なレイヤーです。

設計上の目標は次の通りです。

- GitHub CLI の auth state をホスト OS に置かない
- ホスト側で `gh auth token` を実行しても有用な token を返さない
- 主要な `gh` コマンドのインターフェースをできるだけ変えない
- 認証済み sandbox を短い TTL で失効させる。デフォルトは `1h`

Docker image は、対応する Linux architecture 向け GitHub CLI release
asset の SHA256 checksum を固定して検証します。

これは任意のローカルコード実行に対する完全な防御ではありません。sandbox
container が生きている間、その container 内でコマンドを実行できる主体は、
container-local の GitHub CLI session を利用できます。

## インストール

通常は次を実行します。

```zsh
./install.sh
```

`~/.local/bin` が PATH に入っていない場合は、表示された PATH 設定を shell
config に追加してください。

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

新しい shell を開いて確認します。

```zsh
which gh
gh --help
gh auth token
```

`which gh` は install された wrapper symlink を指すはずです。
`gh auth token` は wrapper によって block されます。

Claude Code など、shell startup file を安定して読まない agent では、
system-level symlink を使います。

```zsh
./install.sh --system-link
```

これは既存の `/usr/local/bin/gh` を一度だけ backup し、この wrapper への
symlink に置き換えます。Homebrew の公式 `gh` は `/opt/homebrew/bin/gh`
などに残ります。

uninstall は次です。

```zsh
./uninstall.sh
```

## Agent Setup

この repository には Claude Code Skill も含めています。

```text
skills/gh-sandbox-proxy-installer/SKILL.md
```

別の machine で agent に install、verify、PATH 問題の調査、uninstall を
任せる場合に使えます。実際の machine 変更は `install.sh` / `uninstall.sh`
に集約しているため、人間が実行しても agent が実行しても同じ手順になります。

## 使い方

通常の `gh` と同じように使います。

```zsh
gh issue view 123
gh pr list
gh pr create -B develop -d
gh workflow run "Deploy" --ref "$(git branch --show-current)"
```

`gh pr list -w` のように browser を開くコマンドも proxy します。Linux 版
`gh` process が container-local hook に URL を渡し、その URL を wrapper が
macOS host 側で開きます。

テスト時は host opener を上書きできます。

```zsh
GH_SANDBOX_OPEN=/bin/echo gh pr list -w
```

初回の認証が必要な command では、container 内で次が実行されます。

```zsh
gh auth login -h github.com --web
```

表示された browser/device flow に従ってください。token は host の GitHub CLI
config ではなく、sandbox に紐づく Docker volume に保存されます。この volume
は TTL expiry または `gh sandbox cleanup` で削除されます。

## Sandbox 操作

```zsh
gh sandbox status
gh sandbox cleanup
gh sandbox build
gh sandbox config
```

`cleanup` は現在の container と auth volume をすぐに削除します。

## Config

デフォルトの config path:

```text
~/.config/gh-sandbox-proxy/config.yml
```

上書き:

```zsh
export GH_SANDBOX_CONFIG=/path/to/config.yml
```

主な項目:

```yaml
image: gh-sandbox-proxy:latest
ttl: 1h
container_name: gh-sandbox-proxy
workdir_mount: true
auto_auth: true
auth_hostname: github.com
blocked:
  - ["auth", "token"]
  - ["auth", "status", "--show-token"]
```

YAML parser は意図的に小さくしています。`config.example.yml` と同じ単純な
shape で書いてください。

## Security Model

この wrapper は、長期的に残る host GitHub CLI token を不用意に露出するリスクを
下げることを目的にしています。

- host 側の `gh auth token` を block する
- host 側の `gh auth status --show-token` を block する
- 公式 `gh` の auth file を active sandbox session 用 Docker volume に置く
- container と auth volume は `ttl` 後に作り直す。デフォルトは `1h`
- `gh sandbox cleanup` で認証済み container と auth volume を即時削除する

この wrapper が防げないものもあります。

- Docker administrator は container に inspect / exec できる
- Docker administrator は Docker volume を inspect できる
- container 内で実行された command は active GitHub session を利用できる
- container を削除しても GitHub 側で発行済み OAuth token が自動 revoke される
  わけではない
- current working directory を mount するため、container 内 command はその
  directory を読み書きできる

より制限したい場合は `workdir_mount: false` にし、可能な command では
`--repo OWNER/REPO` を明示してください。

Docker Desktop for Mac では、current directory が Docker file sharing に含まれて
いない場合に mount が失敗することがあります。その場合 wrapper は `/work` mount
なしで retry します。repo-local command では `--repo OWNER/REPO` が必要になる
ことがあります。

別 repository から `gh` を実行すると、wrapper はその repository を `/work` に
mount するため container を作り直します。auth volume は TTL が切れるまで維持
されます。

## License

MIT
