build:
	hugo -t clarity --minify --config config.toml

serve:
	hugo serve -t clarity --minify --config config.toml -b http://localhost:1313