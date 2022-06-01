; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --include-generated-funcs
; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -simplifycfg -early-cse-memssa -instsimplify -correlated-propagation -adce -S | FileCheck %s

%struct.Gradients = type { double, double, double }

; Function Attrs: nounwind
declare %struct.Gradients @__enzyme_fwddiff(i8*, ...)

; TODO optimize this style reduction

; Function Attrs: norecurse nounwind readonly uwtable
define double @alldiv(double* nocapture readonly %A, i64 %N, double %start) {
entry:
  br label %loop

loop:                                                ; preds = %9, %5
  %i = phi i64 [ 0, %entry ], [ %next, %body ]
  %reduce = phi double [ %start, %entry ], [ %div, %body ]
  %cmp = icmp ult i64 %i, %N
  br i1 %cmp, label %body, label %end

body:
  %gep = getelementptr inbounds double, double* %A, i64 %i
  %ld = load double, double* %gep, align 8, !tbaa !2
  %div = fdiv double %reduce, %ld
  %next = add nuw nsw i64 %i, 1
  br label %loop

end:                                                ; preds = %9, %3
  ret double %reduce
}

; Function Attrs: nounwind uwtable
define %struct.Gradients @main(double* %A, double* %dA1, double* %dA2, double* %dA3, i64 %N, double %start) {
  %r = call %struct.Gradients (i8*, ...) @__enzyme_fwddiff(i8* bitcast (double (double*, i64, double)* @alldiv to i8*), metadata !"enzyme_width", i64 3, double* %A, double* %dA1, double* %dA2, double* %dA3, i64 %N, double %start, double 1.0, double 2.0, double 3.0)
  ret %struct.Gradients %r
}

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"Ubuntu clang version 10.0.1-++20200809072545+ef32c611aa2-1~exp1~20200809173142.193"}
!2 = !{!3, !3, i64 0}
!3 = !{!"double", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"any pointer", !4, i64 0}


; CHECK: define {{[^@]+}}@fwddiffe3alldiv(double* nocapture readonly [[A:%.*]], [3 x double*] %"A'", i64 [[N:%.*]], double [[START:%.*]], [3 x double] %"start'") 
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[BODY:%.*]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[TMP0:%.*]] = phi {{(fast )?}}[3 x double] [ %"start'", [[ENTRY]] ], [ [[TMP22:%.*]], [[BODY]] ]
; CHECK-NEXT:    [[REDUCE:%.*]] = phi double [ [[START]], [[ENTRY]] ], [ [[DIV:%.*]], [[BODY]] ]
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[CMP:%.*]] = icmp ne i64 [[IV]], [[N]]
; CHECK-NEXT:    br i1 [[CMP]], label [[BODY]], label [[END:%.*]]
; CHECK:       body:
; CHECK-NEXT:    [[TMP1:%.*]] = extractvalue [3 x double*] %"A'", 0
; CHECK-NEXT:    %"gep'ipg" = getelementptr inbounds double, double* [[TMP1]], i64 [[IV]]
; CHECK-NEXT:    [[TMP2:%.*]] = extractvalue [3 x double*] %"A'", 1
; CHECK-NEXT:    %"gep'ipg1" = getelementptr inbounds double, double* [[TMP2]], i64 [[IV]]
; CHECK-NEXT:    [[TMP3:%.*]] = extractvalue [3 x double*] %"A'", 2
; CHECK-NEXT:    %"gep'ipg2" = getelementptr inbounds double, double* [[TMP3]], i64 [[IV]]
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds double, double* [[A]], i64 [[IV]]
; CHECK-NEXT:    %"ld'ipl" = load double, double* %"gep'ipg", align 8, !tbaa !2
; CHECK-NEXT:    %"ld'ipl3" = load double, double* %"gep'ipg1", align 8, !tbaa !2
; CHECK-NEXT:    %"ld'ipl4" = load double, double* %"gep'ipg2", align 8, !tbaa !2
; CHECK-NEXT:    [[LD:%.*]] = load double, double* [[GEP]], align 8, !tbaa !2
; CHECK-NEXT:    [[DIV]] = fdiv double [[REDUCE]], [[LD]]
; CHECK-NEXT:    [[TMP4:%.*]] = extractvalue [3 x double] [[TMP0]], 0
; CHECK-NEXT:    [[TMP5:%.*]] = fmul fast double [[TMP4]], [[LD]]
; CHECK-NEXT:    [[TMP6:%.*]] = fmul fast double [[REDUCE]], %"ld'ipl"
; CHECK-NEXT:    [[TMP7:%.*]] = fsub fast double [[TMP5]], [[TMP6]]
; CHECK-NEXT:    [[TMP8:%.*]] = extractvalue [3 x double] [[TMP0]], 1
; CHECK-NEXT:    [[TMP9:%.*]] = fmul fast double [[TMP8]], [[LD]]
; CHECK-NEXT:    [[TMP10:%.*]] = fmul fast double [[REDUCE]], %"ld'ipl3"
; CHECK-NEXT:    [[TMP11:%.*]] = fsub fast double [[TMP9]], [[TMP10]]
; CHECK-NEXT:    [[TMP12:%.*]] = extractvalue [3 x double] [[TMP0]], 2
; CHECK-NEXT:    [[TMP13:%.*]] = fmul fast double [[TMP12]], [[LD]]
; CHECK-NEXT:    [[TMP14:%.*]] = fmul fast double [[REDUCE]], %"ld'ipl4"
; CHECK-NEXT:    [[TMP15:%.*]] = fsub fast double [[TMP13]], [[TMP14]]
; CHECK-NEXT:    [[TMP16:%.*]] = fmul fast double [[LD]], [[LD]]
; CHECK-NEXT:    [[TMP17:%.*]] = fdiv fast double [[TMP7]], [[TMP16]]
; CHECK-NEXT:    [[TMP18:%.*]] = insertvalue [3 x double] undef, double [[TMP17]], 0
; CHECK-NEXT:    [[TMP19:%.*]] = fdiv fast double [[TMP11]], [[TMP16]]
; CHECK-NEXT:    [[TMP20:%.*]] = insertvalue [3 x double] [[TMP18]], double [[TMP19]], 1
; CHECK-NEXT:    [[TMP21:%.*]] = fdiv fast double [[TMP15]], [[TMP16]]
; CHECK-NEXT:    [[TMP22]] = insertvalue [3 x double] [[TMP20]], double [[TMP21]], 2
; CHECK-NEXT:    br label [[LOOP]]
; CHECK:       end:
; CHECK-NEXT:    ret [3 x double] [[TMP0]]
;