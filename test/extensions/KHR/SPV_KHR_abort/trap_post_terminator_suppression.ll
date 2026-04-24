; Edge case: instructions after llvm.trap in the same basic block.
;
; In real code (e.g. device libraries' __assert_fail), the pattern is:
;   call void @llvm.trap()
;   ; ... possibly lifetime.end intrinsics ...
;   ret void            ; or unreachable
;
; OpAbortKHR is a block terminator, so ALL subsequent instructions in the
; same BB must be suppressed to produce valid SPIR-V. This test verifies
; that no instructions appear after OpAbortKHR in any function.

; RUN: llvm-as %s -o %t.bc
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_abort -o %t.spv
; RUN: llvm-spirv %t.spv -to-text -o %t.spt
; RUN: FileCheck < %t.spt %s --check-prefix=CHECK-SPIRV

; Validate SPIR-V is structurally valid
; RUN: spirv-val %t.spv

; Round-trip
; RUN: llvm-spirv -r %t.spv -o %t.rev.bc
; RUN: llvm-dis < %t.rev.bc | FileCheck %s --check-prefix=CHECK-LLVM

; ---- trap followed by unreachable (common pattern) ----
; CHECK-SPIRV: Function
; CHECK-SPIRV: AbortKHR
; CHECK-SPIRV-NEXT: FunctionEnd

; ---- trap followed by ret void (device library pattern) ----
; CHECK-SPIRV: Function
; CHECK-SPIRV: AbortKHR
; CHECK-SPIRV-NEXT: FunctionEnd

; ---- trap followed by lifetime.end + ret void (full device library pattern) ----
; CHECK-SPIRV: Function
; CHECK-SPIRV: AbortKHR
; CHECK-SPIRV-NEXT: FunctionEnd

; ---- Round-trip: all variants recover llvm.trap + unreachable ----
; CHECK-LLVM: define spir_func void @trap_then_unreachable
; CHECK-LLVM: call void @llvm.trap()
; CHECK-LLVM-NEXT: unreachable
;
; CHECK-LLVM: define spir_func void @trap_then_ret
; CHECK-LLVM: call void @llvm.trap()
; CHECK-LLVM-NEXT: unreachable
;
; CHECK-LLVM: define spir_func void @trap_then_lifetime_ret
; CHECK-LLVM: call void @llvm.trap()
; CHECK-LLVM-NEXT: unreachable

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir64-unknown-unknown"

; Pattern 1: trap + unreachable (standard LLVM pattern after noreturn call)
define spir_func void @trap_then_unreachable() {
entry:
  call void @llvm.trap()
  unreachable
}

; Pattern 2: trap + ret void (seen in device library __assert_fail)
define spir_func void @trap_then_ret() {
entry:
  call void @llvm.trap()
  ret void
}

; Pattern 3: trap + lifetime.end + ret void (full device library pattern)
define spir_func void @trap_then_lifetime_ret() {
entry:
  %buf = alloca i8, align 1
  call void @llvm.lifetime.start.p0(i64 1, ptr %buf)
  call void @llvm.trap()
  call void @llvm.lifetime.end.p0(i64 1, ptr %buf)
  ret void
}

declare void @llvm.trap() #0
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #1
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #1

attributes #0 = { cold noreturn nounwind }
attributes #1 = { argmemonly nounwind willreturn }
