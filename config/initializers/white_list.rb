Rails::Html::WhiteListSanitizer.allowed_tags += %w[table thead tbody tr th td caption tfoot]
Rails::Html::WhiteListSanitizer.allowed_attributes += %w[rel target]
