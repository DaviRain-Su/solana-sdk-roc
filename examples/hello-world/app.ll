; ModuleID = 'app'
source_filename = "builtins-host"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-musl"

%str.RocStr = type { ptr, i64, i64 }

@__stack_chk_guard = weak_odr dso_local global i64 -69242844270821376, align 8
@0 = private unnamed_addr constant [2 x i64] zeroinitializer, align 8
@_str_literal_13276749449650780488 = private unnamed_addr constant [33 x i8] c"\00\00\00\00\00\00\00\00Hello from Roc on Solana!", align 8

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #0

; Function Attrs: nounwind uwtable
define weak_odr dso_local i128 @__divti3(i128 %0, i128 %1) #1 {
  %3 = zext i7 -1 to i128
  %4 = ashr i128 %0, %3
  %5 = zext i7 -1 to i128
  %6 = ashr i128 %1, %5
  %7 = xor i128 %0, %4
  %8 = sub i128 %7, %4
  %9 = xor i128 %1, %6
  %10 = sub i128 %9, %6
  %11 = call fastcc i128 @compiler_rt.udivmod.udivmod__anon_4855(i128 %8, i128 %10, ptr align 16 null)
  %12 = xor i128 %4, %6
  %13 = xor i128 %11, %12
  %14 = sub i128 %13, %12
  ret i128 %14
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #2

; Function Attrs: nounwind uwtable
define private fastcc i128 @compiler_rt.udivmod.udivmod__anon_4855(i128 %0, i128 %1, ptr align 16 %2) unnamed_addr #1 {
  %4 = alloca [8 x i8], align 8
  %5 = alloca [16 x i8], align 16
  %6 = alloca [16 x i8], align 16
  %7 = alloca [16 x i8], align 8
  %8 = alloca [16 x i8], align 8
  %9 = alloca [16 x i8], align 16
  %10 = alloca [16 x i8], align 16
  %11 = icmp ugt i128 %1, %0
  br i1 %11, label %16, label %18

12:                                               ; preds = %18
  store i128 %0, ptr %10, align 16
  store i128 %1, ptr %9, align 16
  call void @llvm.memset.p0.i64(ptr align 8 %8, i8 undef, i64 16, i1 false)
  call void @llvm.memset.p0.i64(ptr align 8 %7, i8 undef, i64 16, i1 false)
  %13 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 1
  %14 = load i64, ptr %13, align 8
  %15 = icmp eq i64 %14, 0
  br i1 %15, label %38, label %45

16:                                               ; preds = %3
  %17 = icmp ne ptr %2, null
  br i1 %17, label %20, label %21

18:                                               ; preds = %3
  br label %12

19:                                               ; preds = %21, %20
  ret i128 0

20:                                               ; preds = %16
  store i128 %0, ptr %2, align 16
  br label %19

21:                                               ; preds = %16
  br label %19

22:                                               ; preds = %45
  %23 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 1
  %24 = load i64, ptr %23, align 8
  %25 = call i64 @llvm.ctlz.i64(i64 %24, i1 false)
  %26 = trunc i64 %25 to i7
  %27 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 1
  %28 = load i64, ptr %27, align 8
  %29 = call i64 @llvm.ctlz.i64(i64 %28, i1 false)
  %30 = trunc i64 %29 to i7
  %31 = sub nuw i7 %26, %30
  %32 = load i128, ptr %10, align 8
  store i128 %32, ptr %6, align 16
  %33 = load i128, ptr %9, align 8
  %34 = zext i7 %31 to i128
  %35 = shl i128 %33, %34
  store i128 %35, ptr %5, align 16
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %8, ptr align 8 @0, i64 16, i1 false)
  store i64 0, ptr %4, align 8
  %36 = add nuw i7 %31, 1
  %37 = zext i7 %36 to i64
  br label %85

38:                                               ; preds = %12
  %39 = getelementptr inbounds [2 x i64], ptr %7, i64 0, i64 1
  store i64 0, ptr %39, align 8
  %40 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 1
  %41 = load i64, ptr %40, align 8
  %42 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 0
  %43 = load i64, ptr %42, align 8
  %44 = icmp ult i64 %41, %43
  br i1 %44, label %48, label %59

45:                                               ; preds = %12
  br label %22

46:                                               ; preds = %59, %48
  %47 = icmp ne ptr %2, null
  br i1 %47, label %80, label %82

48:                                               ; preds = %38
  %49 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 1
  store i64 0, ptr %49, align 8
  %50 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 0
  %51 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 1
  %52 = load i64, ptr %51, align 8
  %53 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 0
  %54 = load i64, ptr %53, align 8
  %55 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 0
  %56 = load i64, ptr %55, align 8
  %57 = getelementptr inbounds [2 x i64], ptr %7, i64 0, i64 0
  %58 = call fastcc i64 @compiler_rt.udivmod.divwide__anon_7772(i64 %52, i64 %54, i64 %56, ptr nonnull align 8 %57)
  store i64 %58, ptr %50, align 8
  br label %46

59:                                               ; preds = %38
  %60 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 1
  %61 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 1
  %62 = load i64, ptr %61, align 8
  %63 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 0
  %64 = load i64, ptr %63, align 8
  %65 = udiv i64 %62, %64
  store i64 %65, ptr %60, align 8
  %66 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 0
  %67 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 1
  %68 = load i64, ptr %67, align 8
  %69 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 0
  %70 = load i64, ptr %69, align 8
  %71 = urem i64 %68, %70
  %72 = getelementptr inbounds [2 x i64], ptr %10, i64 0, i64 0
  %73 = load i64, ptr %72, align 8
  %74 = getelementptr inbounds [2 x i64], ptr %9, i64 0, i64 0
  %75 = load i64, ptr %74, align 8
  %76 = getelementptr inbounds [2 x i64], ptr %7, i64 0, i64 0
  %77 = call fastcc i64 @compiler_rt.udivmod.divwide__anon_7772(i64 %71, i64 %73, i64 %75, ptr nonnull align 8 %76)
  store i64 %77, ptr %66, align 8
  br label %46

78:                                               ; preds = %82, %80
  %79 = load i128, ptr %8, align 8
  ret i128 %79

80:                                               ; preds = %46
  %81 = load i128, ptr %7, align 8
  store i128 %81, ptr %2, align 16
  br label %78

82:                                               ; preds = %46
  br label %78

83:                                               ; preds = %113
  %84 = icmp ne ptr %2, null
  br i1 %84, label %116, label %118

85:                                               ; preds = %88, %22
  %86 = load i64, ptr %4, align 8
  %87 = icmp ult i64 %86, %37
  br i1 %87, label %90, label %113

88:                                               ; preds = %90
  %89 = add nuw i64 %86, 1
  store i64 %89, ptr %4, align 8
  br label %85

90:                                               ; preds = %85
  %91 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 0
  %92 = load i64, ptr %91, align 8
  %93 = zext i6 1 to i64
  %94 = shl i64 %92, %93
  store i64 %94, ptr %91, align 8
  %95 = load i128, ptr %5, align 16
  %96 = load i128, ptr %6, align 16
  %97 = sub i128 %95, %96
  %98 = sub i128 %97, 1
  %99 = zext i7 -1 to i128
  %100 = ashr i128 %98, %99
  %101 = getelementptr inbounds [2 x i64], ptr %8, i64 0, i64 0
  %102 = load i64, ptr %101, align 8
  %103 = and i128 %100, 1
  %104 = trunc i128 %103 to i64
  %105 = or i64 %102, %104
  store i64 %105, ptr %101, align 8
  %106 = load i128, ptr %6, align 16
  %107 = load i128, ptr %5, align 16
  %108 = and i128 %107, %100
  %109 = sub nuw i128 %106, %108
  store i128 %109, ptr %6, align 16
  %110 = load i128, ptr %5, align 16
  %111 = zext i7 1 to i128
  %112 = lshr i128 %110, %111
  store i128 %112, ptr %5, align 16
  br label %88

113:                                              ; preds = %85
  br label %83

114:                                              ; preds = %118, %116
  %115 = load i128, ptr %8, align 8
  ret i128 %115

116:                                              ; preds = %83
  %117 = load i128, ptr %6, align 16
  store i128 %117, ptr %2, align 16
  br label %114

118:                                              ; preds = %83
  br label %114
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local i128 @__udivti3(i128 %0, i128 %1) #1 {
  %3 = call fastcc i128 @compiler_rt.udivmod.udivmod__anon_4855(i128 %0, i128 %1, ptr align 16 null)
  ret i128 %3
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local i128 @__modti3(i128 %0, i128 %1) #1 {
  %3 = alloca [16 x i8], align 16
  %4 = zext i7 -1 to i128
  %5 = ashr i128 %0, %4
  %6 = zext i7 -1 to i128
  %7 = ashr i128 %1, %6
  %8 = xor i128 %0, %5
  %9 = sub i128 %8, %5
  %10 = xor i128 %1, %7
  %11 = sub i128 %10, %7
  call void @llvm.memset.p0.i64(ptr align 16 %3, i8 undef, i64 16, i1 false)
  %12 = call fastcc i128 @compiler_rt.udivmod.udivmod__anon_4855(i128 %9, i128 %11, ptr align 16 %3)
  %13 = load i128, ptr %3, align 16
  %14 = xor i128 %13, %5
  %15 = sub i128 %14, %5
  ret i128 %15
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local i128 @__umodti3(i128 %0, i128 %1) #1 {
  %3 = alloca [16 x i8], align 16
  call void @llvm.memset.p0.i64(ptr align 16 %3, i8 undef, i64 16, i1 false)
  %4 = call fastcc i128 @compiler_rt.udivmod.udivmod__anon_4855(i128 %0, i128 %1, ptr align 16 %3)
  %5 = load i128, ptr %3, align 16
  ret i128 %5
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local i128 @__muloti4(i128 %0, i128 %1, ptr nonnull align 4 %2) #1 {
  store i32 0, ptr %2, align 4
  %4 = mul i128 %0, %1
  %5 = icmp slt i128 %0, 0
  br i1 %5, label %9, label %11

6:                                                ; preds = %24, %23
  ret i128 %4

7:                                                ; preds = %11, %9
  %8 = phi i1 [ %10, %9 ], [ false, %11 ]
  br i1 %8, label %14, label %15

9:                                                ; preds = %3
  %10 = icmp eq i128 %1, -170141183460469231731687303715884105728
  br label %7

11:                                               ; preds = %3
  br label %7

12:                                               ; preds = %17, %14
  %13 = phi i1 [ true, %14 ], [ %18, %17 ]
  br i1 %13, label %23, label %24

14:                                               ; preds = %7
  br label %12

15:                                               ; preds = %7
  %16 = icmp ne i128 %0, 0
  br i1 %16, label %19, label %22

17:                                               ; preds = %22, %19
  %18 = phi i1 [ %21, %19 ], [ false, %22 ]
  br label %12

19:                                               ; preds = %15
  %20 = sdiv i128 %4, %0
  %21 = icmp ne i128 %20, %1
  br label %17

22:                                               ; preds = %15
  br label %17

23:                                               ; preds = %12
  store i32 1, ptr %2, align 4
  br label %6

24:                                               ; preds = %12
  br label %6
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.ctlz.i64(i64, i1 immarg) #3

; Function Attrs: nounwind uwtable
define private fastcc void @mem.doNotOptimizeAway__anon_5277(float %0) unnamed_addr #1 {
  call void asm sideeffect "", "rm,~{dirflag},~{fpsr},~{flags}"(float %0)
  ret void
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local float @floorf(float %0) #1 {
  %2 = alloca [4 x i8], align 4
  %3 = alloca [4 x i8], align 4
  %4 = bitcast float %0 to i32
  store i32 %4, ptr %3, align 4
  %5 = load i32, ptr %3, align 4
  %6 = zext i5 -9 to i32
  %7 = lshr i32 %5, %6
  %8 = and i32 %7, 255
  %9 = sub nsw i32 %8, 127
  call void @llvm.memset.p0.i64(ptr align 4 %2, i8 undef, i64 4, i1 false)
  %10 = fcmp oeq float %0, 0.000000e+00
  br i1 %10, label %13, label %14

11:                                               ; preds = %14
  %12 = icmp sge i32 %9, 23
  br i1 %12, label %17, label %18

13:                                               ; preds = %1
  ret float %0

14:                                               ; preds = %1
  br label %11

15:                                               ; preds = %18
  %16 = icmp sge i32 %9, 0
  br i1 %16, label %19, label %27

17:                                               ; preds = %11
  ret float %0

18:                                               ; preds = %11
  br label %15

19:                                               ; preds = %15
  %20 = trunc i32 %9 to i5
  %21 = zext i5 %20 to i32
  %22 = lshr i32 8388607, %21
  store i32 %22, ptr %2, align 4
  %23 = load i32, ptr %3, align 4
  %24 = load i32, ptr %2, align 4
  %25 = and i32 %23, %24
  %26 = icmp eq i32 %25, 0
  br i1 %26, label %39, label %40

27:                                               ; preds = %15
  %28 = fadd float %0, 0x4770000000000000
  call fastcc void @mem.doNotOptimizeAway__anon_5277(float %28)
  %29 = load i32, ptr %3, align 4
  %30 = zext i5 -1 to i32
  %31 = lshr i32 %29, %30
  %32 = icmp eq i32 %31, 0
  br i1 %32, label %52, label %53

33:                                               ; preds = %40
  %34 = fadd float %0, 0x4770000000000000
  call fastcc void @mem.doNotOptimizeAway__anon_5277(float %34)
  %35 = load i32, ptr %3, align 4
  %36 = zext i5 -1 to i32
  %37 = lshr i32 %35, %36
  %38 = icmp ne i32 %37, 0
  br i1 %38, label %47, label %51

39:                                               ; preds = %19
  ret float %0

40:                                               ; preds = %19
  br label %33

41:                                               ; preds = %51, %47
  %42 = load i32, ptr %3, align 4
  %43 = load i32, ptr %2, align 4
  %44 = xor i32 %43, -1
  %45 = and i32 %42, %44
  %46 = bitcast i32 %45 to float
  ret float %46

47:                                               ; preds = %33
  %48 = load i32, ptr %3, align 4
  %49 = load i32, ptr %2, align 4
  %50 = add nuw i32 %48, %49
  store i32 %50, ptr %3, align 4
  br label %41

51:                                               ; preds = %33
  br label %41

52:                                               ; preds = %27
  ret float 0.000000e+00

53:                                               ; preds = %27
  ret float -1.000000e+00
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local ptr @memcpy(ptr noalias align 1 %0, ptr noalias readonly align 1 %1, i64 %2) #1 {
  %4 = alloca [8 x i8], align 8
  %5 = alloca [8 x i8], align 8
  %6 = alloca [8 x i8], align 8
  %7 = icmp ne i64 %2, 0
  br i1 %7, label %9, label %10

8:                                                ; preds = %11, %10
  ret ptr %0

9:                                                ; preds = %3
  store ptr %0, ptr %6, align 8
  store ptr %1, ptr %5, align 8
  store i64 %2, ptr %4, align 8
  br label %12

10:                                               ; preds = %3
  br label %8

11:                                               ; preds = %27
  br label %8

12:                                               ; preds = %22, %9
  %13 = load ptr, ptr %6, align 8
  %14 = getelementptr inbounds i8, ptr %13, i64 0
  %15 = load ptr, ptr %5, align 8
  %16 = getelementptr inbounds i8, ptr %15, i64 0
  %17 = load i8, ptr %16, align 1
  store i8 %17, ptr %14, align 1
  %18 = load i64, ptr %4, align 8
  %19 = sub nuw i64 %18, 1
  store i64 %19, ptr %4, align 8
  %20 = load i64, ptr %4, align 8
  %21 = icmp eq i64 %20, 0
  br i1 %21, label %27, label %28

22:                                               ; preds = %28
  %23 = load ptr, ptr %6, align 8
  %24 = getelementptr inbounds i8, ptr %23, i64 1
  store ptr %24, ptr %6, align 8
  %25 = load ptr, ptr %5, align 8
  %26 = getelementptr inbounds i8, ptr %25, i64 1
  store ptr %26, ptr %5, align 8
  br label %12

27:                                               ; preds = %12
  br label %11

28:                                               ; preds = %12
  br label %22
}

; Function Attrs: nounwind uwtable
define weak_odr dso_local ptr @memset(ptr align 1 %0, i8 zeroext %1, i64 %2) #1 {
  %4 = alloca [8 x i8], align 8
  %5 = alloca [8 x i8], align 8
  %6 = icmp ne i64 %2, 0
  br i1 %6, label %8, label %9

7:                                                ; preds = %10, %9
  ret ptr %0

8:                                                ; preds = %3
  store ptr %0, ptr %5, align 8
  store i64 %2, ptr %4, align 8
  br label %11

9:                                                ; preds = %3
  br label %7

10:                                               ; preds = %21
  br label %7

11:                                               ; preds = %18, %8
  %12 = load ptr, ptr %5, align 8
  %13 = getelementptr inbounds i8, ptr %12, i64 0
  store i8 %1, ptr %13, align 1
  %14 = load i64, ptr %4, align 8
  %15 = sub nuw i64 %14, 1
  store i64 %15, ptr %4, align 8
  %16 = load i64, ptr %4, align 8
  %17 = icmp eq i64 %16, 0
  br i1 %17, label %21, label %22

18:                                               ; preds = %22
  %19 = load ptr, ptr %5, align 8
  %20 = getelementptr inbounds i8, ptr %19, i64 1
  store ptr %20, ptr %5, align 8
  br label %11

21:                                               ; preds = %11
  br label %10

22:                                               ; preds = %11
  br label %18
}

; Function Attrs: nounwind uwtable
define private fastcc i64 @compiler_rt.udivmod.divwide__anon_7772(i64 %0, i64 %1, i64 %2, ptr nonnull align 8 %3) unnamed_addr #1 {
  %5 = alloca [8 x i8], align 8
  call void @llvm.memset.p0.i64(ptr align 8 %5, i8 undef, i64 8, i1 false)
  %6 = call { i64, i64 } asm "divq ${2}", "={rax},={rdx},r,{rax},{rdx},~{dirflag},~{fpsr},~{flags}"(i64 %2, i64 %1, i64 %0)
  %7 = extractvalue { i64, i64 } %6, 0
  %8 = extractvalue { i64, i64 } %6, 1
  store i64 %8, ptr %5, align 8
  %9 = load i64, ptr %5, align 8
  store i64 %9, ptr %3, align 8
  ret i64 %7
}

define internal fastcc void @_main_for_host_c610e85212d0697cb161d4ba431ba63f273feee7dcb7927c9ff5d74ae6cbfa3(ptr %0) !dbg !3 {
entry:
  %result_value = alloca %str.RocStr, align 8
  call fastcc void @"#UserApp_main_ec2bd03bf86b935fa34d71ad7ebb49f1f10f87d343e521511d8f9e6625620cd"(ptr %result_value), !dbg !7
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %0, ptr align 8 %result_value, i64 ptrtoint (ptr getelementptr (%str.RocStr, ptr null, i32 1) to i64), i1 false), !dbg !7
  ret void, !dbg !7
}

define void @roc__main_for_host_1_exposed_generic(ptr %0) !dbg !9 {
entry:
  %result_value = alloca %str.RocStr, align 8
  call fastcc void @_main_for_host_c610e85212d0697cb161d4ba431ba63f273feee7dcb7927c9ff5d74ae6cbfa3(ptr %result_value), !dbg !10
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %0, ptr align 8 %result_value, i64 ptrtoint (ptr getelementptr (%str.RocStr, ptr null, i32 1) to i64), i1 false), !dbg !10
  ret void, !dbg !10
}

define void @roc__main_for_host_1_exposed(ptr sret(%str.RocStr) %0) !dbg !12 {
entry:
  %result_value = alloca %str.RocStr, align 8
  call fastcc void @_main_for_host_c610e85212d0697cb161d4ba431ba63f273feee7dcb7927c9ff5d74ae6cbfa3(ptr %result_value), !dbg !13
  %load_roc_result = load %str.RocStr, ptr %result_value, align 8, !dbg !13
  store %str.RocStr %load_roc_result, ptr %0, align 8, !dbg !13
  ret void, !dbg !13
}

define i64 @roc__main_for_host_1_exposed_size() !dbg !15 {
entry:
  ret i64 ptrtoint (ptr getelementptr (%str.RocStr, ptr null, i32 1) to i64), !dbg !16
}

define internal fastcc void @"#UserApp_main_ec2bd03bf86b935fa34d71ad7ebb49f1f10f87d343e521511d8f9e6625620cd"(ptr %0) !dbg !18 {
entry:
  %const_str_store = alloca %str.RocStr, align 8
  store %str.RocStr { ptr getelementptr inbounds (i8, ptr @_str_literal_13276749449650780488, i64 8), i64 25, i64 25 }, ptr %const_str_store, align 8, !dbg !19
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %0, ptr align 8 %const_str_store, i64 ptrtoint (ptr getelementptr (%str.RocStr, ptr null, i32 1) to i64), i1 false), !dbg !19
  ret void, !dbg !19
}

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #1 = { nounwind uwtable "frame-pointer"="none" "target-cpu"="x86-64" "target-features"="-16bit-mode,-32bit-mode,-3dnow,-3dnowa,+64bit,-adx,-aes,-allow-light-256-bit,-amx-bf16,-amx-complex,-amx-fp16,-amx-int8,-amx-tile,-avx,-avx10.1-256,-avx10.1-512,-avx2,-avx512bf16,-avx512bitalg,-avx512bw,-avx512cd,-avx512dq,-avx512er,-avx512f,-avx512fp16,-avx512ifma,-avx512pf,-avx512vbmi,-avx512vbmi2,-avx512vl,-avx512vnni,-avx512vp2intersect,-avx512vpopcntdq,-avxifma,-avxneconvert,-avxvnni,-avxvnniint16,-avxvnniint8,-bmi,-bmi2,-branchfusion,-ccmp,-cf,-cldemote,-clflushopt,-clwb,-clzero,+cmov,-cmpccxadd,-crc32,-cx16,+cx8,-egpr,-enqcmd,-ermsb,-evex512,-f16c,-false-deps-getmant,-false-deps-lzcnt-tzcnt,-false-deps-mulc,-false-deps-mullq,-false-deps-perm,-false-deps-popcnt,-false-deps-range,-fast-11bytenop,-fast-15bytenop,-fast-7bytenop,-fast-bextr,-fast-gather,-fast-hops,-fast-lzcnt,-fast-movbe,-fast-scalar-fsqrt,-fast-scalar-shift-masks,-fast-shld-rotate,-fast-variable-crosslane-shuffle,-fast-variable-perlane-shuffle,-fast-vector-fsqrt,-fast-vector-shift-masks,-faster-shift-than-shuffle,-fma,-fma4,-fsgsbase,-fsrm,+fxsr,-gfni,-harden-sls-ijmp,-harden-sls-ret,-hreset,-idivl-to-divb,+idivq-to-divl,-invpcid,-kl,-lea-sp,-lea-uses-ag,-lvi-cfi,-lvi-load-hardening,-lwp,-lzcnt,+macrofusion,+mmx,-movbe,-movdir64b,-movdiri,-mwaitx,-ndd,-no-bypass-delay,-no-bypass-delay-blend,-no-bypass-delay-mov,-no-bypass-delay-shuffle,+nopl,-pad-short-functions,-pclmul,-pconfig,-pku,-popcnt,-ppx,-prefer-128-bit,-prefer-256-bit,-prefer-mask-registers,-prefer-movmsk-over-vtest,-prefer-no-gather,-prefer-no-scatter,-prefetchi,-prefetchwt1,-prfchw,-ptwrite,-push2pop2,-raoint,-rdpid,-rdpru,-rdrnd,-rdseed,-retpoline,-retpoline-external-thunk,-retpoline-indirect-branches,-retpoline-indirect-calls,-rtm,-sahf,-sbb-dep-breaking,-serialize,-seses,-sgx,-sha,-sha512,-shstk,+slow-3ops-lea,+slow-incdec,-slow-lea,-slow-pmaddwd,-slow-pmulld,-slow-shld,-slow-two-mem-ops,-slow-unaligned-mem-16,-slow-unaligned-mem-32,-sm3,-sm4,-soft-float,+sse,+sse2,-sse3,-sse4.1,-sse4.2,-sse4a,-sse-unaligned-mem,-ssse3,-tagged-globals,-tbm,-tsxldtrk,-tuning-fast-imm-vector-shift,-uintr,-use-glm-div-sqrt-costs,-use-slm-arith-costs,-usermsr,-vaes,-vpclmulqdq,+vzeroupper,-waitpkg,-wbnoinvd,-widekl,+x87,-xop,-xsave,-xsavec,-xsaveopt,-xsaves" }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0}
!llvm.dbg.cu = !{!1}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = distinct !DICompileUnit(language: DW_LANG_C, file: !2, producer: "my llvm compiler frontend", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false)
!2 = !DIFile(filename: "roc_app", directory: ".")
!3 = distinct !DISubprogram(name: "_main_for_host_c610e85212d0697cb161d4ba431ba63f273feee7dcb7927c9ff5d74ae6cbfa3", linkageName: "_main_for_host_c610e85212d0697cb161d4ba431ba63f273feee7dcb7927c9ff5d74ae6cbfa3", scope: !2, file: !2, type: !4, flags: DIFlagPublic, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !1)
!4 = !DISubroutineType(flags: DIFlagPublic, types: !5)
!5 = !{!6}
!6 = !DIBasicType(name: "type_name", flags: DIFlagPublic)
!7 = !DILocation(line: 0, scope: !8)
!8 = distinct !DILexicalBlock(scope: !3, file: !2)
!9 = distinct !DISubprogram(name: "roc__main_for_host_1_exposed_generic", linkageName: "roc__main_for_host_1_exposed_generic", scope: !2, file: !2, type: !4, flags: DIFlagPublic, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !1)
!10 = !DILocation(line: 0, scope: !11)
!11 = distinct !DILexicalBlock(scope: !9, file: !2)
!12 = distinct !DISubprogram(name: "roc__main_for_host_1_exposed", linkageName: "roc__main_for_host_1_exposed", scope: !2, file: !2, type: !4, flags: DIFlagPublic, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !1)
!13 = !DILocation(line: 0, scope: !14)
!14 = distinct !DILexicalBlock(scope: !12, file: !2)
!15 = distinct !DISubprogram(name: "roc__main_for_host_1_exposed_size", linkageName: "roc__main_for_host_1_exposed_size", scope: !2, file: !2, type: !4, flags: DIFlagPublic, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !1)
!16 = !DILocation(line: 0, scope: !17)
!17 = distinct !DILexicalBlock(scope: !15, file: !2)
!18 = distinct !DISubprogram(name: "#UserApp_main_ec2bd03bf86b935fa34d71ad7ebb49f1f10f87d343e521511d8f9e6625620cd", linkageName: "#UserApp_main_ec2bd03bf86b935fa34d71ad7ebb49f1f10f87d343e521511d8f9e6625620cd", scope: !2, file: !2, type: !4, flags: DIFlagPublic, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition, unit: !1)
!19 = !DILocation(line: 0, scope: !20)
!20 = distinct !DILexicalBlock(scope: !18, file: !2)
