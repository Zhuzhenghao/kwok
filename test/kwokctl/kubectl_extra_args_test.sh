#!/usr/bin/env bash
# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DIR="$(dirname "${BASH_SOURCE[0]}")"

DIR="$(realpath "${DIR}")"

RELEASES=()

function usage() {
  echo "Usage: $0 <kube-version...>"
  echo "  <kube-version> is the version of kubernetes to test against."
}

function args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi
  while [[ $# -gt 0 ]]; do
    RELEASES+=("${1}")
    shift
  done
}

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

function test_create_cluster() {
  local release="${1}"
  local name="${2}"

  if version_gt $release "1.17.0"; then
    KWOK_KUBE_VERSION="${release}" kwokctl --config "${DIR}/fake-kwok-config.yaml" -v=-4 create cluster --name "${name}" --timeout 10m --wait 10m --quiet-pull --prometheus-port 9090 --controller-port 10247 --etcd-port=2400 --kube-scheduler-port=10250 --kube-controller-manager-port=10260
  else
    KWOK_KUBE_VERSION="${release}" kwokctl --config "${DIR}/fake-kwok-config-le-1-17.yaml" -v=-4 create cluster --name "${name}" --timeout 10m --wait 10m --quiet-pull --prometheus-port 9090 --controller-port 10247 --etcd-port=2400 --kube-scheduler-port=10250 --kube-controller-manager-port=10260
  fi

  if [[ $? -ne 0 ]]; then
    echo "Error: Cluster ${name} creation failed"
    exit 1
  fi
}

function test_delete_cluster() {
  local release="${1}"
  local name="${2}"
  kwokctl delete cluster --name "${name}"
}

function main() {
  local failed=()
  for release in "${RELEASES[@]}"; do
    echo "------------------------------"
    echo "Testing extra args on ${KWOK_RUNTIME} for ${release}"
    name="extra-args-cluster-${KWOK_RUNTIME}-${release//./-}"
    test_create_cluster "${release}" "${name}" || failed+=("create_cluster_${name}")
    test_delete_cluster "${release}" "${name}" || failed+=("delete_cluster_${name}")
  done

  if [[ "${#failed[@]}" -ne 0 ]]; then
    echo "------------------------------"
    echo "Error: Some tests failed"
    for test in "${failed[@]}"; do
      echo " - ${test}"
    done
    exit 1
  fi
}

args "$@"

main
