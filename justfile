docker_image := "manuald"

build-docker:
	@podman build -f docker/Dockerfile.dev -t {{docker_image}}:dev .

run-dev:
	@podman run -it --rm -v $PWD:/app -p 3000:3000 -p 3002:3002 -p 8080:8080 {{docker_image}}:dev ./swift-dev
