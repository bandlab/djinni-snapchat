/**
  * Copyright 2014 Dropbox, Inc.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
  * You may obtain a copy of the License at
  *
  *    http://www.apache.org/licenses/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the License is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the License for the specific language governing permissions and
  * limitations under the License.
  *
  * Kotlin backend (PoC). Modeled on JavaMarshal. JavaMarshal is NOT modified.
  */

package djinni

import djinni.ast._
import djinni.generatorTools._
import djinni.meta._

// Maps the djinni type model to idiomatic Kotlin type expressions.
//
// Naming: Kotlin deliberately reuses the *Java* ident styles (spec.javaIdentStyle, exposed as
// `idJava` on the Marshal base) for every JVM-visible name -- class names, field names, method
// names, enum constants. That guarantees the member surface is byte-for-byte identical to today's
// generated Java, so the existing JNI layer (which looks classes/fields/methods up by these exact
// names) keeps binding. Only *type shapes* and *nullability* become idiomatic.
//
// Two type flavors are produced:
//   - the idiomatic flavor (List/Set/Map, T?) -- used for interface method signatures (the API).
//   - the "concrete" flavor (ArrayList/HashSet/HashMap) -- used for `data class` record fields and
//     constructor params, because the JNI record helper looks up the constructor signature and each
//     field id with the concrete java.util.* type descriptor. See KotlinGenerator / IMPLEMENTATION-NOTES.
class KotlinMarshal(spec: Spec) extends Marshal(spec) {

  // Mirrors JavaMarshal's policy: without --cpp-nn-type an interface reference is nullable
  // (Java @Nullable); with it, non-null. Records/enums are always non-null; optional<T> is nullable.
  private val interfaceNullable: Boolean = spec.cppNnType.isEmpty

  // ---- Marshal API -----------------------------------------------------------------------------

  // Bare type name for a declaration (no package, no nullability). Used to name the class itself.
  override def typename(tm: MExpr): String = kotlinType(tm, None, concrete = false, forceNonNull = false)
  def typename(name: String, ty: TypeDef): String = idJava.ty(name)

  override def fqTypename(tm: MExpr): String = kotlinType(tm, spec.kotlinPackage, concrete = false, forceNonNull = false)
  def fqTypename(name: String, ty: TypeDef): String = withPackage(spec.kotlinPackage, idJava.ty(name))

  // Interface method params/returns -> idiomatic flavor.
  override def paramType(tm: MExpr): String = kotlinType(tm, None, concrete = false, forceNonNull = false)
  override def fqParamType(tm: MExpr): String = kotlinType(tm, spec.kotlinPackage, concrete = false, forceNonNull = false)

  override def returnType(ret: Option[TypeRef]): String = ret.fold("Unit")(t => kotlinType(t.resolved, None, concrete = false, forceNonNull = false))
  override def fqReturnType(ret: Option[TypeRef]): String = ret.fold("Unit")(t => kotlinType(t.resolved, spec.kotlinPackage, concrete = false, forceNonNull = false))

  // Record fields/constructor params -> idiomatic flavor (List/Set/Map, read-only). Team decision:
  // collections are idiomatic everywhere and only arrays are mutable. The JNI record marshalling must
  // then bind interface descriptors (Ljava/util/List; etc.) instead of concrete java.util.* -- a
  // deferred JNI-side change, not a surface blocker.
  override def fieldType(tm: MExpr): String = kotlinType(tm, None, concrete = false, forceNonNull = false)
  override def fqFieldType(tm: MExpr): String = kotlinType(tm, spec.kotlinPackage, concrete = false, forceNonNull = false)

  override def toCpp(tm: MExpr, expr: String): String = throw new AssertionError("direct kotlin to cpp conversion not possible")
  override def fromCpp(tm: MExpr, expr: String): String = throw new AssertionError("direct cpp to kotlin conversion not possible")

  // Non-null variant of a return type. Used for the create() factory (the one intentional deviation
  // from Java's @Nullable static-native create): create(...): T, never T?.
  def returnTypeNonNull(ret: Option[TypeRef]): String =
    ret.fold("Unit")(t => kotlinType(t.resolved, None, concrete = false, forceNonNull = true))

  // Kotlin needs very few imports: List/Set/Map/ArrayList/HashSet/HashMap are all in kotlin.collections
  // (typealiased to java.util.*) and auto-imported; same-package generated types need no import; date is
  // referenced fully-qualified. Cross-package extern imports are a follow-up (not exercised by the PoC).
  def references(m: Meta): Seq[SymbolReference] = List()

  // ---- Type mapping ----------------------------------------------------------------------------

  private def kotlinType(tm: MExpr, pkg: Option[String], concrete: Boolean, forceNonNull: Boolean): String =
    bareType(tm, pkg, concrete) + nullSuffix(tm, forceNonNull)

  private def bareType(tm: MExpr, pkg: Option[String], concrete: Boolean): String = {
    def args(x: MExpr): String =
      if (x.args.isEmpty) "" else x.args.map(a => kotlinType(a, pkg, concrete, forceNonNull = false)).mkString("<", ", ", ">")
    tm.base match {
      case MOptional =>
        // In Kotlin optional<T> is just the inner type with a `?` suffix (added by nullSuffix).
        assert(tm.args.size == 1)
        bareType(tm.args.head, pkg, concrete)
      case MArray => arrayType(tm.args.head, pkg, concrete)
      case p: MPrimitive => primName(p)
      case MString => "String"
      case MDate => "java.util.Date"
      case MBinary => "ByteArray"
      case MList => (if (concrete) "ArrayList" else "List") + args(tm)
      case MSet => (if (concrete) "HashSet" else "Set") + args(tm)
      case MMap => (if (concrete) "HashMap" else "Map") + args(tm)
      case MVoid => "Unit"
      case p: MParam => idJava.typeParam(p.name)
      case d: MDef =>
        if (isEnumFlags(tm)) "java.util.EnumSet<" + withPackage(pkg, idJava.ty(d.name)) + ">"
        else withPackage(pkg, idJava.ty(d.name)) + args(tm)
      case e: MExtern =>
        if (isEnumFlags(tm)) "java.util.EnumSet<" + e.java.typename + ">"
        else e.java.typename + (if (e.java.generic) args(tm) else "")
      case p: MProtobuf => p.name
    }
  }

  // Nullability per the mirrored Java policy, encoded in the Kotlin type itself.
  private def nullSuffix(tm: MExpr, forceNonNull: Boolean): String = {
    if (forceNonNull) return ""
    tm.base match {
      case MOptional => "?"
      case m if isInterfaceMeta(m) => if (interfaceNullable) "?" else ""
      case _ => ""
    }
  }

  private def arrayType(elem: MExpr, pkg: Option[String], concrete: Boolean): String = elem.base match {
    case p: MPrimitive => p.jName match {
      case "byte" => "ByteArray"
      case "short" => "ShortArray"
      case "int" => "IntArray"
      case "long" => "LongArray"
      case "float" => "FloatArray"
      case "double" => "DoubleArray"
      case "boolean" => "BooleanArray"
      case _ => "Array<" + kotlinType(elem, pkg, concrete, forceNonNull = false) + ">"
    }
    case _ => "Array<" + kotlinType(elem, pkg, concrete, forceNonNull = false) + ">"
  }

  private def primName(p: MPrimitive): String = p.jName match {
    case "byte" => "Byte"
    case "short" => "Short"
    case "int" => "Int"
    case "long" => "Long"
    case "float" => "Float"
    case "double" => "Double"
    case "boolean" => "Boolean"
    case other => firstUpper(other)
  }

  private def isInterfaceMeta(m: Meta): Boolean = m match {
    case d: MDef => d.defType == DInterface
    case e: MExtern => e.defType == DInterface
    case _ => false
  }

  def isEnumFlags(m: Meta): Boolean = m match {
    case MDef(_, _, _, Enum(_, true)) => true
    case MExtern(_, _, _, Enum(_, true), _, _, _, _, _, _, _) => true
    case _ => false
  }
  def isEnumFlags(tm: MExpr): Boolean = tm.base match {
    case MOptional => isEnumFlags(tm.args.head)
    case _ => isEnumFlags(tm.base)
  }

  private def withPackage(pkg: Option[String], t: String): String = pkg.fold(t)(_ + "." + t)
}
