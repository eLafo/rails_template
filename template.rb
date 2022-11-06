gem_group :development do
    gem "annotate", group: :development
    gem "rubocop", require: false
    gem "rubocop-faker", require: false
    gem "rubocop-rails", require: false
    gem "rubocop-rspec", require: false
    gem "solargraph"
  end
  
  gem_group :development, :test do
    gem "capybara"
    gem "capybara-screenshot"
    gem "factory_bot_rails"
    gem "faker"
    gem "i18n-tasks", require: false
    gem "launchy"
    gem "rspec-rails"
    gem "webdrivers", require: false
    gem "webmock", require: false
    gem "yard"
  end
  
  unless File.exist? 'docker-compose.yml'
    create_file 'docker-compose.yml' do <<~YAML
      version: "3.1"
  
      services:
        db:
          image: postgres
          restart: always
          environment:
            POSTGRES_USER: #{app_name}
            POSTGRES_PASSWORD: #{app_name}
          volumes:
            - postgres:/var/lib/postgresql
          ports:
            - 5432:5432
  
        redis:
          image: redis
          restart: always
          volumes:
            - redis:/data
          ports:
            - 6379:6379
  
        mailcatcher:
          image: tophfr/mailcatcher
          ports:
            - "1080:80"
            - "25:25"
  
      volumes:
        redis: {}
        postgres: {}
    YAML
    end
  end
  
  remove_file 'config/database.yml'
  create_file 'config/database.yml' do <<~EOF
    default: &default
      adapter: postgresql
      encoding: unicode
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  
    development:
      <<: *default
      database: #{app_name}_development
      username: #{app_name}
      password: #{app_name}
      host: localhost
      port: 5432
  
    test:
      <<: *default
      database: #{app_name}_test
      username: #{app_name}
      password: #{app_name}
      host: localhost
      port: 5432
  
    production:
      <<: *default
      url: <%= ENV['DATABASE_URL'] %>
    EOF
  end
  
  create_file '.rubocop.yml' do <<~EOF  
      require:
        - rubocop-rspec
        - rubocop-faker
        - rubocop-rails
  
      AllCops:
        NewCops: enable
        Exclude:
          - bin/*
          - db/schema.rb
  
      Layout/HashAlignment:
        Exclude:
          - lib/tasks/auto_annotate_models.rake
  
      Metrics/BlockLength:
        Exclude:
          - lib/tasks/auto_annotate_models.rake
  
      Style/BlockComments:
        Exclude:
          - spec/spec_helper.rb
  
      Style/Documentation:
        Enabled: false
  
      Style/RedundantFetchBlock:
        Exclude:
          - config/puma.rb
  
      Style/StringLiterals:
        Enabled: false
  
      Style/SymbolArray:
        Enabled: false
    EOF
  end
  
  after_bundle do
    generate "rspec:install"
    generate "annotate:install"
    run "cp $(i18n-tasks gem-path)/templates/config/i18n-tasks.yml config/"
    run "cp $(i18n-tasks gem-path)/templates/rspec/i18n_spec.rb spec/"
  
    run "docker-compose up -d"
    run "sleep 2"
    rails_command "db:prepare"
  
    git :init
    git add: "."
    git commit: %Q{ -m 'Initial commit' }
  
    run "rubocop -A --only Style/FrozenStringLiteralComment,Layout/EmptyLineAfterMagicComment"
    git add: "."
    git commit: %Q{ -m 'adds missing frozen string literal comment to all files' }
  
    run "rubocop -A --only Rails/RakeEnvironment lib/tasks/auto_annotate_models.rake"
    git add: "."
    git commit: %Q{ -m 'fixes Rails/RakeEnvironment offenses' }
  
    run "rubocop -A --only Style/GlobalStdStream config/environments/production.rb"
    git add: "."
    git commit: %Q{ -m 'fixes Style/GlobalStdStream offenses' }
  
    run "rubocop -a"
    git add: "."
    git commit: %Q{ -m 'autocorrects rubocop offenses' }
  end