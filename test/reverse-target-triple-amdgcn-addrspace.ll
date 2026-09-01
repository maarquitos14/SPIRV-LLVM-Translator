; Test that --spirv-target-triple derives the address-space map from the target
; triple during reverse-translation.

; RUN: llvm-as < %s -o %t.bc
; SPV_INTEL_usm_storage_classes preserves the GlobalDevice/GlobalHost storage
; classes through forward translation so the reverse map is exercised for them.
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_INTEL_usm_storage_classes -o %t.spv

; Positive: AMDGCN override remaps to the AMDGPU convention.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=amdgcn-amd-amdhsa \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-AMDGCN

; Negative / control: no override keeps the default SPIR numbering.
; RUN: llvm-spirv -r %t.spv \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-DEFAULT

; Negative: an untabled (non-AMDGCN) triple falls through to identity/SPIR.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=nvptx64-nvidia-cuda \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-DEFAULT

; Interaction: an explicit --spirv-addrspace-map wins over the triple-derived
; map. 0:5 keeps the private alloca in the AMDGPU-required addrspace(5) (so the
; module still verifies), while leaving the other classes at their identity
; numbering.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=amdgcn-amd-amdhsa \
; RUN:   --spirv-addrspace-map=0:5 \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-OVERRIDE

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1"
target triple = "spir64-unknown-unknown"

; Global variable: SPIRAS_Global (1). Maps to AMDGPU GLOBAL_ADDRESS (1) too, so
; addrspace(1) in every case.
; CHECK-AMDGCN: @gv = {{.*}}addrspace(1){{.*}}global i32
; CHECK-DEFAULT: @gv = {{.*}}addrspace(1){{.*}}global i32
; CHECK-OVERRIDE: @gv = {{.*}}addrspace(1){{.*}}global i32
@gv = addrspace(1) global i32 0, align 4

; Global (1) stays 1; local (3) stays 3; generic (4) -> AMDGPU flat (0) under the
; AMDGCN map, but stays addrspace(4) under the SPIR/identity default and the
; explicit 0:4 map.
; CHECK-AMDGCN: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr{{( addrspace\(0\))?}}
; CHECK-DEFAULT: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr addrspace(4)
; CHECK-OVERRIDE: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr addrspace(4)
define spir_kernel void @test_stable_and_generic(ptr addrspace(1) %global_p,
                                                 ptr addrspace(3) %local_p,
                                                 ptr addrspace(4) %generic_p) {
  ret void
}

; Constant (2) -> AMDGPU CONSTANT_ADDRESS (4) under the AMDGCN map; stays
; addrspace(2) under the SPIR/identity default and the explicit 0:4 map.
; CHECK-AMDGCN: define{{.*}} @test_constant({{.*}}ptr addrspace(4)
; CHECK-DEFAULT: define{{.*}} @test_constant({{.*}}ptr addrspace(2)
; CHECK-OVERRIDE: define{{.*}} @test_constant({{.*}}ptr addrspace(2)
define spir_kernel void @test_constant(ptr addrspace(2) %const_p) {
  ret void
}

; Private alloca: SPIRAS_Private (0). AMDGPU PRIVATE_ADDRESS (5) under the AMDGCN
; map; AS 0 under the default; addrspace(5) under the explicit 0:5 map.
; CHECK-AMDGCN: define{{.*}} @test_private(
; CHECK-AMDGCN: alloca i32,{{.*}} addrspace(5)
; CHECK-DEFAULT: define{{.*}} @test_private(
; CHECK-DEFAULT: alloca i32, align
; CHECK-OVERRIDE: define{{.*}} @test_private(
; CHECK-OVERRIDE: alloca i32,{{.*}} addrspace(5)
define spir_func i32 @test_private() {
  %x = alloca i32
  %v = load i32, ptr %x
  ret i32 %v
}

; GlobalDevice (5) and GlobalHost (6) both -> AMDGPU GLOBAL_ADDRESS (1) under the
; AMDGCN map; they stay at their identity numbering (5 and 6) under the default
; and the explicit 0:5 map (which only overrides index 0).
; CHECK-AMDGCN: define{{.*}} @test_usm({{.*}}ptr addrspace(1){{.*}}ptr addrspace(1)
; CHECK-DEFAULT: define{{.*}} @test_usm({{.*}}ptr addrspace(5){{.*}}ptr addrspace(6)
; CHECK-OVERRIDE: define{{.*}} @test_usm({{.*}}ptr addrspace(5){{.*}}ptr addrspace(6)
define spir_kernel void @test_usm(ptr addrspace(5) %device_p,
                                  ptr addrspace(6) %host_p) {
  ret void
}
