; Basic test: llvm.trap translates to OpAbortKHR when SPV_KHR_abort is enabled,
; and round-trips back to llvm.trap + unreachable.

; --- Positive: extension enabled ---
; RUN: llvm-as %s -o %t.bc
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_abort -o %t.spv
; RUN: llvm-spirv %t.spv -to-text -o %t.spt
; RUN: FileCheck < %t.spt %s --check-prefix=CHECK-SPIRV

; Round-trip: SPIR-V binary -> LLVM IR
; RUN: llvm-spirv -r %t.spv -o %t.rev.bc
; RUN: llvm-dis < %t.rev.bc | FileCheck %s --check-prefix=CHECK-LLVM

; --- Negative: extension not enabled ---
; RUN: llvm-spirv %t.bc -spirv-text -o %t.noext.spt
; RUN: FileCheck < %t.noext.spt %s --check-prefix=CHECK-NO-EXT

; Verify SPIR-V without extension is still valid
; RUN: llvm-spirv %t.bc -o %t.noext.spv
; RUN: spirv-val %t.noext.spv

; ---- CHECK-SPIRV: extension, capability, and instruction present ----
; CHECK-SPIRV-DAG: Extension "SPV_KHR_abort"
; CHECK-SPIRV-DAG: Capability AbortKHR
; CHECK-SPIRV: Function
; CHECK-SPIRV: Label
; CHECK-SPIRV: AbortKHR
; CHECK-SPIRV: FunctionEnd

; ---- CHECK-LLVM: round-trip recovers llvm.trap + unreachable ----
; CHECK-LLVM: call void @llvm.trap()
; CHECK-LLVM-NEXT: unreachable

; ---- CHECK-NO-EXT: without extension, no AbortKHR emitted ----
; CHECK-NO-EXT-NOT: AbortKHR

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir64-unknown-unknown"

define spir_func void @trap_simple() {
entry:
  call void @llvm.trap()
  unreachable
}

declare void @llvm.trap() #0

attributes #0 = { cold noreturn nounwind }
