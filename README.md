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

## OpenSearch 連携の下準備
- `app/services/search_client.rb` に接続用クライアントを用意しています（`OPENSEARCH_URL` を利用）。次のステップで実際の API 呼び出しを実装してください。
- デフォルトの環境変数は `docker-compose.yml` の `OPENSEARCH_URL=http://opensearch:9200`。必要に応じて上書きしてください。

## 主要ファイル
- `app/app.rb` … Sinatra アプリ本体。
- `app/services/search_client.rb` … OpenSearch クライアント生成用のプレースホルダー。
- `config/puma.rb` … Rack サーバー設定（Puma）。
- `config.ru` … Rack エントリーポイント。
- `Dockerfile` / `docker-compose.yml` … 開発用コンテナ定義（ホットリロード対応）。`bundle` ボリュームは使わず、イメージビルド時の Bundler キャッシュを利用します。
