////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMRealm_Private.h"

#import <unordered_map>

namespace realm {
    class Group;
    class Realm;
    class Schema;
}

struct RLMObjectInfo;

namespace std {
template<> struct hash<NSString *> {
    size_t operator()(__unsafe_unretained NSString *const str) const {
        return [str hash];
    }
};
template<> struct equal_to<NSString *> {
    bool operator()(__unsafe_unretained NSString * lhs, __unsafe_unretained NSString *rhs) const {
        return [lhs isEqualToString:rhs];
    }
};
}

class RLMSchemaInfo {
    using impl = std::unordered_map<NSString *, RLMObjectInfo>;
public:
    void init(RLMRealm *realm, RLMSchema *rlmSchema, realm::Schema const& schema);

    RLMObjectInfo *find(NSString *name) const noexcept;
    RLMObjectInfo& operator[](NSString *name) const; // throws

    impl::iterator begin();
    impl::iterator end();
    impl::const_iterator begin() const;
    impl::const_iterator end() const;
private:
    std::unordered_map<NSString *, RLMObjectInfo> m_objects;
};

@interface RLMRealm () {
    @public
    std::shared_ptr<realm::Realm> _realm;
    RLMSchemaInfo _info;
}

// FIXME - group should not be exposed
@property (nonatomic, readonly) realm::Group &group;
@end
