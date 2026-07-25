// MINIMAL STUBS for protobuf extern types referenced by the golden Kotlin.
// These stand in for the protoc-generated Java classes named in
// djinni/vendor/third-party/proto.yaml (java.class 'djinni.test.Test') and
// proto2.yaml (java.class 'djinni.test2.Test2'). Only the type identity matters
// for a compile check; no protobuf runtime behavior is needed.
//
// NOTE: The KotlinGenerator references these types by their SIMPLE names with no
// import (see api/ProtoTestsStatics.kt). The Java generator, by contrast, emits
// `import djinni.test.Test.Person;` etc. To reproduce the *intended* nesting we
// declare them here as nested classes; the harness ALSO provides package-local
// aliases (see ProtoAliases.kt) so the bare Kotlin references resolve. See REPORT.md
// (generator bug: missing proto import) for details.

package djinni.test;

public final class Test {
    private Test() {}
    public static final class Person {}
    public static final class AddressBook {}
}
