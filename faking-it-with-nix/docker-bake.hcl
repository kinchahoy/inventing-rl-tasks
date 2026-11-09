# Image graph for every Nix replica task. BuildKit owns ordering and caching.
# Add a task: create <id>/ (Harbor) and author/tasks/<id>/ (recipe), then list
# it here. Generated inputs live under .cache/tasks/<id>/ (see author/tasks/README.md).
variable "TASKS" {
  default = ["node17-reconstruction-hard", "node23-reconstruction-hard", "node31-reconstruction-hard", "node37-reconstruction-hard", "node41-reconstruction-easy"]
}

target "_shared" {
  context = "author/images"
}

target "base" {
  inherits   = ["_shared"]
  dockerfile = "base.Dockerfile"
  tags       = ["replica-base:v1"]
}

target "toolchain" {
  inherits   = ["_shared"]
  dockerfile = "toolchain.Dockerfile"
  contexts   = { base = "target:base" }
  tags       = ["replica-toolchain:v1"]
}

target "builder" {
  inherits   = ["_shared"]
  dockerfile = "builder.Dockerfile"
  contexts = {
    toolchain = "target:toolchain"
    builder   = "author/builder"
    keys      = ".cache/builder/server"
  }
  tags = ["replica-builder:v1"]
}

target "inputs" {
  name       = "inputs-${id}"
  matrix     = { id = TASKS }
  inherits   = ["_shared"]
  dockerfile = "inputs.Dockerfile"
  contexts = {
    toolchain = "target:toolchain"
    pins      = "author/pins"
    recipe    = "author/tasks/${id}"
  }
  tags = ["${id}-inputs:v1"]
}

# Solving image; Harbor uses it via [environment].docker_image.
target "task" {
  name       = "task-${id}"
  matrix     = { id = TASKS }
  inherits   = ["_shared"]
  dockerfile = "task.Dockerfile"
  contexts = {
    inputs    = "target:inputs-${id}"
    pins      = "author/pins"
    contract  = "author/contract"
    recipe    = "author/tasks/${id}"
    reference = ".cache/tasks/${id}/reference"
    creds     = ".cache/tasks/${id}/creds"
  }
  tags = ["${id}:v1"]
}

# Private verifier: solving image + bundled tests + builder client key.
target "verifier" {
  name       = "verifier-${id}"
  matrix     = { id = TASKS }
  inherits   = ["_shared"]
  dockerfile = "verifier.Dockerfile"
  contexts = {
    task   = "target:task-${id}"
    tests  = "${id}/tests"
    client = ".cache/builder/client"
  }
  tags = ["${id}-verifier:v1"]
}
