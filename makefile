build:
	hugo -t clarity --minify --config config.toml,config.clarity.toml

serve:
	hugo serve -t clarity --minify --config config.toml,config.clarity.toml -b http://localhost:1313