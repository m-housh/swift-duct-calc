docker_image := "ductcalc"
docker_tag := "latest"

install-deps:
	@curl -sL daisyui.com/fast | bash

run-css:
	@./tailwindcss -i Public/css/main.css -o Public/css/output.css --watch

run:
	@swift run App serve --log debug

build-docker file="docker/Dockerfile":
	@podman build -f {{file}} -t {{docker_image}}:{{docker_tag}} .

run-docker:
	@podman run -it --rm -v $PWD:/app -p 8080:8080 {{docker_image}}:{{docker_tag}}
