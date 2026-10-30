package settings

import "core:testing"

@(test)
semantic_version_requires_ascii_digits :: proc(t:^testing.T) {
    for text in ([]string{"1.2.3","0001.02.3","999999999.0.0"}) {
        _,valid:=semantic_version_parse(text);testing.expect(t,valid)
    }
    for text in ([]string{"\u0131.2.3","1.\u0232.3","1.2.\u0333","1.2.3-beta","1.2","1000000000.0.0"}) {
        _,valid:=semantic_version_parse(text);testing.expect(t,!valid,text)
    }
}
