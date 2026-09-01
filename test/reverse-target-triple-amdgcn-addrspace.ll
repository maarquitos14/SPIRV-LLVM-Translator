; --spirv-target-triple derives the reverse address-space map.

; SPV_INTEL_usm_storage_classes: keeps GlobalDevice/GlobalHost forward, so the
; reverse map is exercised for them.
; RUN: llvm-spirv %s --spirv-ext=+SPV_INTEL_usm_storage_classes -o %t.spv

; amdgcn override: AMDGPU convention.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=amdgcn-amd-amdhsa \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-AMDGCN

; No override: default SPIR numbering.
; RUN: llvm-spirv -r %t.spv \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-DEFAULT

; Untabled (non-AMDGCN) triple: falls through to SPIR identity.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=nvptx64-nvidia-cuda \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-DEFAULT

; Explicit --spirv-addrspace-map wins over triple-derived. 0:5: private alloca ->
; addrspace(5) (verifies); other classes identity.
; RUN: llvm-spirv -r %t.spv --spirv-target-triple=amdgcn-amd-amdhsa \
; RUN:   --spirv-addrspace-map=0:5 \
; RUN:   -o - | llvm-dis | FileCheck %s --check-prefix=CHECK-OVERRIDE

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1"
target triple = "spir64-unknown-unknown"

; Global (1) -> AMDGPU GLOBAL (1); addrspace(1) every case.
; CHECK-AMDGCN: @gv = {{.*}}addrspace(1){{.*}}global i32
; CHECK-DEFAULT: @gv = {{.*}}addrspace(1){{.*}}global i32
; CHECK-OVERRIDE: @gv = {{.*}}addrspace(1){{.*}}global i32
@gv = addrspace(1) global i32 0, align 4

; Global (1), local (3) stable. Generic (4) -> AMDGPU flat (0) under amdgcn;
; stays (4) under default and 0:5.
; CHECK-AMDGCN: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr{{( addrspace\(0\))?}}
; CHECK-DEFAULT: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr addrspace(4)
; CHECK-OVERRIDE: define{{.*}} @test_stable_and_generic({{.*}}ptr addrspace(1){{.*}}ptr addrspace(3){{.*}}ptr addrspace(4)
define spir_kernel void @test_stable_and_generic(ptr addrspace(1) %global_p,
                                                 ptr addrspace(3) %local_p,
                                                 ptr addrspace(4) %generic_p) {
  ret void
}

; Constant (2) -> AMDGPU CONSTANT (4) under amdgcn; stays (2) under default and 0:5.
; CHECK-AMDGCN: define{{.*}} @test_constant({{.*}}ptr addrspace(4)
; CHECK-DEFAULT: define{{.*}} @test_constant({{.*}}ptr addrspace(2)
; CHECK-OVERRIDE: define{{.*}} @test_constant({{.*}}ptr addrspace(2)
define spir_kernel void @test_constant(ptr addrspace(2) %const_p) {
  ret void
}

; Private alloca (0) -> AMDGPU PRIVATE (5) under amdgcn; AS 0 under default;
; addrspace(5) under 0:5.
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

; GlobalDevice (5), GlobalHost (6) -> AMDGPU GLOBAL (1) under amdgcn; stay (5)/(6)
; under default and 0:5 (overrides index 0 only).
; CHECK-AMDGCN: define{{.*}} @test_usm({{.*}}ptr addrspace(1){{.*}}ptr addrspace(1)
; CHECK-DEFAULT: define{{.*}} @test_usm({{.*}}ptr addrspace(5){{.*}}ptr addrspace(6)
; CHECK-OVERRIDE: define{{.*}} @test_usm({{.*}}ptr addrspace(5){{.*}}ptr addrspace(6)
define spir_kernel void @test_usm(ptr addrspace(5) %device_p,
                                  ptr addrspace(6) %host_p) {
  ret void
}
