# Monadic Chat CLI - Batch Processing Implementation Plan

## 概要

OpenAI Batch APIを使用した大量データ処理機能の実装計画。

### 主な特徴
- 多様な入力形式（テキスト、CSV、フォルダ）をサポート
- インタラクティブなバッチ設計（AIアシスタントによる支援）
- **2つの処理モード**: parallel（並列）と sequential（逐次/モナド的）
- 非同期処理（24時間以内の完了保証、50%コスト削減）※parallelモードのみ
- ジョブ管理（一覧、ステータス確認、キャンセル、結果取得）

---

## 処理モード

### Parallel モード（Batch API）
- 全レコードを独立して並列処理
- 50%コスト削減
- 順序保証なし
- ユースケース: 独立した文書の翻訳、分類、要約

### Sequential モード（通常API、モナド的処理）
- 前の処理結果を引き継いで逐次処理
- 通常料金
- 順序保証あり
- ユースケース:
  - 書籍の章ごと要約（前章の要約を参照）
  - 対話履歴を蓄積しながらの分析
  - 用語集を更新しながらの翻訳
  - 外国語学習用の例文を連続したストーリーとして作成

```
Sequential モードの処理フロー:

Record 1 → Result 1
              ↓
Record 2 + Result 1 → Result 2
                        ↓
Record 3 + Result 2 → Result 3
                        ↓
              ... (累積的に処理)
```

---

## アーキテクチャ

### 2段階AI呼び出し

```
┌─────────────────────────────────────────────────────────────┐
│ 段階1: インタラクティブ設計 (Responses API)                   │
│                                                             │
│  ユーザー ←→ AIアシスタント                                  │
│  - 入力データの確認                                          │
│  - プロンプト設計                                            │
│  - パラメータ設定                                            │
│  - コスト見積もり                                            │
│  - 確認・承認                                                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 段階2: バッチ実行 (Batch API)                                │
│                                                             │
│  1. JSONL生成 → 2. ファイルアップロード → 3. バッチ作成      │
│  4. ステータス監視 → 5. 結果取得 → 6. 出力整形               │
└─────────────────────────────────────────────────────────────┘
```

---

## ファイル構造

```
lib/monadic_chat/
├── batch/
│   ├── processor.rb        # バッチ処理のコアロジック
│   ├── input_parser.rb     # 入力形式の解析
│   ├── job_manager.rb      # ジョブの状態管理
│   ├── jsonl_builder.rb    # JSONL生成
│   ├── cost_estimator.rb   # コスト見積もり
│   └── output_formatter.rb # 結果の整形
├── batch_commands.rb       # CLIコマンド定義

~/.monadic_chat/
├── batches/
│   ├── batch_abc123.json   # ジョブメタデータ
│   └── ...
└── monadic_chat.conf       # 既存の設定ファイル
```

---

## CLIコマンド体系

### `monadic-chat batch start`

インタラクティブにバッチを設計・開始

```bash
$ monadic-chat batch start [INPUT_PATH] [--config CONFIG_FILE] [--mode MODE]

# オプション:
#   --mode, -m  処理モード: parallel (デフォルト) または sequential

# 対話例:
入力データを指定してください: ./data/documents/
→ 150個のMarkdownファイルを検出しました

処理内容を説明してください:
> 各文書を日本語に翻訳してください

モデルを選択してください:
  1. gpt-5-mini (推奨、コスト効率)
  2. gpt-5
  3. gpt-5.2
> 1

設定を確認します:
  入力: 150レコード
  モデル: gpt-5-mini
  推定コスト: $X.XX (Batch API 50%割引適用)
  推定時間: 1-4時間

この設定を保存しますか？ [Y/n]: y
保存先: ./translate_batch_config.json

バッチを開始しますか？ [Y/n]: y
バッチジョブを開始しました
  ジョブID: batch_abc123
  ステータス確認: monadic-chat batch status batch_abc123
```

### `monadic-chat batch list`

ジョブ一覧を表示

```bash
$ monadic-chat batch list

ID              STATUS        PROGRESS    MODEL        CREATED
batch_abc123    in_progress   45%         gpt-5-mini   2024-12-13 15:30
batch_def456    completed     100%        gpt-5        2024-12-13 10:00
batch_ghi789    failed        0%          gpt-5-mini   2024-12-12 20:00
```

### `monadic-chat batch status`

特定ジョブのステータス詳細

```bash
$ monadic-chat batch status batch_abc123

ジョブID: batch_abc123
ステータス: in_progress
進捗: 67/150 (45%)
開始時刻: 2024-12-13 15:30:00
推定残り時間: 約1時間
入力ファイル: ./data/documents/
設定ファイル: ./translate_batch_config.json
```

### `monadic-chat batch result`

結果を取得・保存

```bash
$ monadic-chat batch result batch_abc123 [--output OUTPUT_PATH] [--format FORMAT]

# オプション:
#   --output, -o  出力先パス（デフォルト: ./batch_results/）
#   --format, -f  出力形式: jsonl, csv, folder（デフォルト: folder）

結果を取得しています...
150件の結果を保存しました: ./batch_results/batch_abc123/
  成功: 148件
  失敗: 2件（エラーログ: ./batch_results/batch_abc123/errors.json）
```

### `monadic-chat batch cancel`

ジョブをキャンセル

```bash
$ monadic-chat batch cancel batch_abc123

ジョブ batch_abc123 をキャンセルしますか？ [y/N]: y
キャンセルしました
```

---

## 入力形式

### 1. テキストファイル（1行1レコード）

```text
This is the first document to process.
This is the second document to process.
This is the third document to process.
```

### 2. CSV

```csv
id,content
doc001,"This is the first document."
doc002,"This is the second document."
```

または見出しなし:
```csv
"This is the first document."
"This is the second document."
```

### 3. フォルダ（1ファイル1レコード）

```
input_folder/
├── document1.md
├── document2.md
├── document3.txt
└── data.json
```

---

## ジョブメタデータ形式

`~/.monadic_chat/batches/batch_abc123.json`:

```json
{
  "batch_id": "batch_abc123",
  "openai_batch_id": "batch_xyz789",
  "status": "in_progress",
  "created_at": "2024-12-13T15:30:00Z",
  "input": {
    "path": "/path/to/input",
    "type": "folder",
    "record_count": 150
  },
  "config": {
    "model": "gpt-5-mini",
    "system_prompt": "You are a translator...",
    "max_tokens": 2000,
    "temperature": 0.3
  },
  "custom_id_mapping": {
    "req-001": {"index": 0, "source": "document1.md"},
    "req-002": {"index": 1, "source": "document2.md"}
  },
  "output": {
    "path": null,
    "format": null
  },
  "stats": {
    "completed": 0,
    "failed": 0,
    "total": 150
  }
}
```

---

## JSONL生成形式

Batch APIに送信するJSONL:

```jsonl
{"custom_id": "req-001", "method": "POST", "url": "/v1/responses", "body": {"model": "gpt-5-mini", "input": [{"role": "system", "content": "You are a translator..."}, {"role": "user", "content": "Document content here..."}], "max_output_tokens": 2000}}
{"custom_id": "req-002", "method": "POST", "url": "/v1/responses", "body": {"model": "gpt-5-mini", "input": [{"role": "system", "content": "You are a translator..."}, {"role": "user", "content": "Another document..."}], "max_output_tokens": 2000}}
```

---

## 実装フェーズ

### Phase 1: 基盤実装 ✅ 完了
- [x] ファイル構造の作成
- [x] 入力パーサー（テキスト、CSV、フォルダ）
- [x] JSONL生成
- [x] ジョブメタデータ管理

### Phase 2: Batch API連携 ✅ 完了
- [x] ファイルアップロード（Files API）
- [x] バッチ作成
- [x] ステータス確認
- [x] 結果取得

### Phase 3: CLIコマンド ✅ 完了
- [x] `batch start` コマンド
- [x] `batch list` コマンド
- [x] `batch status` コマンド
- [x] `batch result` コマンド
- [x] `batch cancel` コマンド
- [x] `batch wait` コマンド（追加）
- [x] `batch profile` コマンド（追加）

### Phase 4: インタラクティブ設計 ✅ 完了
- [x] AIアシスタントによる対話的設定（Batchアプリ）
- [x] コスト見積もり
- [x] 設定の保存・読み込み（プロファイル機能）
- [x] ネイティブツール呼び出しAPI対応

### Phase 5: 仕上げ ✅ 完了
- [x] エラーハンドリング強化
- [x] テスト（370件のユニットテスト）
- [x] ドキュメント
- [x] Sequential モード（AI要約付き累積処理）

---

## 依存ライブラリ

既存:
- `csv` (標準ライブラリ)
- `json` (標準ライブラリ)
- `http` (HTTP通信)

追加検討:
- なし（既存で対応可能）

---

## 注意事項

1. **Responses API形式**: GPT-5シリーズはResponses APIを使用するため、JONLの`body`は`messages`ではなく`input`キーを使用

2. **custom_id**: 入力データにIDがない場合は自動生成（`req-{index}`形式）

3. **エラー処理**: 失敗したレコードはスキップし、エラーログに記録

4. **結果の順序**: `custom_id`でマッチングして元の順序を復元

5. **コスト**: Batch APIは通常の50%割引だが、24時間以内の完了が保証

---

## ネイティブツール呼び出しAPI

バッチ処理アシスタントアプリは、OpenAIのネイティブツール呼び出しAPIを使用して、以下のツールを自動的に呼び出すことができます。

### 有効化されているツール

**バッチツール:**
| ツール名 | 説明 |
|---------|------|
| `batch_list_profiles` | 保存済みプロファイル一覧を取得 |
| `batch_check_path` | ファイル/ディレクトリの存在確認 |
| `batch_recent_jobs` | 最近のジョブ一覧を取得 |
| `batch_start` | バッチジョブを開始 |
| `batch_status` | ジョブ状態を確認 |
| `batch_result` | 結果を取得 |
| `batch_create_input_file` | 入力ファイルを作成 |
| `batch_save_profile` | プロファイルを保存 |

**ファイルツール:**
| ツール名 | 説明 |
|---------|------|
| `file_read` | ファイル内容を読み取り |
| `file_write` | ファイルに書き込み |
| `file_list` | ディレクトリ内容を一覧表示 |

### セキュリティ制限

- ファイル操作は許可されたパスのみ（作業ディレクトリ、~/Downloads、~/Documents、~/.monadic_chat）
- ファイル読み取り上限: 1MB
- ファイル書き込み上限: 100KB
- パストラバーサル攻撃の防止

---

## 実装完了日

- 2024年12月14日: 全フェーズ完了
