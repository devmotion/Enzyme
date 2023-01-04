; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --include-generated-funcs
; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -enzyme-vectorize-at-leaf-nodes -mem2reg -instsimplify -adce -correlated-propagation -simplifycfg -S | FileCheck %s

; Function Attrs: nounwind
declare void @__enzyme_fwddiff(i8*, ...)

; Function Attrs: noinline norecurse nounwind uwtable
define dso_local zeroext i1 @metasubf(double* nocapture %x) local_unnamed_addr #0 {
entry:
  %arrayidx = getelementptr inbounds double, double* %x, i64 1
  store double 3.000000e+00, double* %arrayidx, align 8
  %0 = load double, double* %x, align 8
  %cmp = fcmp fast oeq double %0, 2.000000e+00
  ret i1 %cmp
}

; Function Attrs: noinline norecurse nounwind uwtable
define dso_local zeroext i1 @subf(double* nocapture %x) local_unnamed_addr #0 {
entry:
  %0 = load double, double* %x, align 8
  %mul = fmul fast double %0, %0
  store double %mul, double* %x, align 8
  %call = tail call zeroext i1 @metasubf(double* %x)
  ret i1 %call
}

; Function Attrs: noinline norecurse nounwind uwtable
define dso_local void @f(double* nocapture %x) #0 {
entry:
  %call = tail call zeroext i1 @subf(double* %x)
  store double 2.000000e+00, double* %x, align 8
  ret void
}

; Function Attrs: noinline nounwind uwtable
define dso_local void @dsumsquare(double* %x, <3 x double>* %xp) local_unnamed_addr #1 {
entry:
  tail call void (i8*, ...) @__enzyme_fwddiff(i8* bitcast (void (double*)* @f to i8*), metadata !"enzyme_width", i64 3, double* %x, <3 x double>* %xp)
  ret void
}

attributes #0 = { noinline norecurse nounwind uwtable }
attributes #1 = { noinline nounwind uwtable }


; CHECK: define internal void @fwddiffe3f(double* nocapture %x, <3 x double>* %"x'")
; CHECK-NEXT:  entry:
; CHECK-NEXT:   call void @fwddiffe3subf(double* %x, <3 x double>* %"x'")
; CHECK-NEXT:   store double 2.000000e+00, double* %x, align 8
; CHECK-NEXT:   store <3 x double> zeroinitializer, <3 x double>* %"x'", align 8
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal void @fwddiffe3subf(double* nocapture %x, <3 x double>* %"x'") 
; CHECK-NEXT:  entry:
; CHECK-NEXT:   %"'ipl" = load <3 x double>, <3 x double>* %"x'", align 8
; CHECK-NEXT:   %0 = load double, double* %x, align 8
; CHECK-NEXT:   %mul = fmul fast double %0, %0
; CHECK-NEXT:   %.splatinsert = insertelement <3 x double> poison, double %0, i32 0
; CHECK-NEXT:   %.splat = shufflevector <3 x double> %.splatinsert, <3 x double> poison, <3 x i32> zeroinitializer
; CHECK-NEXT:   %.splatinsert1 = insertelement <3 x double> poison, double %0, i32 0
; CHECK-NEXT:   %.splat2 = shufflevector <3 x double> %.splatinsert1, <3 x double> poison, <3 x i32> zeroinitializer
; CHECK-NEXT:   %1 = fmul fast <3 x double> %"'ipl", %.splat2
; CHECK-NEXT:   %2 = fmul fast <3 x double> %"'ipl", %.splat
; CHECK-NEXT:   %3 = fadd fast <3 x double> %1, %2
; CHECK-NEXT:   store double %mul, double* %x, align 8
; CHECK-NEXT:   store <3 x double> %3, <3 x double>* %"x'", align 8
; CHECK-NEXT:   call void @fwddiffe3metasubf(double* %x, <3 x double>* %"x'")
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal void @fwddiffe3metasubf(double* nocapture %x, <3 x double>* %"x'")
; CHECK-NEXT:  entry:
; CHECK-NEXT:   %"arrayidx'ipg" = getelementptr inbounds <3 x double>, <3 x double>* %"x'", i64 1
; CHECK-NEXT:   %arrayidx = getelementptr inbounds double, double* %x, i64 1
; CHECK-NEXT:   store double 3.000000e+00, double* %arrayidx, align 8
; CHECK-NEXT:   store <3 x double> zeroinitializer, <3 x double>* %"arrayidx'ipg", align 8
; CHECK-NEXT:   ret void
; CHECK-NEXT: }