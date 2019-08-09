#!/usr/bin/env bash

readonly PLATFORM_OS_ANDROID=android
readonly PLATFORM_OS_DARWIN=darwin
readonly PLATFORM_OS_DRAGONFLY=dragonfly
readonly PLATFORM_OS_FREEBSD=freebsd
readonly PLATFORM_OS_LINUX=linux
readonly PLATFORM_OS_NETBSD=netbsd
readonly PLATFORM_OS_OPENBSD=openbsd
readonly PLATFORM_OS_PLAN9=plan9
readonly PLATFORM_OS_SOLARIS=solaris
readonly PLATFORM_OS_WINDOWS=windows
# shellcheck disable=SC2034
readonly PLATFORM_OSES=( "$PLATFORM_OS_ANDROID" "$PLATFORM_OS_DARWIN" "$PLATFORM_OS_DRAGONFLY" "$PLATFORM_OS_FREEBSD" "$PLATFORM_OS_LINUX" "$PLATFORM_OS_NETBSD" "$PLATFORM_OS_OPENBSD" "$PLATFORM_OS_PLAN9" "$PLATFORM_OS_SOLARIS" "$PLATFORM_OS_WINDOWS" )

readonly PLATFORM_ARCH_386=386
readonly PLATFORM_ARCH_AMD64=amd64
readonly PLATFORM_ARCH_ARM=arm
readonly PLATFORM_ARCH_ARM64=arm64
readonly PLATFORM_ARCH_PPC64=ppc64
readonly PLATFORM_ARCH_PPC64LE=ppc64le
readonly PLATFORM_ARCH_MIPS=mips
readonly PLATFORM_ARCH_MIPSLE=mipsle
readonly PLATFORM_ARCH_MIPS64=mips64
readonly PLATFORM_ARCH_MIPS64LE=mips64le
readonly PLATFORM_ARCH_S390X=s390x
# shellcheck disable=SC2034
readonly PLATFORM_ARCHES=( "$PLATFORM_ARCH_386" "$PLATFORM_ARCH_AMD64" "$PLATFORM_ARCH_ARM" "$PLATFORM_ARCH_ARM64" "$PLATFORM_ARCH_PPC64" "$PLATFORM_ARCH_PPC64LE" "$PLATFORM_ARCH_MIPS" "$PLATFORM_ARCH_MIPSLE" "$PLATFORM_ARCH_MIPS64" "$PLATFORM_ARCH_MIPS64LE" "$PLATFORM_ARCH_S390X" )

readonly PLATFORM_VARIANT_V6=v6
readonly PLATFORM_VARIANT_V7=v7
readonly PLATFORM_VARIANT_V8=v8
# shellcheck disable=SC2034
readonly PLATFORM_VARIANTS=( "$PLATFORM_VARIANT_V6" "$PLATFORM_VARIANT_V7" "$PLATFORM_VARIANT_V8" )
