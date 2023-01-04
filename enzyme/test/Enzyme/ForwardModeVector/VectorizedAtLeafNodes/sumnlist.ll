; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --include-generated-funcs
; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -enzyme-vectorize-at-leaf-nodes -mem2reg -gvn -early-cse-memssa -instcombine -instsimplify -simplifycfg -adce -licm -correlated-propagation -instcombine -correlated-propagation -adce -instsimplify -correlated-propagation -jump-threading -instsimplify -early-cse -simplifycfg -S | FileCheck %s

; #include <stdlib.h>
; #include <stdio.h>
; struct n {
;     double *values;
;     struct n *next;
; };
; __attribute__((noinline))
; double sum_list(const struct n *__restrict node, unsigned long times) {
;     double sum = 0;
;     for(const struct n *val = node; val != 0; val = val->next) {
;         for(int i=0; i<=times; i++) {
;             sum += val->values[i];
;         }
;     }
;     return sum;
; }

%struct.n = type { double*, %struct.n* }
%struct.n.vec = type { <3 x double>*, %struct.n.vec* }

; Function Attrs: noinline norecurse nounwind readonly uwtable
define dso_local double @sum_list(%struct.n* noalias readonly %node, i64 %times) local_unnamed_addr #0 {
entry:
  %cmp18 = icmp eq %struct.n* %node, null
  br i1 %cmp18, label %for.cond.cleanup, label %for.cond1.preheader

for.cond1.preheader:                              ; preds = %for.cond.cleanup4, %entry
  %val.020 = phi %struct.n* [ %1, %for.cond.cleanup4 ], [ %node, %entry ]
  %sum.019 = phi double [ %add, %for.cond.cleanup4 ], [ 0.000000e+00, %entry ]
  %values = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 0
  %0 = load double*, double** %values, align 8, !tbaa !2
  br label %for.body5

for.cond.cleanup:                                 ; preds = %for.cond.cleanup4, %entry
  %sum.0.lcssa = phi double [ 0.000000e+00, %entry ], [ %add, %for.cond.cleanup4 ]
  ret double %sum.0.lcssa

for.cond.cleanup4:                                ; preds = %for.body5
  %next = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 1
  %1 = load %struct.n*, %struct.n** %next, align 8, !tbaa !7
  %cmp = icmp eq %struct.n* %1, null
  br i1 %cmp, label %for.cond.cleanup, label %for.cond1.preheader

for.body5:                                        ; preds = %for.body5, %for.cond1.preheader
  %indvars.iv = phi i64 [ 0, %for.cond1.preheader ], [ %indvars.iv.next, %for.body5 ]
  %sum.116 = phi double [ %sum.019, %for.cond1.preheader ], [ %add, %for.body5 ]
  %arrayidx = getelementptr inbounds double, double* %0, i64 %indvars.iv
  %2 = load double, double* %arrayidx, align 8, !tbaa !8
  %add = fadd fast double %2, %sum.116
  %indvars.iv.next = add nuw i64 %indvars.iv, 1
  %exitcond = icmp eq i64 %indvars.iv, %times
  br i1 %exitcond, label %for.cond.cleanup4, label %for.body5
}

; Function Attrs: nounwind
declare dso_local noalias i8* @malloc(i64) local_unnamed_addr #2

; Function Attrs: noinline nounwind uwtable
define dso_local <3 x double> @derivative(%struct.n* %x, %struct.n.vec* %xp, i64 %n) {
entry:
  %0 = tail call <3 x double> (double (%struct.n*, i64)*, ...) @__enzyme_fwddiff(double (%struct.n*, i64)* nonnull @sum_list, metadata !"enzyme_width", i64 3, %struct.n* %x, %struct.n.vec* %xp, i64 %n)
  ret <3 x double> %0
}

; Function Attrs: nounwind
declare <3 x double> @__enzyme_fwddiff(double (%struct.n*, i64)*, ...) #4


attributes #0 = { noinline norecurse nounwind readonly uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #1 = { nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #2 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #3 = { noinline nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #4 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.1.0 "}
!2 = !{!3, !4, i64 0}
!3 = !{!"n", !4, i64 0, !4, i64 8}
!4 = !{!"any pointer", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!3, !4, i64 8}
!8 = !{!9, !9, i64 0}
!9 = !{!"double", !5, i64 0}
!10 = !{!4, !4, i64 0}


; CHECK: define internal <3 x double> @fwddiffe3sum_list(%struct.n* noalias readonly %node, %struct.n.vec* %"node'", i64 %times)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %cmp18 = icmp eq %struct.n* %node, null
; CHECK-NEXT:   br i1 %cmp18, label %for.cond.cleanup, label %for.cond1.preheader

; CHECK: for.cond1.preheader:                              ; preds = %entry, %for.cond.cleanup4
; CHECK-NEXT:   %0 = phi fast double [ %18, %for.cond.cleanup4 ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %1 = phi fast double [ %19, %for.cond.cleanup4 ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %2 = phi fast double [ %20, %for.cond.cleanup4 ], [ 0.000000e+00, %entry ]
; CHECK-NEXT:   %3 = phi %struct.n.vec* [ %"'ipl3", %for.cond.cleanup4 ], [ %"node'", %entry ]
; CHECK-NEXT:   %val.020 = phi %struct.n* [ %10, %for.cond.cleanup4 ], [ %node, %entry ]
; CHECK-NEXT:   %"values'ipg" = getelementptr inbounds %struct.n.vec, %struct.n.vec* %3, i64 0, i32 0
; CHECK-NEXT:   %"'ipl" = load <3 x double>*, <3 x double>** %"values'ipg", align 8, !tbaa !2
; CHECK-NEXT:   br label %for.body5

; CHECK: for.cond.cleanup:                                 ; preds = %for.cond.cleanup4, %entry
; CHECK-NEXT:   %4 = phi fast double [ 0.000000e+00, %entry ], [ %18, %for.cond.cleanup4 ]
; CHECK-NEXT:   %5 = phi fast double [ 0.000000e+00, %entry ], [ %19, %for.cond.cleanup4 ]
; CHECK-NEXT:   %6 = phi fast double [ 0.000000e+00, %entry ], [ %20, %for.cond.cleanup4 ]
; CHECK-NEXT:   %7 = insertelement <3 x double> undef, double %4, i32 0
; CHECK-NEXT:   %8 = insertelement <3 x double> %7, double %5, i32 1
; CHECK-NEXT:   %9 = insertelement <3 x double> %8, double %6, i32 2
; CHECK-NEXT:   ret <3 x double> %9

; CHECK: for.cond.cleanup4:                                ; preds = %for.body5
; CHECK-NEXT:   %"next'ipg" = getelementptr inbounds %struct.n.vec, %struct.n.vec* %3, i64 0, i32 1
; CHECK-NEXT:   %next = getelementptr inbounds %struct.n, %struct.n* %val.020, i64 0, i32 1
; CHECK-NEXT:   %"'ipl3" = load %struct.n.vec*, %struct.n.vec** %"next'ipg", align 8, !tbaa !7
; CHECK-NEXT:   %10 = load %struct.n*, %struct.n** %next, align 8, !tbaa !7
; CHECK-NEXT:   %cmp = icmp eq %struct.n* %10, null
; CHECK-NEXT:   br i1 %cmp, label %for.cond.cleanup, label %for.cond1.preheader

; CHECK: for.body5:                                        ; preds = %for.body5, %for.cond1.preheader
; CHECK-NEXT:   %11 = phi fast double [ %0, %for.cond1.preheader ], [ %18, %for.body5 ]
; CHECK-NEXT:   %12 = phi fast double [ %1, %for.cond1.preheader ], [ %19, %for.body5 ]
; CHECK-NEXT:   %13 = phi fast double [ %2, %for.cond1.preheader ], [ %20, %for.body5 ]
; CHECK-NEXT:   %iv1 = phi i64 [ 0, %for.cond1.preheader ], [ %iv.next2, %for.body5 ]
; CHECK-NEXT:   %14 = insertelement <3 x double> undef, double %11, i32 0
; CHECK-NEXT:   %15 = insertelement <3 x double> %14, double %12, i32 1
; CHECK-NEXT:   %16 = insertelement <3 x double> %15, double %13, i32 2
; CHECK-NEXT:   %iv.next2 = add nuw nsw i64 %iv1, 1
; CHECK-NEXT:   %"arrayidx'ipg" = getelementptr inbounds <3 x double>, <3 x double>* %"'ipl", i64 %iv1
; CHECK-NEXT:   %"'ipl4" = load <3 x double>, <3 x double>* %"arrayidx'ipg", align 8, !tbaa !8
; CHECK-NEXT:   %17 = fadd fast <3 x double> %"'ipl4", %16
; CHECK-NEXT:   %exitcond = icmp eq i64 %iv1, %times
; CHECK-NEXT:   %18 = extractelement <3 x double> %17, i64 0
; CHECK-NEXT:   %19 = extractelement <3 x double> %17, i64 1
; CHECK-NEXT:   %20 = extractelement <3 x double> %17, i64 2
; CHECK-NEXT:   br i1 %exitcond, label %for.cond.cleanup4, label %for.body5
; CHECK-NEXT: }