#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="${1:-}"
if [[ -z "${TARGET_FILE}" ]]; then
  echo "Usage: $0 <kernel-cgroup-source-file>"
  exit 1
fi

if [[ ! -f "${TARGET_FILE}" ]]; then
  echo "Target file not found: ${TARGET_FILE}"
  exit 1
fi

if grep -qE "kernfs_create_link\(cgrp->kn, name, kn\);" "${TARGET_FILE}"; then
  echo "runc patch already present in ${TARGET_FILE}"
  exit 0
fi

if ! grep -qE "^static int cgroup_add_file\(" "${TARGET_FILE}"; then
  echo "cgroup_add_file() not found in ${TARGET_FILE}, skipping"
  exit 0
fi

tmp_file="$(mktemp)"
cleanup() {
  rm -f "${tmp_file}"
}
trap cleanup EXIT

awk '
  BEGIN {
    in_func = 0
    func_body = 0
    brace_depth = 0
    inserted = 0
  }

  /^static int cgroup_add_file\(/ {
    in_func = 1
  }

  {
    if (in_func && func_body && !inserted &&
        $0 ~ /^[[:space:]]*return 0;[[:space:]]*$/ && brace_depth == 1) {
      print "\tif (cft->ss && (cgrp->root->flags & CGRP_ROOT_NOPREFIX) && !(cft->flags & CFTYPE_NO_PREFIX)) {"
      print "\t\tsnprintf(name, CGROUP_FILE_NAME_MAX, \"%s.%s\", cft->ss->name, cft->name);"
      print "\t\tkernfs_create_link(cgrp->kn, name, kn);"
      print "\t}"
      inserted = 1
    }

    print $0

    if (in_func) {
      line = $0
      opens = gsub(/\{/, "{", line)
      line = $0
      closes = gsub(/\}/, "}", line)

      if (!func_body && opens > 0)
        func_body = 1

      if (func_body) {
        brace_depth += opens
        brace_depth -= closes
        if (brace_depth == 0) {
          in_func = 0
          func_body = 0
        }
      }
    }
  }

  END {
    if (!inserted)
      exit 42
  }
' "${TARGET_FILE}" > "${tmp_file}" || {
  rc=$?
  if [[ ${rc} -eq 42 ]]; then
    echo "Expected patch anchor not found in ${TARGET_FILE}, skipping"
    exit 0
  fi
  exit ${rc}
}

mv "${tmp_file}" "${TARGET_FILE}"
echo "runc patch applied: ${TARGET_FILE}"
