# opensearch-ruby-rails

Sinatra ベースの最小構成。Docker Compose で立ち上げ、ローカルの変更が即時コンテナに反映されます。次工程で OpenSearch をつなぎ込めるようにクライアント用のプレースホルダーを用意しています。

## 事前準備
- Docker / Docker Compose が使えること。

## 起動方法
```sh
docker-compose up --build
```
- ブラウザで `http://localhost:4567/` を確認できます。
- ヘルスチェックは `http://localhost:4567/health`。`OPENSEARCH_URL` がレスポンスに含まれます。
- `rerun` + ボリュームマウントで `app/` や `config/` の変更が即反映されます。
- OpenSearch も同時に起動します（`public.ecr.aws/opensearchproject/opensearch:1.3.20`）。`http://localhost:9200` で確認できます。

## 書籍登録/検索の使い方
- UI
  - 登録: `http://localhost:4567/books/new`
  - 検索: `http://localhost:4567/books/search`
- API
  - 登録: `POST http://localhost:4567/api/books`（JSON で `title`, `author` 必須）
  - 検索: `GET  http://localhost:4567/api/books/search?q=キーワード`

## OpenSearch 連携の下準備
- `app/services/search_client.rb` に接続用クライアントを用意しています（`OPENSEARCH_URL` を利用）。次のステップで実際の API 呼び出しを実装してください。
- デフォルトの環境変数は `docker-compose.yml` の `OPENSEARCH_URL=http://opensearch:9200`。必要に応じて上書きしてください。

## 主要ファイル
- `app/app.rb` … Sinatra アプリ本体。
- `app/services/search_client.rb` … OpenSearch クライアント生成用のプレースホルダー。
- `config/puma.rb` … Rack サーバー設定（Puma）。
- `config.ru` … Rack エントリーポイント。
- `Dockerfile` / `docker-compose.yml` … 開発用コンテナ定義（ホットリロード対応）。`bundle` ボリュームは使わず、イメージビルド時の Bundler キャッシュを利用します。
- `docker-compose.yml` の `opensearch` サービス … 開発用 OpenSearch 1.3.20（セキュリティ無効、データは `opensearch-data` ボリュームに永続化）。
