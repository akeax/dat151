.class public Foo
.super java/lang/Object

.method public <init>()V
aload_0
invokenonvirtual java/lang/Object/<init>()V
return
.end method

.method public static main([Ljava/lang/String;)V
.limit locals 100
.limit stack 1000
invokestatic Runtime/readInt()I
istore 1
iload 1
bipush 2
idiv
istore 2
L0:
iconst_1
iload 2
bipush 1
if_icmpgt L2
pop
iconst_0
L2:
ifeq L1
iconst_1
iload 2
iload 1
iload 2
idiv
imul
iload 1
if_icmpeq L5
pop
iconst_0
L5:
ifeq L4
iload 2
invokestatic Runtime/printInt(I)V
goto L3
L4:
L3:
iload 2
dup
bipush 1
isub
istore 2
pop
goto L0
L1:
return
.end method
