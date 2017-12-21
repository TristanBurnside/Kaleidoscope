; ModuleID = 'main'
source_filename = "main"

@IntPrintFormat = private unnamed_addr constant [4 x i8] c"%d\0A\00"
@FloatPrintFormat = private unnamed_addr constant [4 x i8] c"%f\0A\00"

define i64 @foo(i64 %x, i64 %y) {
entry:
  %ret = alloca i64
  store i64 10, i64* %ret
  %0 = load i64, i64* %ret
  %1 = add i64 %0, %x
  store i64 %1, i64* %ret
  %2 = load i64, i64* %ret
  %3 = sub i64 %2, %y
  store i64 %3, i64* %ret
  %4 = load i64, i64* %ret
  ret i64 %4
}

define double @bar(double %x, double %y) {
entry:
  %i = alloca double
  %ans = alloca double
  store double 1.000000e+00, double* %ans
  br label %setup

setup:                                            ; preds = %entry
  store double %x, double* %i
  %0 = load double, double* %i
  %1 = fptoui double %0 to i1
  %2 = fptoui double %y to i1
  %3 = fcmp olt double %0, %y
  %4 = icmp ne i1 %3, false
  br i1 %4, label %body, label %cleanup

body:                                             ; preds = %body, %setup
  %5 = load double, double* %ans
  %6 = fmul double %5, 2.000000e+00
  store double %6, double* %ans
  %7 = load double, double* %i
  %8 = fadd double %7, 1.000000e+00
  store double %8, double* %i
  %9 = load double, double* %i
  %10 = fptoui double %9 to i1
  %11 = fptoui double %y to i1
  %12 = fcmp olt double %9, %y
  %13 = icmp ne i1 %12, false
  br i1 %13, label %body, label %cleanup

cleanup:                                          ; preds = %body, %setup
  %14 = load double, double* %ans
  ret double %14
}

define double @ifFunc() {
entry:
  %x = alloca double
  br i1 false, label %then, label %else

then:                                             ; preds = %entry
  store double 4.000000e+01, double* %x
  br label %merge

else:                                             ; preds = %entry
  store double 0.000000e+00, double* %x
  store double 2.000000e+00, double* %x
  br label %merge

merge:                                            ; preds = %else, %then
  %0 = load double, double* %x
  ret double %0
}

define void @main() {
entry:
  %0 = call i64 @foo(i64 0, i64 5)
  %1 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @IntPrintFormat, i32 0, i32 0), i64 %0)
  %2 = call i64 @foo(i64 3, i64 5)
  %3 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @IntPrintFormat, i64 0, i64 0), i64 %2)
  %4 = call i64 @foo(i64 0, i64 0)
  %5 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @IntPrintFormat, i64 0, i64 0), i64 %4)
  %6 = call i64 @foo(i64 1, i64 0)
  %7 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @IntPrintFormat, i64 0, i64 0), i64 %6)
  %8 = call i64 @foo(i64 0, i64 1)
  %9 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @IntPrintFormat, i64 0, i64 0), i64 %8)
  %10 = call double @bar(double 0.000000e+00, double 0.000000e+00)
  %11 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @FloatPrintFormat, i32 0, i32 0), double %10)
  %12 = call double @bar(double 1.000000e+00, double 0.000000e+00)
  %13 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @FloatPrintFormat, i64 0, i64 0), double %12)
  %14 = call double @bar(double 0.000000e+00, double 4.000000e+00)
  %15 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @FloatPrintFormat, i64 0, i64 0), double %14)
  %16 = call double @bar(double 2.300000e+01, double 2.700000e+01)
  %17 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @FloatPrintFormat, i64 0, i64 0), double %16)
  %18 = call double @ifFunc()
  %19 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @FloatPrintFormat, i64 0, i64 0), double %18)
  ret void
}

declare i32 @printf(i8*, ...)
