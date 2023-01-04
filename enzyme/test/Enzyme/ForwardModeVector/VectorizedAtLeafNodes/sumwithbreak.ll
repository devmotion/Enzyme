; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --include-generated-funcs
; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -enzyme-vectorize-at-leaf-nodes -mem2reg -instcombine -correlated-propagation -adce -instcombine -simplifycfg -early-cse -simplifycfg -loop-unroll -instcombine -simplifycfg -gvn -jump-threading -instcombine -simplifycfg -S | FileCheck %s

; Function Attrs: nounwind
declare <3 x double> @__enzyme_fwddiff(i8*, ...)

; Function Attrs: noinline nounwind uwtable
define dso_local double @f(double* nocapture readonly %x, i64 %n) #0 {
entry:
  br label %for.body

for.body:                                         ; preds = %if.end, %entry
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %if.end ]
  %data.016 = phi double [ 0.000000e+00, %entry ], [ %add5, %if.end ]
  %cmp2 = fcmp fast ogt double %data.016, 1.000000e+01
  br i1 %cmp2, label %if.then, label %if.end

if.then:                                          ; preds = %for.body
  %arrayidx = getelementptr inbounds double, double* %x, i64 %n
  %0 = load double, double* %arrayidx, align 8
  %add = fadd fast double %0, %data.016
  br label %cleanup

if.end:                                           ; preds = %for.body
  %arrayidx4 = getelementptr inbounds double, double* %x, i64 %indvars.iv
  %1 = load double, double* %arrayidx4, align 8
  %add5 = fadd fast double %1, %data.016
  %indvars.iv.next = add nuw i64 %indvars.iv, 1
  %cmp = icmp ult i64 %indvars.iv, %n
  br i1 %cmp, label %for.body, label %cleanup

cleanup:                                          ; preds = %if.end, %if.then
  %data.1 = phi double [ %add, %if.then ], [ %add5, %if.end ]
  ret double %data.1
}

; Function Attrs: noinline nounwind uwtable
define dso_local <3 x double> @dsumsquare(double* %x, <3 x double>* %xp, i64 %n) #0 {
entry:
  %call = call <3 x double> (i8*, ...) @__enzyme_fwddiff(i8* bitcast (double (double*, i64)* @f to i8*), metadata !"enzyme_width", i64 3, double* %x, <3 x double>* %xp, i64 %n)
  ret <3 x double> %call
}

attributes #0 = { noinline nounwind uwtable }


; CHECK: define internal <3 x double> @fwddiffe3f(double* nocapture readonly %x, <3 x double>* %"x'", i64 %n)
; CHECK-NEXT: entry:
; CHECK-NEXT:   br label %for.body

; CHECK: for.body:                                         ; preds = %if.end, %entry
; CHECK-NEXT:   %iv = phi i64 [ %iv.next, %if.end ], [ 0, %entry ]
; CHECK-NEXT:   %0 = phi fast double [ %12, %if.end ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %1 = phi fast double [ %13, %if.end ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %2 = phi fast double [ %14, %if.end ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %data.016 = phi double [ %add5, %if.end ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %3 = insertelement <3 x double> undef, double %0, i32 0
; CHECK-NEXT:   %4 = insertelement <3 x double> %3, double %1, i32 1
; CHECK-NEXT:   %5 = insertelement <3 x double> %4, double %2, i32 2
; CHECK-NEXT:   %cmp2 = fcmp fast ogt double %data.016, 1.000000e+01
; CHECK-NEXT:   br i1 %cmp2, label %if.then, label %if.end

; CHECK: if.then:                                          ; preds = %for.body
; CHECK-NEXT:   %"arrayidx'ipg" = getelementptr inbounds <3 x double>, <3 x double>* %"x'", i64 %n
; CHECK-NEXT:   %"'ipl" = load <3 x double>, <3 x double>* %"arrayidx'ipg", align 8
; CHECK-NEXT:   %6 = fadd fast <3 x double> %"'ipl", %5
; CHECK-NEXT:   %7 = extractelement <3 x double> %6, i64 0
; CHECK-NEXT:   %8 = extractelement <3 x double> %6, i64 1
; CHECK-NEXT:   %9 = extractelement <3 x double> %6, i64 2
; CHECK-NEXT:   br label %cleanup

; CHECK: if.end:                                           ; preds = %for.body
; CHECK-NEXT:   %iv.next = add nuw nsw i64 %iv, 1
; CHECK-NEXT:   %"arrayidx4'ipg" = getelementptr inbounds <3 x double>, <3 x double>* %"x'", i64 %iv
; CHECK-NEXT:   %arrayidx4 = getelementptr inbounds double, double* %x, i64 %iv
; CHECK-NEXT:   %"'ipl2" = load <3 x double>, <3 x double>* %"arrayidx4'ipg", align 8
; CHECK-NEXT:   %10 = load double, double* %arrayidx4, align 8
; CHECK-NEXT:   %add5 = fadd fast double %10, %data.016
; CHECK-NEXT:   %11 = fadd fast <3 x double> %"'ipl2", %5
; CHECK-NEXT:   %cmp = icmp ult i64 %iv, %n
; CHECK-NEXT:   %12 = extractelement <3 x double> %11, i64 0
; CHECK-NEXT:   %13 = extractelement <3 x double> %11, i64 1
; CHECK-NEXT:   %14 = extractelement <3 x double> %11, i64 2
; CHECK-NEXT:   br i1 %cmp, label %for.body, label %cleanup

; CHECK: cleanup:                                          ; preds = %if.end, %if.then
; CHECK-NEXT:   %15 = phi fast double [ %7, %if.then ], [ %12, %if.end ]
; CHECK-NEXT:   %16 = phi fast double [ %8, %if.then ], [ %13, %if.end ]
; CHECK-NEXT:   %17 = phi fast double [ %9, %if.then ], [ %14, %if.end ]
; CHECK-NEXT:   %18 = insertelement <3 x double> undef, double %15, i32 0
; CHECK-NEXT:   %19 = insertelement <3 x double> %18, double %16, i32 1
; CHECK-NEXT:   %20 = insertelement <3 x double> %19, double %17, i32 2
; CHECK-NEXT:   ret <3 x double> %20
; CHECK-NEXT: }