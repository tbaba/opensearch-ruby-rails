# Repository Guidelines

## Project Structure & Module Organization
- Rails-style layout: domain code in `app/`, supporting helpers in `lib/`, environment and OpenSearch/client settings in `config/`, database schema and seeds in `db/`, and request/feature/unit specs in `spec/`.  
- Keep new service classes or query objects in `app/services` and serializers/presenters in `app/serializers` to keep controllers light.  
- Sample data, fixtures, and factories should live alongside specs to keep test intent clear.

## Build, Test, and Development Commands
- `bundle install` — install Ruby and Rails dependencies.  
- `bin/rails db:prepare` — create/migrate the database; safe to run before tests or server start.  
- `bin/rails s` — start the app locally (defaults to `http://localhost:3000`).  
- `bundle exec rspec` — run the full test suite; add `SPEC=path/to/spec.rb` to scope.  
- `bundle exec rubocop` — format/lint Ruby code if RuboCop is enabled in this repo.

## Coding Style & Naming Conventions
- Ruby: 2-space indentation, UTF-8 files, avoid trailing whitespace.  
- Classes/modules use `CamelCase`; files and methods use `snake_case`; constants in `SCREAMING_SNAKE_CASE`.  
- Controllers stay thin: move complex query or indexing logic to POROs under `app/services` or `app/queries`.  
- Prefer explicit dependency injection for OpenSearch clients instead of globals to ease testing.

## Testing Guidelines
- Use RSpec; name specs as `something_spec.rb` under `spec/`.  
- Mirror app paths in specs (e.g., `app/services/foo.rb` → `spec/services/foo_spec.rb`).  
- Favor fast, isolated unit specs; add request/feature specs for behavior that spans controllers and OpenSearch indexing.  
- When adding OpenSearch interactions, provide test doubles or stubbed clients to keep suites deterministic.

## Commit & Pull Request Guidelines
- Commits: concise imperative subject (`Add user index mapping`), explain context in the body when needed, and group related changes.  
- PRs: include a short summary, test plan (`rspec`, `rubocop`, `bin/rails db:prepare` if schema changed), and link any issues or tickets.  
- Add screenshots or JSON samples when UI or API responses change; call out migration or indexing steps in the description.

## Security & Configuration Tips
- Do not commit secrets; use environment variables (e.g., `OPENSEARCH_URL`, credentials) and keep `.env`/`config/master.key` out of version control.  
- Verify indexes and mappings in non-production first; document any manual backfills or reindexing steps in the PR.  
- Keep dependencies updated and run `bundle audit` when available to catch vulnerable gems.

## Communication Rules
- Think in English and output in Japanese.
