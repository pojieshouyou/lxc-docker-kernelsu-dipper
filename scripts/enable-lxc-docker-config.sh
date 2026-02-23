#!/usr/bin/env bash
set -euo pipefail

DEFCONFIG_PATH="${1:-}"
if [[ -z "${DEFCONFIG_PATH}" ]]; then
  echo "Usage: $0 <defconfig-path>"
  exit 1
fi

if [[ ! -f "${DEFCONFIG_PATH}" ]]; then
  echo "Defconfig not found: ${DEFCONFIG_PATH}"
  exit 1
fi

find_kernel_root() {
  local dir
  dir="$(cd "$(dirname "$1")" && pwd)"
  while [[ "${dir}" != "/" ]]; do
    if [[ -f "${dir}/Makefile" && -f "${dir}/Kconfig" ]]; then
      echo "${dir}"
      return 0
    fi
    dir="$(dirname "${dir}")"
  done
  return 1
}

KERNEL_ROOT="$(find_kernel_root "${DEFCONFIG_PATH}" || true)"

# Ensure appends never glue to the previous line when the file lacks a trailing newline.
if [[ -s "${DEFCONFIG_PATH}" ]] && [[ $(tail -c1 "${DEFCONFIG_PATH}" | wc -l) -eq 0 ]]; then
  echo >> "${DEFCONFIG_PATH}"
fi

set_cfg() {
  local key="$1"
  local value="$2"

  sed -i -E "/^${key}=|^# ${key} is not set$/d" "${DEFCONFIG_PATH}"
  if [[ "${value}" == "n" ]]; then
    echo "# ${key} is not set" >> "${DEFCONFIG_PATH}"
  else
    echo "${key}=${value}" >> "${DEFCONFIG_PATH}"
  fi
}

has_kconfig_symbol() {
  local symbol="$1"
  if [[ -z "${KERNEL_ROOT}" ]]; then
    return 1
  fi
  grep -RqsE "^[[:space:]]*config[[:space:]]+${symbol}([[:space:]]|$)" \
    --include='Kconfig*' "${KERNEL_ROOT}"
}

set_cfg_if_symbol_exists() {
  local key="$1"
  local value="$2"
  local symbol="${key#CONFIG_}"
  if has_kconfig_symbol "${symbol}"; then
    set_cfg "${key}" "${value}"
  else
    echo "Skip ${key}: symbol not found in kernel Kconfig"
  fi
}

# Based on the original lxc-docker-config3 baseline.
set_cfg "CONFIG_NAMESPACES" "y"
set_cfg "CONFIG_NET_NS" "y"
set_cfg "CONFIG_PID_NS" "y"
set_cfg "CONFIG_IPC_NS" "y"
set_cfg "CONFIG_UTS_NS" "y"
set_cfg "CONFIG_USER_NS" "y"
set_cfg "CONFIG_POSIX_MQUEUE" "y"
set_cfg "CONFIG_KEYS" "y"
set_cfg "CONFIG_CGROUPS" "y"
set_cfg "CONFIG_CGROUP_CPUACCT" "y"
set_cfg "CONFIG_CGROUP_DEVICE" "y"
set_cfg "CONFIG_CGROUP_FREEZER" "y"
set_cfg "CONFIG_CGROUP_SCHED" "y"
set_cfg "CONFIG_CPUSETS" "y"
set_cfg "CONFIG_MEMCG" "y"
set_cfg "CONFIG_CGROUP_PIDS" "y"
set_cfg "CONFIG_BLK_CGROUP" "y"
set_cfg "CONFIG_BLK_DEV_THROTTLING" "y"
set_cfg "CONFIG_CFS_BANDWIDTH" "y"
set_cfg "CONFIG_SECCOMP" "y"
set_cfg "CONFIG_SECCOMP_FILTER" "y"
set_cfg "CONFIG_SECURITY" "y"
set_cfg "CONFIG_SECURITY_SELINUX" "y"
set_cfg "CONFIG_NET" "y"
set_cfg "CONFIG_INET" "y"
set_cfg "CONFIG_NETFILTER" "y"
set_cfg "CONFIG_NETFILTER_ADVANCED" "y"
set_cfg "CONFIG_NETFILTER_XTABLES" "y"
set_cfg "CONFIG_NF_CONNTRACK" "y"
set_cfg "CONFIG_NF_NAT" "y"
set_cfg "CONFIG_NF_NAT_IPV6" "y"
set_cfg "CONFIG_VETH" "y"
set_cfg "CONFIG_MACVLAN" "y"
set_cfg "CONFIG_IPVLAN" "y"
set_cfg "CONFIG_VXLAN" "y"
set_cfg "CONFIG_VLAN_8021Q" "y"
set_cfg "CONFIG_BRIDGE" "y"
set_cfg "CONFIG_BRIDGE_NETFILTER" "y"
set_cfg "CONFIG_BRIDGE_VLAN_FILTERING" "y"
set_cfg "CONFIG_IP_NF_IPTABLES" "y"
set_cfg "CONFIG_IP_NF_FILTER" "y"
set_cfg "CONFIG_IP_NF_MANGLE" "y"
set_cfg "CONFIG_IP_NF_RAW" "y"
set_cfg "CONFIG_IP_NF_NAT" "y"
set_cfg "CONFIG_IP_NF_TARGET_MASQUERADE" "y"
set_cfg "CONFIG_IP6_NF_FILTER" "y"
set_cfg "CONFIG_IP6_NF_MANGLE" "y"
set_cfg "CONFIG_IP6_NF_RAW" "y"
set_cfg "CONFIG_IP6_NF_NAT" "y"
set_cfg "CONFIG_IP6_NF_TARGET_MASQUERADE" "y"
set_cfg "CONFIG_NF_NAT_IPV4" "y"
set_cfg "CONFIG_NF_CONNTRACK_IPV4" "y"
set_cfg "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE" "y"
set_cfg "CONFIG_NETFILTER_XT_MATCH_COMMENT" "y"
set_cfg "CONFIG_NETFILTER_XT_MATCH_CONNTRACK" "y"
set_cfg "CONFIG_NETFILTER_XT_MATCH_IPVS" "y"
set_cfg "CONFIG_NETFILTER_XT_MARK" "y"
set_cfg "CONFIG_IP_NF_TARGET_REDIRECT" "y"
set_cfg "CONFIG_NETFILTER_XT_TARGET_CHECKSUM" "y"
set_cfg "CONFIG_OVERLAY_FS" "y"
set_cfg "CONFIG_EXT4_FS" "y"
set_cfg "CONFIG_EXT4_FS_POSIX_ACL" "y"
set_cfg "CONFIG_EXT4_FS_SECURITY" "y"
set_cfg "CONFIG_UNIX" "y"
set_cfg "CONFIG_FHANDLE" "y"
set_cfg "CONFIG_CGROUP_BPF" "y"
set_cfg_if_symbol_exists "CONFIG_NF_NAT_NEEDED" "y"

# Recommended configs for broader Docker networking/storage compatibility.
set_cfg "CONFIG_NF_TABLES" "y"
set_cfg "CONFIG_NFT_CT" "y"
set_cfg "CONFIG_NFT_FIB_IPV4" "y"
set_cfg "CONFIG_NFT_FIB_IPV6" "y"
set_cfg "CONFIG_NFT_FIB" "y"
set_cfg "CONFIG_NFT_MASQ" "y"
set_cfg "CONFIG_NFT_NAT" "y"
set_cfg "CONFIG_IP_VS" "y"
set_cfg "CONFIG_IP_VS_NFCT" "y"
set_cfg "CONFIG_IP_VS_PROTO_TCP" "y"
set_cfg "CONFIG_IP_VS_PROTO_UDP" "y"
set_cfg "CONFIG_IP_VS_RR" "y"
set_cfg "CONFIG_CRYPTO" "y"
set_cfg "CONFIG_CRYPTO_AEAD" "y"
set_cfg "CONFIG_CRYPTO_GCM" "y"
set_cfg "CONFIG_CRYPTO_SEQIV" "y"
set_cfg "CONFIG_CRYPTO_GHASH" "y"
set_cfg "CONFIG_XFRM" "y"
set_cfg "CONFIG_XFRM_USER" "y"
set_cfg "CONFIG_XFRM_ALGO" "y"
set_cfg "CONFIG_INET_ESP" "y"
set_cfg "CONFIG_NETFILTER_XT_MATCH_BPF" "y"
set_cfg "CONFIG_NF_NAT_FTP" "y"
set_cfg "CONFIG_NF_CONNTRACK_FTP" "y"
set_cfg "CONFIG_NF_NAT_TFTP" "y"
set_cfg "CONFIG_NF_CONNTRACK_TFTP" "y"

# Additional hard requirements for container user switching.
set_cfg "CONFIG_MULTIUSER" "y"
set_cfg "CONFIG_ANDROID_PARANOID_NETWORK" "n"

echo "LXC/Docker config patch applied to ${DEFCONFIG_PATH}"
