container_engine := `command -v podman >/dev/null 2>&1 && echo podman || echo docker`
worktree_name := "ductcalc-" + sha256(justfile_directory())
docker_image := "localhost/" + worktree_name

default:
    @just --list

clean:
    rm -rf .build

install-deps:
    @npm ci

run-css:
    @npm run build:css -- --watch

run: run-docker

build-docker file="docker/Dockerfile" tag="app":
    @{{ container_engine }} build -f {{ quote(file) }} -t {{ docker_image }}:{{ tag }} .

# Rebuild the source image; keep this worktree's compiler cache and SQLite database.
run-docker: _dev-port (build-docker "docker/Dockerfile.test" "dev")
    @just url
    @{{ container_engine }} run --rm --name {{ worktree_name }} \
        -p "127.0.0.1:$(cat .dev-port):8080" \
        -e SQLITE_PATH=/data/db.sqlite \
        -v {{ worktree_name }}-data:/data \
        -v {{ worktree_name }}-build:/app/.build \
        {{ docker_image }}:dev swift run --jobs 4 App serve --env development --hostname 0.0.0.0 --port 8080

stop:
    @{{ container_engine }} stop {{ worktree_name }}

url: _dev-port
    @echo "http://127.0.0.1:$(cat .dev-port)"

_dev-port:
    #!/usr/bin/env python3
    from pathlib import Path
    import socket
    path = Path('.dev-port')
    if path.exists():
        port = int(path.read_text().strip())
        if not 1024 <= port <= 65535:
            raise SystemExit('.dev-port must contain a port between 1024 and 65535')
    else:
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            with path.open('x') as output:
                output.write(str(listener.getsockname()[1]) + '\n')

[positional-arguments]
test-docker *ARGS: (build-docker "docker/Dockerfile.test" "test")
    @{{ container_engine }} run --rm {{ docker_image }}:test swift test --jobs 4 "$@"

code-coverage:
    @llvm-cov report \
        "$(find $(swift build --show-bin-path) -name '*.xctest')" \
        -instr-profile=.build/debug/codecov/default.profdata \
        -ignore-filename-regex=".build|Tests" \
        -use-color

[positional-arguments]
test *ARGS:
    @swift test --enable-code-coverage "$@"

# Run against this worktree's isolated app after starting it with `just run`.
test-accessibility: _dev-port
    @DUCTCALC_A11Y_ORIGIN="http://127.0.0.1:$(cat .dev-port)" npm run test:accessibility
