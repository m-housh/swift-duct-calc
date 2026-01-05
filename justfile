docker_image := "manuald"

install-deps:
	@curl -sL daisyui.com/fast | bash

run-css:
	@./tailwindcss -i Public/css/main.css -o Public/css/output.css --watch

run:
	@swift run App serve --log debug

build-docker:
	@podman build -f docker/Dockerfile.dev -t {{docker_image}}:dev .

run-dev:
	@podman run -it --rm -v $PWD:/app -p 8080:8080 {{docker_image}}:dev
