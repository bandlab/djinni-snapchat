// Hand-written C++ implementation of the curated `runtime_iface` (+c) interface,
// for the HOST load/link/run round-trip proof. Not part of djinni codegen; lives
// only in the scratchpad harness. Mirrors the role of test-suite/handwritten-src/cpp
// impls (e.g. reverse_client_interface_impl.cpp): provides the concrete native side
// plus the `static create` factory symbol the JNI Statics glue links against.
//
// Round-trip semantics (distinctive so the Kotlin driver can assert end-to-end):
//   create(seed)          -> impl with seed
//   id_record(r)          -> r verbatim (echo; proves record marshalling both ways)
//   make_record(label)    -> record{ id=seed, "cfg:"+label, gain=1.5, [a,b],
//                                     {"k":7}, fav_color=(Color)(seed % 7) }
//   next_color(c)         -> (c+1) mod 7  (enum round-trip)
//   id_optional(o)        -> o verbatim
//   id_list(l)            -> l verbatim
//   id_map(m)             -> m verbatim
//   get_seed / set_seed   -> property backing field

#include "runtime_iface.hpp"
#include "runtime_record.hpp"
#include "color.hpp"

#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace rt {
namespace {

class RuntimeIfaceImpl final : public RuntimeIface {
public:
    explicit RuntimeIfaceImpl(int32_t seed) : m_seed(seed) {}

    RuntimeRecord id_record(const RuntimeRecord & r) override { return r; }

    RuntimeRecord make_record(const std::string & label) override {
        return RuntimeRecord(
            m_seed,
            "cfg:" + label,
            std::optional<double>(1.5),
            std::vector<std::string>{"a", "b"},
            std::unordered_map<std::string, int64_t>{{"k", 7}},
            static_cast<Color>(m_seed % 7));
    }

    Color next_color(Color c) override {
        return static_cast<Color>((static_cast<int>(c) + 1) % 7);
    }

    std::optional<std::string> id_optional(const std::optional<std::string> & o) override {
        return o;
    }

    std::vector<int32_t> id_list(const std::vector<int32_t> & l) override { return l; }

    std::unordered_map<std::string, int64_t> id_map(
            const std::unordered_map<std::string, int64_t> & m) override {
        return m;
    }

    int32_t get_seed() override { return m_seed; }
    void set_seed(int32_t s) override { m_seed = s; }

private:
    int32_t m_seed;
};

} // namespace

std::shared_ptr<RuntimeIface> RuntimeIface::create(int32_t seed) {
    return std::make_shared<RuntimeIfaceImpl>(seed);
}

} // namespace rt
