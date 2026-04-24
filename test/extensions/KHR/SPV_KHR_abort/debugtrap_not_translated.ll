; Negative test: llvm.debugtrap and llvm.ubsantrap should NOT produce OpAbortKHR.
; Only llvm.trap is translated to OpAbortKHR. The other trap variants are
; currently dropped (return nullptr). This test ensures they don't accidentally
; trigger the abort path.

; RUN: llvm-as %s -o %t.bc
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_abort -spirv-text -o %t.spt
; RUN: FileCheck < %t.spt %s --check-prefix=CHECK-SPIRV

; ---- debugtrap: no AbortKHR, unreachable still present ----
; CHECK-SPIRV: Function
; CHECK-SPIRV: Label
; CHECK-SPIRV-NOT: AbortKHR
; CHECK-SPIRV: Unreachable
; CHECK-SPIRV: FunctionEnd

; ---- ubsantrap: no AbortKHR, unreachable still present ----
; CHECK-SPIRV: Function
; CHECK-SPIRV: Label
; CHECK-SPIRV-NOT: AbortKHR
; CHECK-SPIRV: Unreachable
; CHECK-SPIRV: FunctionEnd

target datalayout = "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "spir64-unknown-unknown"

define spir_func void @uses_debugtrap() {
entry:
  call void @llvm.debugtrap()
  unreachable
}

define spir_func void @uses_ubsantrap() {
entry:
  call void @llvm.ubsantrap(i8 7)
  unreachable
}

declare void @llvm.debugtrap() #0
declare void @llvm.ubsantrap(i8) #0

attributes #0 = { cold noreturn nounwind }
