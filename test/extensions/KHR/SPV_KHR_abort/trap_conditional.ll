; Conditional trap — models the assert() pattern where only some paths trap.
; Verifies that:
;   1. The trap BB gets OpAbortKHR (not OpUnreachable)
;   2. The non-trap BB is unaffected (still has OpReturn)
;   3. No double terminators in the trap block

; RUN: llvm-as %s -o %t.bc
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_abort -o %t.spv
; RUN: llvm-spirv %t.spv -to-text -o %t.spt
; RUN: FileCheck < %t.spt %s --check-prefix=CHECK-SPIRV

; Round-trip
; RUN: llvm-spirv -r %t.spv -o %t.rev.bc
; RUN: llvm-dis < %t.rev.bc | FileCheck %s --check-prefix=CHECK-LLVM

; Without extension: trap dropped, unreachable remains
; RUN: llvm-spirv %t.bc -spirv-text -o %t.noext.spt
; RUN: FileCheck < %t.noext.spt %s --check-prefix=CHECK-NO-EXT

; ---- SPIR-V with extension ----
; CHECK-SPIRV-DAG: Extension "SPV_KHR_abort"
; CHECK-SPIRV-DAG: Capability AbortKHR
; CHECK-SPIRV: Function
;
; Entry block: branch conditional
; CHECK-SPIRV: BranchConditional
;
; OK block: normal return
; CHECK-SPIRV: Return
;
; Trap block: abort only, no Unreachable after it
; CHECK-SPIRV: AbortKHR
; CHECK-SPIRV-NEXT: FunctionEnd

; ---- Round-trip LLVM IR ----
; CHECK-LLVM: define spir_func void @assert_like
; CHECK-LLVM: br i1
; CHECK-LLVM: ret void
; CHECK-LLVM: call void @llvm.trap()
; CHECK-LLVM-NEXT: unreachable

; ---- Without extension: no AbortKHR ----
; CHECK-NO-EXT-NOT: AbortKHR

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir64-unknown-unknown"

define spir_func void @assert_like(i32 %gid, i32 %N) {
entry:
  %cmp = icmp slt i32 %gid, %N
  br i1 %cmp, label %ok, label %trap

ok:
  ret void

trap:
  call void @llvm.trap()
  unreachable
}

declare void @llvm.trap() #0

attributes #0 = { cold noreturn nounwind }
