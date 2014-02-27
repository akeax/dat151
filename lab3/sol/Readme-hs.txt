-- AR 18/2/2014 for the PLT course

=Compiler=

To compile the compiler:

  make compilemini

Make sure you have bnfc, Happy, Alex, and GHC available.

To run the compiler:

  ./compilemini ../ex.mini

Make sure you have jasmin.jar available.

To run the generated JVM code:

  java Foo

Make sure you have Runtime.class available. You can produce it by

  javac ../Runtime.java

Also make sure that your current directory (where Foo.class resides) is the the CLASSPATH.


=Files=

  compilermini       -- shell script that runs compilermini.java
  compilermini.hs    -- top level compiler
  Compiler.hs        -- code generator
  TypeChecker.hs     -- type checker
  Interpreter.hs     -- interpreter

  AnnotCompiler.hs          -- code generator using type annotations
  AnnotatingTypeChecker.hs  -- type checker that produces annotations; not quite complete

  ../Mini.cf       -- grammar of Mini, source file for bnfc
  ../ex.mini       -- example Mini program
  ../Runtime.java  -- runtime system for the compiler


