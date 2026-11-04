#
# SPDX-FileCopyrightText: 2024-2026 Franco Masotti (See /README.md)
#
# SPDX-License-Identifier: MIT

# Change these two. Required.
PROJECT_NAME := basic-repo-template
PYTHON_MODULE_NAME := basic_repo_template

# Required
MAKEFILE_SOURCE := https://raw.githubusercontent.com/frnmst/python-makefile/refs/heads/master/Makefile.linux.example
DOCKER_BUILD_PYTHON_DIST_SOURCE := https://raw.githubusercontent.com/frnmst/python-makefile/refs/heads/master/Dockerfile.python3.13_hatchling.build.example
bootstrap:
	curl -o Makefile $(MAKEFILE_SOURCE)
	curl -o .dockerfile_build_python_dist $(DOCKER_BUILD_PYTHON_DIST_SOURCE)

# Add extra targets here. Optional.
example-target:
	@echo "This is an example target"

# Override targets in the Makefile. Optional.
OVERRIDE_CLEAN := true
clean::
	rm -rf .build/
